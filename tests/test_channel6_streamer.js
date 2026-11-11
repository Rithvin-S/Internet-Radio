const http = require('http');
const assert = require('assert');
const { spawn } = require('child_process');
const path = require('path');

const TEST_PORT = 8006;
const BASE_URL = `http://127.0.0.1:${TEST_PORT}`;

console.log('======================================================');
console.log('       PULSECAST CHANNEL 6 STREAMER TEST SUITE        ');
console.log('======================================================\n');

let serverProcess = null;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function startServer() {
  return new Promise((resolve, reject) => {
    const serverPath = path.resolve(__dirname, '..', 'radio', 'channel6-streamer', 'server.js');
    serverProcess = spawn('node', [serverPath], {
      env: {
        ...process.env,
        CHANNEL6_PORT: String(TEST_PORT),
        PORT: String(TEST_PORT)
      },
      stdio: ['ignore', 'pipe', 'pipe']
    });

    serverProcess.stdout.on('data', (d) => {
      const msg = d.toString();
      if (msg.includes('Channel 6 is LIVE!')) {
        resolve();
      }
    });

    serverProcess.stderr.on('data', (d) => {
      console.error('[Server STDERR]', d.toString());
    });

    serverProcess.on('error', reject);
    serverProcess.on('exit', (code) => {
      if (code !== null && code !== 0) {
        reject(new Error(`Server exited prematurely with code ${code}`));
      }
    });

    setTimeout(() => {
      reject(new Error('Server start timed out after 10s'));
    }, 10000);
  });
}

function stopServer() {
  if (serverProcess) {
    try {
      serverProcess.kill('SIGINT');
    } catch (_) {}
    serverProcess = null;
  }
}

function httpGetJson(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, data: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, raw: data });
        }
      });
    }).on('error', reject);
  });
}

function connectAudioStream(timeoutMs = 4000) {
  return new Promise((resolve, reject) => {
    const req = http.get(`${BASE_URL}/pulsecast.mp3`, (res) => {
      let bytesReceived = 0;
      let chunksCount = 0;
      const firstChunkReceived = Date.now();

      res.on('data', (chunk) => {
        bytesReceived += chunk.length;
        chunksCount++;
      });

      const timer = setTimeout(() => {
        req.destroy();
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          bytesReceived,
          chunksCount,
          durationMs: timeoutMs
        });
      }, timeoutMs);

      res.on('error', (err) => {
        clearTimeout(timer);
        reject(err);
      });
    });

    req.on('error', reject);
  });
}

async function runTests() {
  const args = process.argv.slice(2);
  const run10MinTest = args.includes('--10min') || args.includes('--soak');

  try {
    console.log('[Test 0] Launching Channel 6 Streaming Server on port', TEST_PORT);
    await startServer();
    console.log('✓ Server started successfully.\n');

    // 1. Health and metadata check
    console.log('[Test 1] Health and Metadata APIs');
    const health = await httpGetJson(`${BASE_URL}/health`);
    assert.strictEqual(health.status, 200);
    assert.strictEqual(health.data.status, 'ok');
    assert.strictEqual(health.data.channel, 6);
    assert.ok(health.data.libraryCount > 0, 'Library count must be > 0');
    console.log(`✓ Health check passed. Library has ${health.data.libraryCount} tracks.`);

    const nowPlaying = await httpGetJson(`${BASE_URL}/api/now-playing`);
    assert.strictEqual(nowPlaying.status, 200);
    assert.ok(nowPlaying.data.currentTrack, 'Current track must exist');
    console.log(`✓ Now playing: "${nowPlaying.data.currentTrack.title}" by ${nowPlaying.data.currentTrack.artist}`);
    console.log(`  Next up: "${nowPlaying.data.nextTrack.title}" by ${nowPlaying.data.nextTrack.artist}\n`);

    // 2. Multiple Simultaneous Listeners Test
    console.log('[Test 2] Multiple Simultaneous Listeners (5 concurrent clients for 5s)');
    const clientPromises = [];
    for (let i = 1; i <= 5; i++) {
      clientPromises.push(connectAudioStream(5000));
    }
    const results = await Promise.all(clientPromises);
    for (let i = 0; i < results.length; i++) {
      const r = results[i];
      assert.strictEqual(r.statusCode, 200, `Client ${i+1} status code must be 200`);
      assert.strictEqual(r.headers['content-type'], 'audio/mpeg', `Client ${i+1} content-type must be audio/mpeg`);
      assert.ok(r.bytesReceived > 40000, `Client ${i+1} must receive > 40KB (received: ${r.bytesReceived})`);
      console.log(`  Client ${i+1}: received ${r.bytesReceived} bytes (${(r.bytesReceived/1024).toFixed(1)} KB) in ${r.chunksCount} chunks`);
    }
    console.log('✓ Multiple simultaneous listeners test passed.\n');

    // 3. Listener Joining Midway Through a Song
    console.log('[Test 3] Listener Joining Midway Through a Song');
    const npBefore = await httpGetJson(`${BASE_URL}/api/now-playing`);
    const initialElapsed = npBefore.data.elapsedSeconds;
    console.log(`  Initial playback position: ${initialElapsed.toFixed(1)}s into "${npBefore.data.currentTrack.title}"`);

    console.log('  Waiting 3 seconds before new listener connects...');
    await sleep(3000);

    const midStreamResult = await connectAudioStream(3000);
    assert.strictEqual(midStreamResult.statusCode, 200);
    assert.ok(midStreamResult.bytesReceived > 20000, 'Must receive audio immediately on mid-join');

    const npAfter = await httpGetJson(`${BASE_URL}/api/now-playing`);
    console.log(`  Playback position after mid-join: ${npAfter.data.elapsedSeconds.toFixed(1)}s (timeline advanced seamlessly)`);
    assert.ok(npAfter.data.elapsedSeconds > initialElapsed + 2.5, 'Authoritative timeline must advance continuously');
    console.log('✓ Listener midway join verified with immediate audio delivery.\n');

    // 4. Disconnect and Reconnect Behavior
    console.log('[Test 4] Disconnect and Reconnect Behavior');
    // Start listener A and listener B
    let listenerBReceivedAfter = false;
    let listenerBBytes = 0;

    const reqB = http.get(`${BASE_URL}/pulsecast.mp3`, (resB) => {
      resB.on('data', chunk => {
        listenerBBytes += chunk.length;
        if (listenerBReceivedAfter) {
          // B is still receiving after A disconnected
        }
      });
    });

    await sleep(1000);
    // Connect listener A and abruptly disconnect
    const reqA = http.get(`${BASE_URL}/pulsecast.mp3`, (resA) => {
      resA.on('data', () => {});
    });
    await sleep(1000);
    reqA.destroy();
    console.log('  Listener A abruptly disconnected.');

    // Verify listener B continues receiving
    const bytesBefore = listenerBBytes;
    listenerBReceivedAfter = true;
    await sleep(2000);
    const bytesAfter = listenerBBytes;
    assert.ok(bytesAfter > bytesBefore + 10000, 'Listener B must continue receiving audio uninterrupted');
    console.log(`  Listener B received ${bytesAfter - bytesBefore} bytes while Listener A was disconnected.`);
    reqB.destroy();

    // Reconnect Listener A
    const reconnectResult = await connectAudioStream(2500);
    assert.strictEqual(reconnectResult.statusCode, 200);
    assert.ok(reconnectResult.bytesReceived > 15000, 'Reconnected listener must receive audio');
    console.log('✓ Disconnect and reconnect behavior verified.\n');

    // 5. Seamless Song Transitions
    console.log('[Test 5] Seamless Song Transitions');
    let transitionBytes = 0;
    let receivedAcrossTransition = false;

    // Connect a continuous listener
    const transReq = http.get(`${BASE_URL}/pulsecast.mp3`, (transRes) => {
      assert.strictEqual(transRes.statusCode, 200);
      transRes.on('data', chunk => {
        transitionBytes += chunk.length;
      });
    });

    await sleep(1000);
    const trackBefore = (await httpGetJson(`${BASE_URL}/api/now-playing`)).data.currentTrack.title;
    console.log(`  Current track before transition: "${trackBefore}"`);

    // Trigger skip to simulate end-of-track transition
    const skipRes = await httpGetJson(`${BASE_URL}/api/skip`);
    console.log(`  Triggered transition to next track: "${skipRes.data.currentTrack.title}"`);
    assert.notStrictEqual(skipRes.data.currentTrack.title, trackBefore, 'Must advance to next track');

    const bytesPreSleep = transitionBytes;
    await sleep(3000);
    const bytesPostSleep = transitionBytes;

    assert.ok(bytesPostSleep > bytesPreSleep + 20000, 'Audio must continue streaming without closing HTTP connection');
    transReq.destroy();
    console.log(`  Stream remained continuously open: received ${bytesPostSleep - bytesPreSleep} bytes of new track.`);
    console.log('✓ Seamless song transition verified.\n');

    // 6. Continuous Playback Verification (Soak Test)
    if (run10MinTest) {
      console.log('[Test 6] 10-Minute Continuous Playback Verification');
      console.log('  Streaming continuous audio for 600 seconds...');
      const startTime = Date.now();
      const targetDurationMs = 600 * 1000;
      let totalBytesReceived = 0;
      let intervalCount = 0;

      await new Promise((resolve, reject) => {
        const streamReq = http.get(`${BASE_URL}/pulsecast.mp3`, (res) => {
          res.on('data', chunk => {
            totalBytesReceived += chunk.length;
          });

          const interval = setInterval(async () => {
            intervalCount++;
            const elapsed = Math.floor((Date.now() - startTime) / 1000);
            const kbStreamed = (totalBytesReceived / 1024).toFixed(1);
            const np = await httpGetJson(`${BASE_URL}/api/now-playing`);
            console.log(`  [${elapsed}s / 600s] Received: ${kbStreamed} KB | Playing: "${np.data.currentTrack.title}" (${np.data.elapsedSeconds}s)`);

            if (Date.now() - startTime >= targetDurationMs) {
              clearInterval(interval);
              streamReq.destroy();
              resolve();
            }
          }, 30000); // report every 30 seconds
        });
        streamReq.on('error', reject);
      });

      console.log(`✓ 10-minute continuous playback verified! Total audio received: ${(totalBytesReceived/(1024*1024)).toFixed(2)} MB.\n`);
    } else {
      console.log('[Test 6] 30-Second Continuous Playback Verification (Pass --10min for full 10-minute soak)');
      const contResult = await connectAudioStream(30000);
      assert.strictEqual(contResult.statusCode, 200);
      assert.ok(contResult.bytesReceived > 400000, 'Must receive > 400KB in 30 seconds');
      console.log(`  Received ${(contResult.bytesReceived/1024).toFixed(1)} KB in 30 seconds. Stream is stable.`);
      console.log('✓ Continuous playback verified.\n');
    }

    console.log('======================================================');
    console.log('      ALL CHANNEL 6 STREAMER TESTS PASSED!            ');
    console.log('======================================================');
    stopServer();
    process.exit(0);
  } catch (err) {
    console.error('\n❌ TEST FAILED:', err);
    stopServer();
    process.exit(1);
  }
}

runTests();


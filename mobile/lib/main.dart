import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/cache/cache_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'features/player/presentation/providers/player_providers.dart';
import 'features/player/services/radio_audio_handler.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences for persistent offline caching, favorites, and settings
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize single persistent system audio handler for background & lockscreen playback
  final audioHandler = await initAudioHandler();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        radioAudioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const PulseCastApp(),
    ),
  );
}

class PulseCastApp extends ConsumerWidget {
  const PulseCastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}

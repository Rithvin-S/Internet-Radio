import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routing/route_names.dart';
import 'presentation/providers/admin_providers.dart';

/// PulseCast Exact Reference Admin Dashboard Screen
/// Features green crown icon, centered title, 2x2 grid (Library, Stations, Schedule, Analytics),
/// and bottom glowing green wave.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.settings);
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // Bottom glowing green wave matching reference
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GreenBottomWave(),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),

                  // 1. Crown Icon in vibrant reference green
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.primary,
                    size: 38,
                  ),
                  const SizedBox(height: 12),

                  // 2. Admin Dashboard Title
                  const Text(
                    'Admin Dashboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // 3. Exact 2x2 Grid matching reference
                  Row(
                    children: [
                      // Grid Item 1: Library
                      Expanded(
                        child: _buildDashboardCard(
                          icon: Icons.music_note_rounded,
                          title: 'Library',
                          subtitle: 'Manage tracks',
                          onTap: () => context.push(RouteNames.adminSongs),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Grid Item 2: Stations
                      Expanded(
                        child: _buildDashboardCard(
                          icon: Icons.cell_tower_rounded,
                          title: 'Stations',
                          subtitle: 'Manage stations',
                          onTap: () => context.push(RouteNames.adminStations),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // Grid Item 3: Schedule
                      Expanded(
                        child: _buildDashboardCard(
                          icon: Icons.calendar_month_rounded,
                          title: 'Schedule',
                          subtitle: 'Plan broadcasts',
                          onTap: () => context.push(RouteNames.adminSchedules),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Grid Item 4: Analytics
                      Expanded(
                        child: _buildDashboardCard(
                          icon: Icons.bar_chart_rounded,
                          title: 'Analytics',
                          subtitle: 'Listeners & usage',
                          onTap: () => _showAnalyticsDialog(context, ref, statsAsync),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.primary, size: 32),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAnalyticsDialog(BuildContext context, WidgetRef ref, AsyncValue statsAsync) {
    statsAsync.when(
      data: (stats) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Listener & Stream Analytics', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Active Stations', '${stats.activeStations}/${stats.totalStations}'),
                _buildStatRow('Published Schedules', '${stats.publishedSchedules}/${stats.totalSchedules}'),
                _buildStatRow('Gateway Health', stats.isServerHealthy ? 'ONLINE' : 'CHECKING'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        );
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _GreenBottomWave extends StatelessWidget {
  const _GreenBottomWave();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: CustomPaint(
          painter: _BottomWavePainter(),
        ),
      ),
    );
  }
}

class _BottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(0, h * 0.75);
    path.cubicTo(w * 0.3, h * 0.45, w * 0.65, h * 0.95, w, h * 0.65);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.3),
          AppColors.primary.withValues(alpha: 0.0),
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

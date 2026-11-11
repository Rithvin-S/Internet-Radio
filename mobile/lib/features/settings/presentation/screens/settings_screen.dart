import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/domain/models/user.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logout_confirmation_dialog.dart';
import '../../../stations/presentation/providers/stations_provider.dart';
import '../providers/settings_providers.dart';

/// Exact Reference Settings Screen:
/// Matches the reference UI specification with profile card, high-fidelity settings rows,
/// toggle switches, and the dark red Log Out button.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _lockScreenControls = true;
  bool _backgroundPlayback = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final isAuthenticated = authState.isAuthenticated && user != null;
    final isAdmin = isAuthenticated && user.role == UserRole.admin;
    final settings = ref.watch(userSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Account Card matching reference
              _buildProfileCard(context, ref, isAuthenticated, user, isAdmin),

              const SizedBox(height: 24),

              // 2. Settings Items List matching reference
              _buildSettingsItem(
                icon: Icons.volume_up_outlined,
                title: 'Audio Quality',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('High', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                  ],
                ),
                onTap: () => _showAudioQualityDialog(context),
              ),

              _buildSettingsItem(
                icon: Icons.layers_outlined,
                title: 'Background Playback',
                trailing: Switch(
                  value: _backgroundPlayback,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _backgroundPlayback = val);
                  },
                ),
              ),

              _buildSettingsItem(
                icon: Icons.lock_clock_outlined,
                title: 'Lock Screen Controls',
                trailing: Switch(
                  value: _lockScreenControls,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _lockScreenControls = val);
                  },
                ),
              ),

              _buildSettingsItem(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                onTap: () {},
              ),

              _buildSettingsItem(
                icon: Icons.wifi_off_rounded,
                title: 'Offline Mode',
                trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                onTap: () {},
              ),

              _buildSettingsItem(
                icon: Icons.info_outline_rounded,
                title: 'About',
                trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                onTap: () => _showAboutDialog(context),
              ),

              // Admin Portal Link for authenticated admins
              if (isAdmin) ...[
                const SizedBox(height: 12),
                _buildSettingsItem(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin Dashboard',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.primary),
                  onTap: () => context.push(RouteNames.admin),
                ),
              ],

              const SizedBox(height: 36),

              // 3. Exact Reference Log Out Button (Dark reddish brown with red text)
              if (isAuthenticated)
                InkWell(
                  onTap: () async {
                    final shouldLogout = await LogoutConfirmationDialog.show(context);
                    if (shouldLogout) {
                      await ref.read(authNotifierProvider.notifier).logout();
                      if (context.mounted) {
                        context.go(RouteNames.login);
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.logoutButtonBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(
                        color: AppColors.logoutText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () => context.push(RouteNames.login),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    WidgetRef ref,
    bool isAuthenticated,
    User? user,
    bool isAdmin,
  ) {
    final name = isAuthenticated ? (user?.name ?? 'Listener') : 'Guest Listener';
    final email = isAuthenticated ? (user?.email ?? 'signed-in user') : 'Sign in to sync favourites';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Green circular avatar matching reference
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // User Name & Email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAudioQualityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Audio Quality', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('High (192-320 kbps MP3)', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.check, color: AppColors.primary),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text('Standard (128 kbps)', style: TextStyle(color: AppColors.textSecondary)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text('Low / Data Saver (64 kbps)', style: TextStyle(color: AppColors.textSecondary)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('About PulseCast', style: TextStyle(color: Colors.white)),
        content: const Text(
          'PulseCast Internet Radio Streaming v1.0.0\nHigh-fidelity 24/7 automated music broadcasting.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

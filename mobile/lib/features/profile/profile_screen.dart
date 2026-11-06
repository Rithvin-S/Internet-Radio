import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_typography.dart';
import '../../routing/route_names.dart';
import '../auth/presentation/providers/auth_providers.dart';
import '../auth/presentation/widgets/logout_confirmation_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final isAuthenticated = authState.isAuthenticated;
    final isAdmin = authState.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.navProfile),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: isAuthenticated && user != null
              ? _buildAuthenticatedProfile(context, ref, user, isAdmin)
              : _buildGuestProfile(context),
        ),
      ),
    );
  }

  Widget _buildAuthenticatedProfile(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    bool isAdmin,
  ) {
    final initials = user.name.isNotEmpty
        ? user.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'U';

    final memberSince = user.createdAt != null
        ? '${user.createdAt!.year}-${user.createdAt!.month.toString().padLeft(2, '0')}-${user.createdAt!.day.toString().padLeft(2, '0')}'
        : 'Active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // User Header Card
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor:
                    isAdmin ? AppColors.accentAmber : AppColors.accentCyan,
                child: Text(
                  initials.toUpperCase(),
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.background,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              Text(
                user.name,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingMedium,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? AppColors.accentAmber.withValues(alpha: 0.15)
                      : AppColors.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  border: Border.all(
                    color: isAdmin
                        ? AppColors.accentAmber
                        : AppColors.accentCyan,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.headphones_rounded,
                      size: 16,
                      color: isAdmin
                          ? AppColors.accentAmber
                          : AppColors.accentCyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAdmin ? 'ADMINISTRATOR' : 'LISTENER',
                      style: AppTypography.caption.copyWith(
                        color: isAdmin
                            ? AppColors.accentAmber
                            : AppColors.accentCyan,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.paddingLarge),

        // Account Details Card
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Details',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: AppColors.borderSubtle, height: 24),
              _buildDetailRow('User ID', '#${user.id}'),
              const SizedBox(height: 12),
              _buildDetailRow('Role', user.role.toRoleString().toUpperCase()),
              const SizedBox(height: 12),
              _buildDetailRow('Member Since', memberSince),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.paddingLarge),

        // Admin Access Section (Only visible for Admins)
        if (isAdmin) ...[
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentAmber.withValues(alpha: 0.12),
                  AppColors.cardSurface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(
                color: AppColors.accentAmber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: AppColors.accentAmber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Management',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage stations, song libraries & schedules',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentAmber,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingMedium,
                      vertical: AppDimensions.paddingSmall,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall,
                      ),
                    ),
                  ),
                  onPressed: () => context.go(RouteNames.admin),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.paddingLarge),
        ],

        // Settings Tile
        Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: ListTile(
            leading: const Icon(Icons.settings_rounded, color: AppColors.accentCyan),
            title: const Text('Settings & Preferences'),
            subtitle: const Text('Offline cache, default stream, autoplay'),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            onTap: () => context.push(RouteNames.settings),
          ),
        ),

        // Sign Out Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentCoral,
            side: const BorderSide(color: AppColors.accentCoral),
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingMedium,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: Text(
            'Sign Out',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.accentCoral,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () async {
            final shouldLogout = await LogoutConfirmationDialog.show(context);
            if (shouldLogout) {
              await ref.read(authNotifierProvider.notifier).logout();
            }
          },
        ),
      ],
    );
  }

  Widget _buildGuestProfile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.surface,
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 36,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              Text(
                'Guest Listener',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in or register to bookmark stations, build favourites, and sync your radio experience across devices.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.paddingLarge),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan,
            foregroundColor: AppColors.background,
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingMedium,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
          onPressed: () => context.go(RouteNames.login),
          child: Text(
            'Sign In',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.background,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingMedium),

        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentCyan,
            side: const BorderSide(color: AppColors.accentCyan),
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingMedium,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
          onPressed: () => context.go(RouteNames.register),
          child: Text(
            'Create Account',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.accentCyan,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingMedium),

        // Settings Tile
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: ListTile(
            leading: const Icon(Icons.settings_rounded, color: AppColors.accentCyan),
            title: const Text('Settings & Preferences'),
            subtitle: const Text('Offline cache, default stream, autoplay'),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            onTap: () => context.push(RouteNames.settings),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/core/connectivity/connectivity_service.dart';
import 'package:pulsecast/core/constants/app_colors.dart';
import 'package:pulsecast/core/constants/app_dimensions.dart';
import 'package:pulsecast/core/theme/app_typography.dart';
import 'package:pulsecast/core/connectivity/connectivity_providers.dart';

/// Notification banner indicating offline device status or temporary backend unavailability
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityStatusProvider);

    // Never show an offline warning while verifying on startup or when online
    if (status == ConnectivityStatus.online ||
        status == ConnectivityStatus.checking ||
        status == ConnectivityStatus.unknown) {
      return const SizedBox.shrink();
    }

    final isDeviceOffline = status == ConnectivityStatus.offline;
    final message = isDeviceOffline
        ? "You're offline — showing saved information"
        : "PulseCast server is waking up — showing saved information";
    final icon = isDeviceOffline
        ? Icons.wifi_off_rounded
        : Icons.cloud_queue_rounded;
    final bannerBg = isDeviceOffline
        ? const Color(0xFF2C1E08)
        : const Color(0xFF1E293B);
    final accentColor = isDeviceOffline
        ? AppColors.accentAmber
        : AppColors.accentCyan;

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: bannerBg,
          border: Border(
            bottom: BorderSide(
              color: accentColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: accentColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
            InkWell(
              onTap: () {
                ref.read(connectivityStatusProvider.notifier).checkNow();
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'Retry',
                  style: AppTypography.caption.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../stations/domain/models/station.dart';
import '../../../stations/presentation/providers/stations_provider.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_station_form_dialog.dart';
import '../widgets/confirm_dialog.dart';

class AdminStationsScreen extends ConsumerWidget {
  final bool embedded;

  const AdminStationsScreen({
    super.key,
    this.embedded = false,
  });

  Future<void> _handleToggleStatus(
    BuildContext context,
    WidgetRef ref,
    Station station,
    bool nextStatus,
  ) async {
    try {
      final repo = ref.read(adminStationRepositoryProvider);
      await repo.toggleStationStatus(station.id, isActive: nextStatus);
      ref.invalidate(adminStationsListProvider);
      ref.invalidate(stationsListProvider);
      ref.invalidate(adminDashboardStatsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update station status: $e'),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteStation(
    BuildContext context,
    WidgetRef ref,
    Station station,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Station',
      message:
          'Are you sure you want to permanently delete station "${station.name}"? This will also remove associated queues.',
      confirmLabel: 'Delete Station',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (!confirmed || !context.mounted) return;

    try {
      final repo = ref.read(adminStationRepositoryProvider);
      await repo.deleteStation(station.id);
      ref.invalidate(adminStationsListProvider);
      ref.invalidate(stationsListProvider);
      ref.invalidate(adminDashboardStatsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Station "${station.name}" deleted.'),
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete station: $e'),
            backgroundColor: AppColors.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(adminStationsListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Station Management'),
              backgroundColor: AppColors.background,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Stations',
                  onPressed: () => ref.invalidate(adminStationsListProvider),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await AdminStationFormDialog.show(
            context,
            onSave: ({
              required name,
              description,
              genre,
              required streamUrl,
              artworkUrl,
              required isActive,
            }) async {
              final repo = ref.read(adminStationRepositoryProvider);
              await repo.createStation(
                name: name,
                description: description,
                genre: genre,
                streamUrl: streamUrl,
                artworkUrl: artworkUrl,
                isActive: isActive,
              );
            },
          );
          if (created) {
            ref.invalidate(adminStationsListProvider);
            ref.invalidate(stationsListProvider);
            ref.invalidate(adminDashboardStatsProvider);
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Station',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(adminStationsListProvider);
            await ref.read(adminStationsListProvider.future);
          },
          child: stationsAsync.when(
            data: (stations) {
              if (stations.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'No stations configured.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingLarge,
                  AppDimensions.paddingSmall,
                  AppDimensions.paddingLarge,
                  80,
                ),
                itemCount: stations.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppDimensions.paddingMedium),
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return _buildStationCard(context, ref, station);
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.accentCoral,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load stations: $e',
                    style: const TextStyle(color: AppColors.accentCoral),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(adminStationsListProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStationCard(
    BuildContext context,
    WidgetRef ref,
    Station station,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: station.isActive
              ? AppColors.borderSubtle
              : AppColors.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: station.isActive
                      ? AppColors.accentCyan.withValues(alpha: 0.15)
                      : AppColors.surfaceHighlight,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Icon(
                  Icons.cell_tower_rounded,
                  color: station.isActive
                      ? AppColors.accentCyan
                      : AppColors.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      station.genre ?? 'General Music',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Active toggle switch
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: station.isActive,
                  activeColor: AppColors.accentEmerald,
                  onChanged: (val) =>
                      _handleToggleStatus(context, ref, station, val),
                ),
              ),
            ],
          ),

          if (station.description != null &&
              station.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              station.description!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    station.streamUrl,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 4),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                onPressed: () async {
                  final saved = await AdminStationFormDialog.show(
                    context,
                    station: station,
                    onSave: ({
                      required name,
                      description,
                      genre,
                      required streamUrl,
                      artworkUrl,
                      required isActive,
                    }) async {
                      final repo = ref.read(adminStationRepositoryProvider);
                      await repo.updateStation(
                        station.id,
                        name: name,
                        description: description,
                        genre: genre,
                        streamUrl: streamUrl,
                        artworkUrl: artworkUrl,
                        isActive: isActive,
                      );
                    },
                  );
                  if (saved) {
                    ref.invalidate(adminStationsListProvider);
                    ref.invalidate(stationsListProvider);
                  }
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentCoral,
                ),
                onPressed: () => _handleDeleteStation(context, ref, station),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

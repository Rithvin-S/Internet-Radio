import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../stations/domain/models/station.dart';
import '../../../stations/presentation/providers/stations_provider.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_station_form_dialog.dart';
import '../widgets/confirm_dialog.dart';

/// Admin Stations Management Screen aligned with the Reference UI design language.
class AdminStationsScreen extends ConsumerWidget {
  final bool embedded;

  const AdminStationsScreen({
    super.key,
    this.embedded = false,
  });

  static Future<void> openCreateDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
  }

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

  Future<void> _handleEditStation(
    BuildContext context,
    WidgetRef ref,
    Station station,
  ) async {
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
              backgroundColor: AppColors.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: context.canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      color: Colors.white,
                      onPressed: () => context.pop(),
                    )
                  : null,
              title: const Text(
                'Stations',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
                  tooltip: 'Refresh Stations',
                  onPressed: () => ref.invalidate(adminStationsListProvider),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16, left: 4),
                  child: GestureDetector(
                    onTap: () => openCreateDialog(context, ref),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
                    ),
                  ),
                ),
              ],
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
                      padding: EdgeInsets.symmetric(vertical: 72),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: stations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildStationCard(context, ref, stations[index]);
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                      textAlign: TextAlign.center,
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
      ),
    );
  }

  Widget _buildStationCard(
    BuildContext context,
    WidgetRef ref,
    Station station,
  ) {
    final hasArtwork =
        station.artworkUrl != null && station.artworkUrl!.startsWith('http');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: station.isActive
              ? AppColors.border
              : AppColors.border.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 52,
              height: 52,
              color: station.isActive
                  ? AppColors.brandGreenDark
                  : AppColors.surfaceElevated,
              child: hasArtwork
                  ? CachedNetworkImage(
                      imageUrl: station.artworkUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.cell_tower_rounded,
                        color: station.isActive
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 24,
                      ),
                    )
                  : Icon(
                      Icons.cell_tower_rounded,
                      color: station.isActive
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  station.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  station.description?.isNotEmpty == true
                      ? station.description!
                      : (station.genre ?? '24/7 Live Radio'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  station.streamUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (station.isChannel6) ...[
            const SizedBox(width: 6),
            Material(
              color: const Color(0xFF2CE045).withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => context.push(RouteNames.adminChannel6Schedule),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF2CE045).withOpacity(0.45),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        color: Color(0xFF2CE045),
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Queue',
                        style: TextStyle(
                          color: Color(0xFF2CE045),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: station.isActive,
              activeColor: Colors.white,
              activeTrackColor: AppColors.primary,
              onChanged: (val) => _handleToggleStatus(context, ref, station, val),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            color: AppColors.surfaceElevated,
            onSelected: (value) {
              if (value == 'channel6_queue') {
                context.push(RouteNames.adminChannel6Schedule);
              } else if (value == 'edit') {
                _handleEditStation(context, ref, station);
              } else if (value == 'delete') {
                _handleDeleteStation(context, ref, station);
              }
            },
            itemBuilder: (_) => [
              if (station.isChannel6)
                const PopupMenuItem(
                  value: 'channel6_queue',
                  child: Row(
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        color: Color(0xFF2CE045),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text('Channel 6 Queue'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text('Edit Station'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.accentCoral, size: 18),
                    SizedBox(width: 10),
                    Text('Delete Station', style: TextStyle(color: AppColors.accentCoral)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

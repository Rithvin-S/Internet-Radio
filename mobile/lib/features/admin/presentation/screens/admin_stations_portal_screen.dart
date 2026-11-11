import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/admin_providers.dart';
import 'admin_schedules_screen.dart';
import 'admin_stations_screen.dart';

/// Combined Admin Portal Screen for Station & Schedule Management aligned with Reference UI.
class AdminStationsPortalScreen extends ConsumerStatefulWidget {
  const AdminStationsPortalScreen({super.key});

  @override
  ConsumerState<AdminStationsPortalScreen> createState() =>
      _AdminStationsPortalScreenState();
}

class _AdminStationsPortalScreenState
    extends ConsumerState<AdminStationsPortalScreen> {
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: canPop
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
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            tooltip: 'Refresh Data',
            onPressed: () {
              ref.invalidate(adminStationsListProvider);
              ref.invalidate(adminSchedulesListProvider);
              ref.invalidate(adminDashboardStatsProvider);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: () {
                if (_selectedSegment == 0) {
                  AdminStationsScreen.openCreateDialog(context, ref);
                } else {
                  AdminSchedulesScreen.openCreateDialog(context, ref);
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Clean Reference Segmented Pill Switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentTab(
                      label: 'Stations',
                      icon: Icons.cell_tower_rounded,
                      selected: _selectedSegment == 0,
                      onTap: () => setState(() => _selectedSegment = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentTab(
                      label: 'Schedules',
                      icon: Icons.calendar_month_rounded,
                      selected: _selectedSegment == 1,
                      onTap: () => setState(() => _selectedSegment = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedSegment,
              children: const [
                AdminStationsScreen(embedded: true),
                AdminSchedulesScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.black : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.black : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

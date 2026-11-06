import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/admin_providers.dart';
import 'admin_stations_screen.dart';
import 'admin_schedules_screen.dart';

/// Combined Admin Portal Screen for Station & Schedule Management
class AdminStationsPortalScreen extends ConsumerStatefulWidget {
  const AdminStationsPortalScreen({super.key});

  @override
  ConsumerState<AdminStationsPortalScreen> createState() =>
      _AdminStationsPortalScreenState();
}

class _AdminStationsPortalScreenState
    extends ConsumerState<AdminStationsPortalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stations & Schedules'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Data',
            onPressed: () {
              ref.invalidate(adminStationsListProvider);
              ref.invalidate(adminSchedulesListProvider);
              ref.invalidate(adminDashboardStatsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentCyan,
          indicatorWeight: 3,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.cell_tower_rounded, size: 20),
              text: 'Stations',
            ),
            Tab(
              icon: Icon(Icons.calendar_month_rounded, size: 20),
              text: 'Schedules',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AdminStationsScreen(embedded: true),
          AdminSchedulesScreen(embedded: true),
        ],
      ),
    );
  }
}


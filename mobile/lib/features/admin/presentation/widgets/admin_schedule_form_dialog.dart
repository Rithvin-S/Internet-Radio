import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:pulsecast/features/admin/domain/models/admin_schedule.dart';
import '../providers/admin_providers.dart';

class AdminScheduleFormDialog extends ConsumerStatefulWidget {
  final AdminSchedule? schedule;
  final Future<void> Function(AdminSchedule schedule) onSave;

  const AdminScheduleFormDialog({
    super.key,
    this.schedule,
    required this.onSave,
  });

  static Future<bool> show(
    BuildContext context, {
    AdminSchedule? schedule,
    required Future<void> Function(AdminSchedule schedule) onSave,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AdminScheduleFormDialog(schedule: schedule, onSave: onSave),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AdminScheduleFormDialog> createState() =>
      _AdminScheduleFormDialogState();
}

class _AdminScheduleFormDialogState
    extends ConsumerState<AdminScheduleFormDialog> {
  int? _selectedStationId;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _isPublished;
  late bool _isRecurring;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _selectedStationId = s?.stationId;
    _titleController = TextEditingController(text: s?.title ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _categoryController = TextEditingController(text: s?.category ?? 'Music');

    if (s?.scheduleDate != null && s!.scheduleDate.isNotEmpty) {
      _selectedDate = DateTime.tryParse(s.scheduleDate) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }

    _startTime = s != null ? _parseTime(s.startTime) : const TimeOfDay(hour: 9, minute: 0);
    _endTime = s != null ? _parseTime(s.endTime) : const TimeOfDay(hour: 12, minute: 0);
    _isPublished = s?.isPublished ?? false;
    _isRecurring = s?.isRecurring ?? false;
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (_) {
      return const TimeOfDay(hour: 10, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (_selectedStationId == null) {
      setState(() => _errorMessage = 'Please select a broadcast station.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a broadcast program title.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final scheduleObj = AdminSchedule(
      id: widget.schedule?.id ?? 0,
      stationId: _selectedStationId!,
      title: title,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      category: _categoryController.text.trim().isNotEmpty
          ? _categoryController.text.trim()
          : null,
      scheduleDate: _formatDate(_selectedDate),
      startTime: _formatTimeOfDay(_startTime),
      endTime: _formatTimeOfDay(_endTime),
      isPublished: _isPublished,
      isRecurring: _isRecurring,
      songs: widget.schedule?.songs ?? const [],
    );

    try {
      await widget.onSave(scheduleObj);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.statusCode == 409) {
            _errorMessage =
                'Schedule Conflict: Overlaps with an existing published programme on this station during ${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}.';
          } else {
            _errorMessage = e.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.schedule != null;
    final stationsAsync = ref.watch(adminStationsListProvider);

    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      title: Text(
        isEdit ? 'Edit Program Schedule' : 'Create Program Schedule',
        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.accentCoral.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.accentCoral.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.accentCoral,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.accentCoral,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Station Selector
            stationsAsync.when(
              data: (stations) {
                final traditionalStations =
                    stations.where((s) => !s.isChannel6).toList();
                final selectableStations = traditionalStations.isNotEmpty
                    ? traditionalStations
                    : stations;
                if ((_selectedStationId == null ||
                        !selectableStations.any((s) => s.id == _selectedStationId)) &&
                    selectableStations.isNotEmpty) {
                  _selectedStationId = selectableStations.first.id;
                }
                return DropdownButtonFormField<int>(
                  value: _selectedStationId,
                  dropdownColor: AppColors.surfaceElevated,
                  decoration: const InputDecoration(
                    labelText: 'Broadcast Station *',
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  items: selectableStations.map((s) {
                    return DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(
                        s.name,
                        style: const TextStyle(color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedStationId = val),
                );
              },
              loading: () => const LinearProgressIndicator(color: AppColors.primary),
              error: (_, __) => const Text('Could not load stations'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Programme Title *',
                hintText: 'e.g. Morning Acoustic Awakening',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category / Genre',
                hintText: 'e.g. Jazz, Rock, Morning Show',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),

            // Date Picker Row
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_rounded,
                  color: AppColors.accentCyan),
              title: const Text('Schedule Date'),
              subtitle: Text(
                _formatDate(_selectedDate),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2030),
                  builder: (context, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary,
                        surface: AppColors.surfaceElevated,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
            ),

            // Time Pickers Row
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start Time', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      _formatTimeOfDay(_startTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: const Icon(Icons.access_time_rounded, size: 18),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (picked != null) {
                        setState(() => _startTime = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End Time', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      _formatTimeOfDay(_endTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: const Icon(Icons.access_time_rounded, size: 18),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (picked != null) {
                        setState(() => _endTime = picked);
                      }
                    },
                  ),
                ),
              ],
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publish Immediately'),
              subtitle: Text(
                _isPublished ? 'Live & broadcastable' : 'Saved as draft',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              value: _isPublished,
              activeColor: AppColors.accentEmerald,
              onChanged: (val) => setState(() => _isPublished = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Text(isEdit ? 'Save Changes' : 'Create Schedule'),
        ),
      ],
    );
  }
}

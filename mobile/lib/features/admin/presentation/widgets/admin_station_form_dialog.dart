import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../stations/domain/models/station.dart';

class AdminStationFormDialog extends StatefulWidget {
  final Station? station; // Null for create, non-null for edit
  final Future<void> Function({
    required String name,
    String? description,
    String? genre,
    required String streamUrl,
    String? artworkUrl,
    required bool isActive,
  }) onSave;

  const AdminStationFormDialog({
    super.key,
    this.station,
    required this.onSave,
  });

  static Future<bool> show(
    BuildContext context, {
    Station? station,
    required Future<void> Function({
      required String name,
      String? description,
      String? genre,
      required String streamUrl,
      String? artworkUrl,
      required bool isActive,
    }) onSave,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AdminStationFormDialog(station: station, onSave: onSave),
    );
    return result ?? false;
  }

  @override
  State<AdminStationFormDialog> createState() => _AdminStationFormDialogState();
}

class _AdminStationFormDialogState extends State<AdminStationFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _genreController;
  late final TextEditingController _streamUrlController;
  late final TextEditingController _artworkUrlController;
  late bool _isActive;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final s = widget.station;
    _nameController = TextEditingController(text: s?.name ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _genreController = TextEditingController(text: s?.genre ?? '');
    _streamUrlController = TextEditingController(text: s?.streamUrl ?? '');
    _artworkUrlController = TextEditingController(text: s?.artworkUrl ?? '');
    _isActive = s?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _genreController.dispose();
    _streamUrlController.dispose();
    _artworkUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final streamUrl = _streamUrlController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Station name is required.');
      return;
    }
    if (streamUrl.isEmpty) {
      setState(() => _errorMessage = 'Stream URL is required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        name: name,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        genre: _genreController.text.trim().isNotEmpty
            ? _genreController.text.trim()
            : null,
        streamUrl: streamUrl,
        artworkUrl: _artworkUrlController.text.trim().isNotEmpty
            ? _artworkUrlController.text.trim()
            : null,
        isActive: _isActive,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
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
    final isEdit = widget.station != null;

    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      title: Text(
        isEdit ? 'Edit Station' : 'Create New Station',
        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentCoral.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.accentCoral.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.accentCoral,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Station Name *',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _genreController,
              decoration: const InputDecoration(
                labelText: 'Genre / Category',
                hintText: 'e.g. Electronic / Chillwave',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _streamUrlController,
              decoration: const InputDecoration(
                labelText: 'Stream URL *',
                hintText: 'https://...',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artworkUrlController,
              decoration: const InputDecoration(
                labelText: 'Artwork URL (Optional)',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active Station'),
              subtitle: Text(
                _isActive ? 'Broadcasting publicly' : 'Hidden from listeners',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              value: _isActive,
              activeColor: AppColors.accentEmerald,
              onChanged: (val) => setState(() => _isActive = val),
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
              : Text(isEdit ? 'Save Changes' : 'Create Station'),
        ),
      ],
    );
  }
}

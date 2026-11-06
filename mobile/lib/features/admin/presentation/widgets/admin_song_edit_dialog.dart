import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song.dart';

class AdminSongEditDialog extends StatefulWidget {
  final AdminSong song;
  final Future<void> Function(
    String id, {
    String? title,
    String? artist,
    String? album,
    bool? isActive,
  }) onSave;

  const AdminSongEditDialog({
    super.key,
    required this.song,
    required this.onSave,
  });

  static Future<bool> show(
    BuildContext context, {
    required AdminSong song,
    required Future<void> Function(
      String id, {
      String? title,
      String? artist,
      String? album,
      bool? isActive,
    }) onSave,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AdminSongEditDialog(song: song, onSave: onSave),
    );
    return result ?? false;
  }

  @override
  State<AdminSongEditDialog> createState() => _AdminSongEditDialogState();
}

class _AdminSongEditDialogState extends State<AdminSongEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  late bool _isActive;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
    _albumController = TextEditingController(text: widget.song.album ?? '');
    _isActive = widget.song.isActive;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Title is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        widget.song.id,
        title: title,
        artist: artist.isNotEmpty ? artist : 'Unknown Artist',
        album: _albumController.text.trim().isNotEmpty
            ? _albumController.text.trim()
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
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      title: Text(
        'Edit Song Metadata',
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
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Song Title',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(
                labelText: 'Artist',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _albumController,
              decoration: const InputDecoration(
                labelText: 'Album (Optional)',
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active Status'),
              subtitle: Text(
                _isActive ? 'Available in library' : 'Archived (hidden)',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              value: _isActive,
              activeColor: AppColors.primary,
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
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

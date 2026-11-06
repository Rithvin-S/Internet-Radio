import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/admin_providers.dart';

class AdminSongUploadScreen extends ConsumerStatefulWidget {
  const AdminSongUploadScreen({super.key});

  @override
  ConsumerState<AdminSongUploadScreen> createState() =>
      _AdminSongUploadScreenState();
}

class _AdminSongUploadScreenState extends ConsumerState<AdminSongUploadScreen> {
  PlatformFile? _pickedFile;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _albumController = TextEditingController();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedFile = file;
          _errorMessage = null;

          // Prefill title from filename if empty
          if (_titleController.text.isEmpty) {
            final rawName = file.name;
            final lastDot = rawName.lastIndexOf('.');
            final base = lastDot != -1 ? rawName.substring(0, lastDot) : rawName;
            _titleController.text = base.replaceAll('_', ' ').replaceAll('-', ' ');
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to select file: $e');
    }
  }

  Future<void> _handleUpload() async {
    if (_pickedFile == null || _pickedFile!.path == null) {
      setState(() => _errorMessage = 'Please select an audio file first.');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a song title.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminSongRepositoryProvider);
      await repo.uploadSong(
        filePath: _pickedFile!.path!,
        title: title,
        artist: _artistController.text.trim().isNotEmpty
            ? _artistController.text.trim()
            : null,
        album: _albumController.text.trim().isNotEmpty
            ? _albumController.text.trim()
            : null,
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() {
              _uploadProgress = sent / total;
            });
          }
        },
      );

      // Invalidate relevant providers
      ref.invalidate(adminSongsListProvider);
      ref.invalidate(adminSongStatsProvider);
      ref.invalidate(adminDashboardStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Song "$title" uploaded to Supabase Storage!'),
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        if (e.statusCode == 409) {
          _errorMessage =
              'Duplicate File: This audio track already exists in your library (matching filename or audio content hash).';
        } else {
          _errorMessage = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorMessage = 'Upload failed: $e';
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Upload Song'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                  decoration: BoxDecoration(
                    color: AppColors.accentCoral.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(
                      color: AppColors.accentCoral.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.accentCoral,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
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
                const SizedBox(height: AppDimensions.paddingMedium),
              ],

              // File Picker Drop Zone
              GestureDetector(
                onTap: _isUploading ? null : _pickAudioFile,
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(
                      color: _pickedFile != null
                          ? AppColors.primary
                          : AppColors.borderLight,
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _pickedFile != null
                              ? Icons.audio_file_rounded
                              : Icons.cloud_upload_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _pickedFile != null
                            ? _pickedFile!.name
                            : 'Tap to select audio file',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pickedFile != null
                            ? '${_formatFileSize(_pickedFile!.size)} • Tap to change file'
                            : 'Supports MP3, WAV, AAC, FLAC (Max 50MB)',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.paddingLarge),

              // Metadata Form Fields
              Text(
                'Track Details',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingSmall),

              TextField(
                controller: _titleController,
                enabled: !_isUploading,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Song Title *',
                  filled: true,
                  fillColor: AppColors.cardSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),

              TextField(
                controller: _artistController,
                enabled: !_isUploading,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Artist Name',
                  hintText: 'e.g. Massive Attack',
                  filled: true,
                  fillColor: AppColors.cardSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),

              TextField(
                controller: _albumController,
                enabled: !_isUploading,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Album (Optional)',
                  hintText: 'e.g. Mezzanine',
                  filled: true,
                  fillColor: AppColors.cardSurface,
                ),
              ),

              const SizedBox(height: AppDimensions.paddingLarge),

              // Upload Progress Bar
              if (_isUploading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Uploading to Supabase Storage...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                      backgroundColor: AppColors.surfaceHighlight,
                      color: AppColors.primary,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingLarge),
              ],

              // Upload Button
              ElevatedButton.icon(
                onPressed:
                    _isUploading || _pickedFile == null ? null : _handleUpload,
                icon: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _isUploading ? 'Uploading Audio...' : 'Upload to Music Library',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

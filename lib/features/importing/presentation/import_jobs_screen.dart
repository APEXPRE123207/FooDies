import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import '../domain/import_job.dart';

class ImportJobsScreen extends ConsumerWidget {
  const ImportJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(importJobsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Import Activity'),
      ),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 56, color: AppColors.textMuted.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No Import Activity Yet',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Shared reels and pasted links will appear here.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final job = jobs[index];
              return _buildJobCard(context, ref, job);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Text('Error loading activity: $err', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, WidgetRef ref, ImportJobEntity job) {
    Color stageColor = AppColors.primary;
    IconData stageIcon = Icons.hourglass_top;

    if (job.currentStage == ImportStage.ready) {
      stageColor = AppColors.success;
      stageIcon = Icons.check_circle;
    } else if (job.currentStage == ImportStage.failed) {
      stageColor = AppColors.error;
      stageIcon = Icons.error_outline;
    } else if (job.currentStage == ImportStage.needs_input) {
      stageColor = AppColors.amber;
      stageIcon = Icons.edit_note;
    } else if (job.currentStage == ImportStage.retrying) {
      stageColor = AppColors.warning;
      stageIcon = Icons.refresh;
    } else if (job.status == JobStatus.in_progress) {
      stageIcon = Icons.sync;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: job.status == JobStatus.in_progress
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status badge & timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(
                label: job.currentStage.displayName,
                icon: stageIcon,
                color: stageColor,
              ),
              Text(
                _formatTimestamp(job.updatedAt),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // URL
          Text(
            job.sourceUrl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Progress indicator for in-progress jobs
          if (job.status == JobStatus.in_progress) ...[
            const SizedBox(height: 4),
            const LinearProgressIndicator(
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.primary,
              minHeight: 3,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getPlayfulStatusCopy(job.currentStage),
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Captured Transcript indicator (Answers: "How do I know if the transcript worked?")
          if (job.rawTranscript != null && job.rawTranscript!.trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.description, size: 15, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transcript Captured:',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.rawTranscript!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Captured Caption indicator
          if (job.rawCaption != null && job.rawCaption!.trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 2, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.description_outlined, size: 14, color: AppColors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Caption Captured:',
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.rawCaption!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error or status note
          if (job.lastError != null) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.3), width: 0.8),
              ),
              child: Text(
                job.lastError!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          ],

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Open Recipe if ready
              if (job.currentStage == ImportStage.ready && job.recipeId != null) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    backgroundColor: AppColors.success,
                  ),
                  icon: const Icon(Icons.restaurant, size: 16),
                  label: const Text('Open Recipe', style: TextStyle(fontSize: 13)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(recipeId: job.recipeId!),
                      ),
                    );
                  },
                ),
              ],

              // Manual Input button if needs_input or failed
              if (job.currentStage == ImportStage.needs_input || job.currentStage == ImportStage.failed) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.edit, size: 14, color: AppColors.amber),
                  label: const Text('Paste Caption', style: TextStyle(fontSize: 12, color: AppColors.amber)),
                  onPressed: () => _showManualInputDialog(context, ref, job),
                ),
                const SizedBox(width: 8),
              ],

              // Retry button
              if (job.canRetry) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('Retry', style: TextStyle(fontSize: 13)),
                  onPressed: () async {
                    await ref.read(importCoordinatorProvider).retryJob(job.id);
                  },
                ),
              ],

              // Cancel button for non-terminal jobs
              if (!job.isTerminal) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    await ref.read(importCoordinatorProvider).cancelJob(job.id);
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog(BuildContext context, WidgetRef ref, ImportJobEntity job) {
    final captionController = TextEditingController(text: job.rawCaption ?? '');
    final transcriptController = TextEditingController(text: job.rawTranscript ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Provide Recipe Text', style: TextStyle(color: AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the reel caption or ingredients below to extract and save the recipe.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: captionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Paste reel caption or ingredients here...',
                  labelText: 'Caption',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste, color: AppColors.primaryLight),
                    tooltip: 'Paste from clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        captionController.text = data!.text!.trim();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: transcriptController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Spoken Transcript or Notes (Optional)',
                  hintText: 'Paste transcript text or recipe notes if you have them...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste, color: AppColors.primaryLight),
                    tooltip: 'Paste transcript',
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        transcriptController.text = data!.text!.trim();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final caption = captionController.text.trim();
              final transcript = transcriptController.text.trim();
              if (caption.isEmpty && transcript.isEmpty) return;

              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              await ref.read(importCoordinatorProvider).submitManualInput(
                    job.id,
                    caption: caption.isNotEmpty ? caption : null,
                    transcript: transcript.isNotEmpty ? transcript : null,
                  );
            },
            child: const Text('Submit & Extract'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
  }

  String _getPlayfulStatusCopy(ImportStage stage) {
    switch (stage) {
      case ImportStage.queued:
        return 'Queueing background worker...';
      case ImportStage.extracting:
        return "Bypassing 'Comment for DM' gatekeeping & reading caption...";
      case ImportStage.transcribing:
        return 'Reading video subtitle tracks...';
      case ImportStage.structuring:
        return 'Structuring ingredients & calculating macro profile...';
      case ImportStage.ready:
        return 'Ready in your offline library!';
      case ImportStage.needs_input:
        return 'Needs input: paste caption or recipe steps';
      case ImportStage.retrying:
        return 'Reconnecting to Ollama Cloud...';
      case ImportStage.failed:
        return 'Import failed';
      case ImportStage.cancelled:
        return 'Import cancelled';
    }
  }
}

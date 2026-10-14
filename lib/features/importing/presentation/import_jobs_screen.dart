import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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
            const SizedBox(height: 8),
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
                'When social platforms restrict automated scraping, paste the reel caption or ingredients below to complete extraction.',
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
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Extract caption via InstaUstad:',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                    icon: const Icon(Icons.open_in_browser, size: 13, color: AppColors.primaryLight),
                    label: const Text('Open InstaUstad', style: TextStyle(fontSize: 11, color: AppColors.primaryLight)),
                    onPressed: () async {
                      final uri = Uri.parse('https://instaustad.com/instagram-reel-caption.php');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: transcriptController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Spoken transcript (optional)...',
                  labelText: 'Transcript',
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
              if (caption.isEmpty) return;

              Navigator.of(ctx).pop();
              await ref.read(importCoordinatorProvider).submitManualInput(
                    job.id,
                    caption: caption,
                    transcript: transcriptController.text.trim().isNotEmpty
                        ? transcriptController.text.trim()
                        : null,
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
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_parser.dart';
import '../../recipes/presentation/recipe_edit_screen.dart';

class ImportSheet extends ConsumerStatefulWidget {
  final String? initialUrl;

  const ImportSheet({super.key, this.initialUrl});

  @override
  ConsumerState<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<ImportSheet> {
  late TextEditingController _urlController;
  late TextEditingController _captionController;
  bool _showCaptionField = false;
  String _detectedPlatform = 'web';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _captionController = TextEditingController();
    if (widget.initialUrl != null) {
      _detectedPlatform = UrlParser.identifyPlatform(widget.initialUrl!);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _onUrlChanged(String val) {
    setState(() {
      _detectedPlatform = UrlParser.identifyPlatform(val);
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      final text = data!.text!.trim();
      final extracted = UrlParser.extractUrl(text);
      setState(() {
        _urlController.text = extracted ?? text;
        _detectedPlatform = UrlParser.identifyPlatform(_urlController.text);
      });
    }
  }

  Future<void> _startImport() async {
    final rawInput = _urlController.text.trim();
    if (rawInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or paste a reel link')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final coordinator = ref.read(importCoordinatorProvider);
      final caption = _captionController.text.trim();

      await coordinator.startImport(
        rawInput: rawInput,
        manualCaption: caption.isNotEmpty ? caption : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recipe import started in background!',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting import: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.link, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Import Recipe',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              _buildPlatformChip(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Paste an Instagram Reel, Facebook Video, or food post link.',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),

          // URL Input
          TextField(
            controller: _urlController,
            onChanged: _onUrlChanged,
            decoration: InputDecoration(
              hintText: 'https://www.instagram.com/reel/...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste, color: AppColors.primaryLight),
                tooltip: 'Paste from clipboard',
                onPressed: _pasteFromClipboard,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Toggle manual caption
          GestureDetector(
            onTap: () => setState(() => _showCaptionField = !_showCaptionField),
            child: Row(
              children: [
                Icon(
                  _showCaptionField ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.amber,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _showCaptionField ? 'Hide manual caption' : 'Add caption or notes manually (optional)',
                  style: const TextStyle(
                    color: AppColors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (_showCaptionField) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _captionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Paste caption or transcript here if reel is private or caption was copied...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste, color: AppColors.primaryLight),
                  tooltip: 'Paste caption',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      setState(() {
                        _captionController.text = data!.text!.trim();
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Need the caption? Extract via InstaUstad:',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  icon: const Icon(Icons.open_in_browser, size: 14, color: AppColors.primaryLight),
                  label: const Text('InstaUstad Extractor', style: TextStyle(fontSize: 11, color: AppColors.primaryLight)),
                  onPressed: () async {
                    final uri = Uri.parse('https://instaustad.com/instagram-reel-caption.php');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _startImport,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 20),
              label: Text(_isSubmitting ? 'Starting...' : 'Extract & Save Recipe'),
            ),
          ),
          const SizedBox(height: 12),

          // Manual creation fallback
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.edit_note, size: 18, color: AppColors.textSecondary),
              label: const Text(
                'Or write a recipe manually',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecipeEditScreen()),
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildPlatformChip() {
    String label = 'Link';
    Color color = AppColors.textMuted;
    if (_detectedPlatform == 'instagram') {
      label = 'Instagram';
      color = const Color(0xFFE1306C);
    } else if (_detectedPlatform == 'facebook') {
      label = 'Facebook';
      color = const Color(0xFF1877F2);
    } else if (_detectedPlatform == 'youtube') {
      label = 'YouTube';
      color = const Color(0xFFFF0000);
    } else if (_detectedPlatform == 'tiktok') {
      label = 'TikTok';
      color = Colors.cyanAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

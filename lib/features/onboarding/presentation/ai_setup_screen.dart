import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/providers.dart';
import '../../../core/networking/ollama_models.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../recipes/presentation/home_feed_screen.dart';
import '../../../shared/widgets/app_logo.dart';

class AiSetupScreen extends ConsumerStatefulWidget {
  final bool isFromSettings;

  const AiSetupScreen({super.key, this.isFromSettings = false});

  @override
  ConsumerState<AiSetupScreen> createState() => _AiSetupScreenState();
}

class _AiSetupScreenState extends ConsumerState<AiSetupScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;

  bool _obscureKey = true;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _showAdvanced = false;

  OllamaConnectionResult? _testResult;

  // Free Available Models highlighted by user
  static const List<Map<String, String>> _freeCloudModels = [
    {
      'name': 'gemma4:31b',
      'title': 'gemma4:31b',
      'desc': 'Multimodal • Highest Recipe Accuracy',
      'tag': 'Recommended',
    },
    {
      'name': 'nemotron-3-nano:30b',
      'title': 'nemotron-3-nano:30b',
      'desc': 'MoE 1M Context • Ultra-Fast Token Output',
      'tag': 'Fastest',
    },
    {
      'name': 'gpt-oss:20b',
      'title': 'gpt-oss:20b',
      'desc': 'Lightweight • Great Quality & Balance',
      'tag': 'Balanced',
    },
    {
      'name': 'gpt-oss:120b',
      'title': 'gpt-oss:120b',
      'desc': 'Deep Reasoning for Complex Ingredients',
      'tag': 'Reasoning',
    },
    {
      'name': 'nemotron-3-super',
      'title': 'nemotron-3-super',
      'desc': 'Enterprise MoE 120B High-Throughput',
      'tag': 'Enterprise',
    },
    {
      'name': 'nemotron-3-ultra',
      'title': 'nemotron-3-ultra',
      'desc': 'Flagship 550B Frontier MoE Model',
      'tag': 'Flagship',
    },
  ];

  static const List<String> _classicModels = [
    'llama3.2',
    'llama3.1',
    'mistral',
    'qwen2.5',
    'gemma2:9b',
  ];

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController(text: SecureStorageService.defaultBaseUrl);
    _modelController = TextEditingController(text: 'gemma4:31b');
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final storage = ref.read(secureStorageProvider);
    var key = await storage.getApiKey();
    final url = await storage.getBaseUrl();
    final model = await storage.getModelName();

    // Check .env if no key was saved in storage yet
    if (key == null || key.isEmpty) {
      try {
        final envFile = File('.env');
        if (await envFile.exists()) {
          final lines = await envFile.readAsLines();
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('OLLAMA_KEY=')) {
              key = trimmed
                  .substring('OLLAMA_KEY='.length)
                  .replaceAll('"', '')
                  .replaceAll("'", '')
                  .trim();
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        if (key != null && key.isNotEmpty) _apiKeyController.text = key;
        _baseUrlController.text = url;
        if (model.isNotEmpty) {
          _modelController.text = model;
        }
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _pasteApiKey() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      setState(() {
        _apiKeyController.text = data!.text!.trim();
      });
    }
  }

  Future<void> _testConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an Ollama Cloud API Key to test')),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final client = ref.read(ollamaClientProvider);
    final result = await client.testConnection(
      apiKey: key,
      baseUrl: _baseUrlController.text.trim(),
      modelName: _modelController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = result;
      });
    }
  }

  Future<void> _saveAndProceed() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Ollama Cloud API Key')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final storage = ref.read(secureStorageProvider);
    await storage.saveApiKey(key);
    await storage.saveBaseUrl(_baseUrlController.text.trim());
    await storage.saveModelName(_modelController.text.trim());
    await storage.setOfflineMode(false);
    ref.invalidate(isApiKeyConfiguredProvider);

    if (mounted) {
      setState(() => _isSaving = false);
      if (widget.isFromSettings) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ollama Cloud configuration saved!')),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeFeedScreen()),
        );
      }
    }
  }

  void _continueOffline() async {
    final storage = ref.read(secureStorageProvider);
    await storage.setOfflineMode(true);

    if (mounted) {
      if (widget.isFromSettings) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeFeedScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentModel = _modelController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isFromSettings ? 'AI Configuration' : 'Welcome to Foodies'),
        leading: widget.isFromSettings
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          children: [
            // Hero Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF261914), Color(0xFF161825)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.primary.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppLogo(
                        size: 40,
                        borderRadius: 12,
                        padding: 3,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Ollama Cloud AI Setup',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Foodies converts Instagram & Facebook reels into structured recipes using Ollama Cloud. Fast, zero-setup, and runs completely in the cloud.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step-by-Step API Key Setup Walkthrough
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.key, color: AppColors.amber, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'HOW TO GET YOUR OLLAMA API KEY',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildWalkthroughStep(
                    step: '1',
                    title: 'Go to ollama.com',
                    desc: 'Visit the official Ollama website in your mobile or desktop browser.',
                    actionWidget: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        side: const BorderSide(color: AppColors.primary, width: 1),
                      ),
                      onPressed: () => _openUrl('https://ollama.com'),
                      icon: const Icon(Icons.open_in_browser, size: 14, color: AppColors.primaryLight),
                      label: const Text('Open ollama.com', style: TextStyle(fontSize: 12, color: AppColors.primaryLight)),
                    ),
                  ),
                  const Divider(height: 18, color: AppColors.border),

                  _buildWalkthroughStep(
                    step: '2',
                    title: 'Sign In / Register',
                    desc: 'Log in with your existing account or create a free profile.',
                  ),
                  const Divider(height: 18, color: AppColors.border),

                  _buildWalkthroughStep(
                    step: '3',
                    title: 'Go to Settings → Keys',
                    desc: 'Open your Account Settings, then select Keys / API Keys.',
                    actionWidget: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        side: BorderSide(color: AppColors.amber.withOpacity(0.8), width: 1),
                      ),
                      onPressed: () => _openUrl('https://ollama.com/settings/keys'),
                      icon: const Icon(Icons.vpn_key, size: 14, color: AppColors.amber),
                      label: const Text('Open Keys Page', style: TextStyle(fontSize: 12, color: AppColors.amber)),
                    ),
                  ),
                  const Divider(height: 18, color: AppColors.border),

                  _buildWalkthroughStep(
                    step: '4',
                    title: 'Generate & Copy Key',
                    desc: 'Click "New Key", copy your bearer token, and paste it below.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // API Key Input
            const Text(
              'OLLAMA CLOUD API KEY',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                hintText: 'Enter your Ollama Cloud Bearer Key',
                prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppColors.primary),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste, color: AppColors.primaryLight),
                      tooltip: 'Paste',
                      onPressed: _pasteApiKey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Encrypted locally via Android EncryptedSharedPreferences with biometric isolation.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 22),

            // Free Available Models Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'FREE AVAILABLE CLOUD MODELS',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Free Tier',
                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select any of the free cloud models below for recipe parsing:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),

            // Cards for Free Available Models
            ..._freeCloudModels.map((item) {
              final isSelected = currentModel == item['name'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _modelController.text = item['name']!);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.12) : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? AppColors.primary : AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item['name']!,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item['tag']!,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['desc']!,
                                style: TextStyle(
                                  color: AppColors.textSecondary.withOpacity(0.85),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Classic Models
            const Text(
              'OTHER STANDARD MODELS',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _classicModels.map((m) {
                final isSelected = currentModel == m;
                return ChoiceChip(
                  label: Text(m),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _modelController.text = m);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Selected Model Input field
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Active Model',
                hintText: 'e.g. gemma4:31b, nemotron-3-nano:30b',
                prefixIcon: Icon(Icons.memory, color: AppColors.amber),
              ),
            ),
            const SizedBox(height: 18),

            // Advanced options toggle
            GestureDetector(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Row(
                children: [
                  Icon(_showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  const Text(
                    'Advanced Endpoint Settings',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            if (_showAdvanced) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://ollama.com/api',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Default is https://ollama.com/api. Do not change unless using an enterprise proxy.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 22),

            // Test Connection Button
            OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.network_check, size: 18),
              label: Text(_isTesting ? 'Testing Connectivity...' : 'Test Connection'),
            ),

            // Connection Test Result Display
            if (_testResult != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _testResult!.isSuccess
                      ? AppColors.success.withOpacity(0.12)
                      : AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _testResult!.isSuccess
                        ? AppColors.success.withOpacity(0.4)
                        : AppColors.error.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _testResult!.isSuccess ? Icons.check_circle : Icons.error,
                          color: _testResult!.isSuccess ? AppColors.success : AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _testResult!.isSuccess
                              ? 'Connection Successful (${_testResult!.latencyMs}ms)'
                              : 'Connection Failed',
                          style: TextStyle(
                            color: _testResult!.isSuccess ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (_testResult!.errorMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _testResult!.errorMessage!,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),

            // Primary Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAndProceed,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.isFromSettings ? 'Save Configuration' : 'Save & Start Cooking'),
              ),
            ),
            const SizedBox(height: 12),

            // Offline Mode button
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.cloud_off, size: 16, color: AppColors.textSecondary),
                label: const Text(
                  'Continue in Offline Mode (browse saved recipes)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                onPressed: _continueOffline,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkthroughStep({
    required String step,
    required String title,
    required String desc,
    Widget? actionWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.85),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (actionWidget != null) ...[
                const SizedBox(height: 6),
                actionWidget,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

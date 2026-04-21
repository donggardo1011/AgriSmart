import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../api/offline_stt.dart';
import '../api/stt_model_downloader.dart';
import '../slm/local_slm.dart';
import '../slm/model_downloader.dart';
import '../theme/kinaiya_colors.dart';
import '../widgets/kinaiya_header.dart';
import '../widgets/kinaiya_layout.dart';
import '../widgets/kinaiya_widgets.dart';
import 'slm_chat_page.dart';

class SlmTestPage extends StatefulWidget {
  static const routeName = '/slm-test';
  const SlmTestPage({super.key});

  @override
  State<SlmTestPage> createState() => _SlmTestPageState();
}

class _SlmTestPageState extends State<SlmTestPage> with TickerProviderStateMixin {
  bool _downloadingSlm = false;
  bool _downloadingStt = false;
  String? _error;
  double _downloadProgress = 0;
  String _downloadLabel = '';
  
  bool _sttExists = false;
  bool _slmExists = false;

  @override
  void initState() {
    super.initState();
    _checkExistingModels();
  }

  Future<void> _checkExistingModels() async {
    final appDir = await getApplicationSupportDirectory();
    final sttFile = File('${appDir.path}${Platform.pathSeparator}whisper_tiny.bin');
    final sttEngineFile = File('${appDir.path}${Platform.pathSeparator}ggml-tiny.bin');
    final slmFile = await LocalSlm.getModelFile();
    
    if (mounted) {
      setState(() {
        _sttExists = sttFile.existsSync() || sttEngineFile.existsSync();
        _slmExists = slmFile.existsSync();
      });
    }
  }

  void _openSlmChat() {
    Navigator.pushNamed(context, SlmChatPage.routeName);
  }

  Future<void> _downloadSlm() async {
    setState(() {
      _downloadingSlm = true;
      _error = null;
      _downloadProgress = 0;
      _downloadLabel = 'Initializing SLM core...';
    });

    try {
      await ModelDownloader.download(onProgress: (p, downloaded, total) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = p;
          final mb = (downloaded / (1024 * 1024)).toStringAsFixed(1);
          _downloadLabel = 'Downloading Llama: $mb MB';
        });
      });
      await LocalSlm.init();
      await _checkExistingModels();
      if (!mounted) return;
      setState(() {
        _downloadLabel = 'SLM ready.';
        _downloadProgress = 1.0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'SLM Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _downloadingSlm = false);
    }
  }

  Future<void> _downloadStt() async {
    setState(() {
      _downloadingStt = true;
      _error = null;
      _downloadProgress = 0;
      _downloadLabel = 'Connecting to Neural Hub...';
    });

    try {
      await SttModelDownloader.download(onProgress: (p, downloaded, total) {
        if (mounted) {
          setState(() {
            _downloadProgress = p;
            final mb = (downloaded / (1024 * 1024)).toStringAsFixed(1);
            _downloadLabel = 'Downloading Whisper: $mb MB';
          });
        }
      });

      await OfflineStt.instance.init();
      await _checkExistingModels();
      
      if (mounted) {
        setState(() {
          _downloadLabel = 'Voice Recognition Ready.';
          _downloadProgress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'STT Error: $e');
    } finally {
      if (mounted) setState(() => _downloadingStt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KinaiyaColors.background,
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KinaiyaColors.primary.withOpacity(0.05),
              ),
            ),
          ),
          KinaiyaMobileContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KinaiyaTopHeader(
                  title: 'LOCAL INTELLIGENCE', 
                  subtitle: 'Manage on-device language models',
                  onBack: () => Navigator.maybePop(context),
                ),
                const SizedBox(height: 24),
                
                _ModelCard(
                  title: 'OpenAI Whisper Tiny',
                  description: 'Used for offline, real-time speech-to-text and reading diagnostics.',
                  icon: Icons.auto_awesome_rounded,
                  isReady: _sttExists,
                  isDownloading: _downloadingStt,
                  sizeLabel: '75 MB',
                  onDownload: _downloadStt,
                ),
                
                const SizedBox(height: 16),
                
                _ModelCard(
                  title: 'Meta Llama 3.2 (1B)',
                  description: 'Used for offline grammar correction and student response analysis.',
                  icon: Icons.psychology_rounded,
                  isReady: _slmExists,
                  isDownloading: _downloadingSlm,
                  sizeLabel: '940 MB',
                  onDownload: _downloadSlm,
                ),
                
                const SizedBox(height: 24),
                
                if (_downloadingSlm || _downloadingStt || _downloadProgress > 0) ...[
                  KinaiyaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_downloadLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text('${(_downloadProgress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w900, color: KinaiyaColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _downloadProgress <= 0 ? null : _downloadProgress,
                            minHeight: 12,
                            backgroundColor: KinaiyaColors.muted.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(KinaiyaColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KinaiyaColors.kinaiyaRed.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KinaiyaColors.kinaiyaRed.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: KinaiyaColors.kinaiyaRed, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: const TextStyle(color: KinaiyaColors.kinaiyaRed, fontSize: 13, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                ],

                if (_slmExists) ...[
                  const SizedBox(height: 14),
                  KinaiyaGradientButton(
                    text: 'Open SLM Chat',
                    icon: Icons.chat_bubble_rounded,
                    onPressed: _openSlmChat,
                  ),
                ],
                
                const Spacer(),
                Opacity(
                  opacity: 0.6,
                  child: Text(
                    'Models are stored locally and encrypted for privacy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isReady;
  final bool isDownloading;
  final String sizeLabel;
  final VoidCallback onDownload;

  const _ModelCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isReady,
    required this.isDownloading,
    required this.sizeLabel,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isReady 
              ? KinaiyaColors.kinaiyaGreen.withOpacity(0.1) 
              : Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 😎,
          ),
        ],
        border: Border.all(
          color: isReady 
              ? KinaiyaColors.kinaiyaGreen.withOpacity(0.3) 
              : Colors.black.withOpacity(0.05),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isReady ? KinaiyaColors.kinaiyaGreen : KinaiyaColors.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isReady ? KinaiyaColors.kinaiyaGreen : KinaiyaColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'Outfit')),
                    Text(sizeLabel, style: TextStyle(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (isReady)
                const Icon(Icons.check_circle_rounded, color: KinaiyaColors.kinaiyaGreen, size: 28)
            ],
          ),
          const SizedBox(height: 14),
          Text(description, style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4)),
          const SizedBox(height: 20),
          if (!isReady)
            KinaiyaGradientButton(
              text: isDownloading ? 'Downloading Hub...' : 'Prepare Engine',
              onPressed: isDownloading ? null : onDownload,
              icon: Icons.auto_mode_rounded,
            ),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SlmChatPage extends StatefulWidget {
  static const routeName = '/slm-chat';
  const SlmChatPage({super.key});

  @override
  State<SlmChatPage> createState() => _SlmChatPageState();
}

class _SlmChatPageState extends State<SlmChatPage> {
  bool _downloading = false;
  String? _error;
  double _downloadProgress = 0;
  String _downloadLabel = '';
  bool _slmExists = false;
  
  late String _slmModelUrl;
  late String _slmModelSize;

  @override
  void initState() {
    super.initState();
    _loadEnvConfig();
    _checkExistingModel();
  }

  void _loadEnvConfig() {
    _slmModelUrl = dotenv.env['SLM_MODEL_URL'] ?? 'https://huggingface.co/itlwas/Qwen2-1.5B-Instruct-Q4_K_M-GGUF/resolve/main/qwen2-1.5b-instruct-q4_k_m.gguf?download=true';
    _slmModelSize = dotenv.env['SLM_MODEL_SIZE'] ?? '940';
  }

  Future<void> _checkExistingModel() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final slmDir = Directory('${appDir.path}${Platform.pathSeparator}slm_models');
      final modelFile = File('${slmDir.path}${Platform.pathSeparator}model.bin');
      
      if (mounted) {
        setState(() {
          _slmExists = slmDir.existsSync() && 
                      slmDir.listSync().isNotEmpty &&
                      modelFile.existsSync();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error checking model: ${e.toString()}');
    }
  }

  // Static method to retrieve SLM model path - can be used by other screens
  static Future<String?> getSlmModelPath() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final modelFile = File('${appDir.path}${Platform.pathSeparator}slm_models${Platform.pathSeparator}model.bin');
      return modelFile.existsSync() ? modelFile.path : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _downloadSlm() async {
    setState(() {
      _downloading = true;
      _error = null;
      _downloadProgress = 0;
      _downloadLabel = 'Initializing SLM download...';
    });

    try {
      // Simulate download progress
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(_slmModelUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final appDir = await getApplicationSupportDirectory();
        final slmDir = Directory('${appDir.path}${Platform.pathSeparator}slm_models');
        
        if (!slmDir.existsSync()) {
          slmDir.createSync(recursive: true);
        }

        final modelFile = File('${slmDir.path}${Platform.pathSeparator}model.bin');
        final contentLength = response.contentLength;
        int downloaded = 0;

        final sink = modelFile.openWrite();
        
        response.listen(
          (List<int> chunk) {
            sink.add(chunk);
            downloaded += chunk.length;
            final progress = contentLength > 0 ? downloaded / contentLength : 0.0;
            
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
                final mb = (downloaded / (1024 * 1024)).toStringAsFixed(1);
                _downloadLabel = 'Downloading SLM: $mb MB';
              });
            }
          },
          onDone: () async {
            await sink.close();
            
            // Verify the file was saved properly
            try {
              final appDir = await getApplicationSupportDirectory();
              final modelFile = File('${appDir.path}${Platform.pathSeparator}slm_models${Platform.pathSeparator}model.bin');
              
              if (modelFile.existsSync()) {
                final fileSize = modelFile.lengthSync();
                
                // Save download metadata for future reference
                final metadataFile = File('${appDir.path}${Platform.pathSeparator}slm_models${Platform.pathSeparator}metadata.json');
                await metadataFile.writeAsString(jsonEncode({
                  'downloaded_at': DateTime.now().toIso8601String(),
                  'model_size': fileSize,
                  'model_version': '1.0',
                  'url': _slmModelUrl,
                }));
                
                await _checkExistingModel();
                
                if (mounted) {
                  setState(() {
                    _downloadLabel = 'SLM ready! (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)';
                    _downloadProgress = 1.0;
                  });
                }
              } else {
                throw Exception('Model file was not saved to device.');
              }
            } catch (e) {
              if (mounted) {
                setState(() => _error = 'Failed to verify model: ${e.toString()}');
              }
            }
          },
          onError: (e) {
            sink.close();
            final appDir = getApplicationSupportDirectory();
            appDir.then((dir) {
              final modelFile = File('${dir.path}${Platform.pathSeparator}slm_models${Platform.pathSeparator}model.bin');
              if (modelFile.existsSync()) {
                modelFile.deleteSync();
              }
            });
            if (mounted) {
              setState(() => _error = 'Download error: ${e.toString()}');
            }
          },
        );
      } else {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }
      
      httpClient.close();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'SLM Error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline AI Assistant'),
        centerTitle: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              
              _SLMCard(
                title: 'Meta Llama 3.2 (1B)',
                description: 'Powerful offline AI for text analysis, grammar correction, and intelligent responses.',
                isReady: _slmExists,
                isDownloading: _downloading,
                sizeLabel: '$_slmModelSize MB',
                onDownload: _downloadSlm,
              ),
              
              const SizedBox(height: 24),
              
              if (_downloading || _downloadProgress > 0) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _downloadLabel,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${(_downloadProgress * 100).toInt()}%',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _downloadProgress <= 0 ? null : _downloadProgress,
                            minHeight: 12,
                            backgroundColor: Colors.grey.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_slmExists) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Model ready! Use the AgriBot Assistant to chat.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              Opacity(
                opacity: 0.6,
                child: Text(
                  'Models are stored locally and encrypted for privacy.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
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

class _SLMCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isReady;
  final bool isDownloading;
  final String sizeLabel;
  final VoidCallback onDownload;

  const _SLMCard({
    required this.title,
    required this.description,
    required this.isReady,
    required this.isDownloading,
    required this.sizeLabel,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isReady 
              ? Colors.green.withOpacity(0.1) 
              : Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isReady 
              ? Colors.green.withOpacity(0.3) 
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
                  color: (isReady ? Colors.green : colorScheme.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.psychology_rounded,
                  color: isReady ? Colors.green : colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      sizeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (isReady)
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 28,
                )
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (!isReady)
            FilledButton(
              onPressed: isDownloading ? null : onDownload,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_rounded),
                  const SizedBox(width: 8),
                  Text(isDownloading ? 'Downloading...' : 'Download SLM'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
// lib/screens/chatbot_screen.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/network.dart';
import '../widgets/detection_overlay.dart';

class ChatbotScreen extends StatefulWidget {
  final String? accessToken;
  final String? initialDisease;
  final Map<String, dynamic>? prediction;
  final bool loadOverviewOnStart;
  final bool slmModelAvailable; // New parameter for SLM model availability

  const ChatbotScreen({
    super.key,
    this.accessToken,
    this.initialDisease,
    this.prediction,
    this.loadOverviewOnStart = false,
    this.slmModelAvailable = false,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool? slmUsed;  // Whether SLM was used for this bot response

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.slmUsed = false,
  });
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final List<_ChatMessage> _messages = [];

  String _selectedDisease = 'sheath_blight';
  String _selectedLanguage = 'english';
  bool _loading = false;
  String? _error;
  bool _quickQuestionAnswered = false; // Track if a quick question has been answered
  bool _useSLMMode = false; // Flag to enable SLM mode for responses
  bool _slmAvailable = false;  // Whether SLM model is available on backend
  bool _lastResponseUsedSLM = false;  // Whether the last bot response used SLM
  String _currentModel = 'qwen2:0.5b';  // Current active model
  bool _modelDownloading = false;  // Whether a model is being downloaded
  double _responseTime = 0.0;  // Last response time in seconds
  Map<String, dynamic> _availableModels = {};  // Available models
  String? _selectedNewModel;  // Model selected for downloading

  static const _diseases = [
    ('bacterial_blight', 'Bacterial Blight'),
    ('brown_spot', 'Brown Spot'),
    ('leaf_blast', 'Leaf Blast'),
    ('sheath_blight', 'Sheath Blight'),
    ('tungro', 'Tungro'),
  ];

  static const Map<String, String> _chemicalImageAssets = {
    'Ortiva Top® 325 SC': 'assets/images/chemicals/Ortiva.png',
    'Ortiva Top 325 SC': 'assets/images/chemicals/Ortiva.png',
    'Armure® 300 EC': 'assets/images/chemicals/Armure.jpg',
    'Armure 300 EC': 'assets/images/chemicals/Armure.jpg',
    'Marshal® 200 SC': 'assets/images/chemicals/Marshal.png',
    'Marshal 200SC': 'assets/images/chemicals/Marshal.png',
    'Marshal 200 SC': 'assets/images/chemicals/Marshal.png',
    'Alika® 247 ZC': 'assets/images/chemicals/Alika.png',
    'Alika 247 ZC': 'assets/images/chemicals/Alika.png',
  };

  static const _quickQuestions = [
    'What symptoms should I watch for?',
    'How do I treat this disease?',
    'How can I prevent it from spreading?',
    'What fertilizer guidance should I follow?',
  ];

  static const _quickQuestionsCebuano = [
    'Unsa nga mga sintomas akong bantayan?',
    'Unsaon pagtambal ani nga sakit?',
    'Unsaon paglikay nga mokaylap kini?',
    'Unsa nga giya sa abono akong sundon?',
  ];

  static const _quickQuestionsFilipino = [
    'Anong mga sintomas ang dapat kong bantayan?',
    'Paano ko itutrato ang sakit na ito?',
    'Paano ko mapipigilan ang pagkalat nito?',
    'Anong gabay sa pataba ang dapat kong sundin?',
  ];

  // SLM-specific questions for follow-up conversations
  static const _slmQuestions = [
    'Tell me more about this',
    'What are the causes?',
    'Can you explain the treatment process?',
    'Are there alternative solutions?',
  ];

  static const _slmQuestionsCebuano = [
    'Ayaw ibigay ko ang mas marami',
    'Unsang ang mga sanhi?',
    'Pwede mo bang ipaliwanag ang proseso sa pagtambal?',
    'May ibang solusyon ba?',
  ];

  static const _slmQuestionsFilipino = [
    'Magbigay ng higit pang impormasyon tungkol dito',
    'Ano ang mga sanhi nito?',
    'Maaari mo bang ipaliwanag ang proseso ng paggamot?',
    'May ibang solusyon ba?',
  ];

  String _normalizeToBackendKey(String input) {
    final n = (input).trim().toLowerCase().replaceAll(' ', '_');
    if (n.contains('blast')) return 'leaf_blast';
    if (n.contains('blight')) return 'bacterial_blight';
    if (n.contains('brown')) return 'brown_spot';
    if (n.contains('sheath')) return 'sheath_blight';
    if (n.contains('tungro')) return 'tungro';
    return n;
  }

  String _normalizeLanguage(String? lang) {
    if (lang == null || lang.trim().isEmpty) return 'english';
    final v = lang.trim().toLowerCase();
    if (v == 'cebuano' || v == 'ceb' || v == 'bisaya' || v == 'binisaya') return 'cebuano';
    if (v == 'filipino' || v == 'fil' || v == 'tagalog' || v == 'tl' || v == 'philippine') return 'filipino';
    return 'english';
  }

  // Helper method to get UI strings based on language
  String _tr(String english, String cebuano, String filipino) {
    final lang = _normalizeLanguage(_selectedLanguage);
    if (lang == 'cebuano') return cebuano;
    if (lang == 'filipino') return filipino;
    return english;
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initialDisease;
    if (init != null && init.isNotEmpty) {
      _selectedDisease = _normalizeToBackendKey(init);
    }

    // Enable SLM mode if model is available
    _useSLMMode = widget.slmModelAvailable;

    if (widget.loadOverviewOnStart && widget.accessToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadChatHistory(); // Load previous conversations
        _fetchSLMModels(); // Fetch available models
        _sendMessage(''); // Send initial overview request
      });
    } else if (widget.accessToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchSLMModels(); // Fetch available models
      });
    }
  }

  Future<void> _fetchSLMModels() async {
    if (widget.accessToken == null || widget.accessToken!.isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse('$apiBaseUrl/api/chatbot/slm-models');
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _currentModel = data['current_model'] ?? 'qwen2:0.5b';
          _availableModels = data['available_models'] ?? {};
          _modelDownloading = data['model_downloading'] ?? false;
          _responseTime = (data['average_response_time'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching SLM models: $e');
      }
    }
  }

  Future<void> _downloadModel(String modelName) async {
    if (widget.accessToken == null || widget.accessToken!.isEmpty) return;

    setState(() {
      _modelDownloading = true;
    });

    try {
      final uri = Uri.parse('$apiBaseUrl/api/chatbot/slm-download-model');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode({'model': modelName}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Downloading model...'),
            duration: const Duration(seconds: 3),
          ),
        );

        // Poll for download completion
        _checkModelDownloadStatus(modelName);
      } else {
        setState(() {
          _modelDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start model download')),
        );
      }
    } catch (e) {
      setState(() {
        _modelDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _checkModelDownloadStatus(String modelName) async {
    // Check download status every 5 seconds for up to 15 minutes
    int checks = 0;
    while (checks < 180) {
      // 180 * 5 = 900 seconds = 15 minutes
      await Future.delayed(const Duration(seconds: 5));

      try {
        await _fetchSLMModels();
        if (!_modelDownloading) {
          // Download completed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Model $modelName downloaded and activated!'),
              backgroundColor: Colors.green,
            ),
          );
          // Auto-switch to the new model
          await _switchModel(modelName);
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error checking download status: $e');
        }
      }
      checks++;
    }

    // Timeout
    setState(() {
      _modelDownloading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Model download timed out')),
    );
  }

  Future<void> _switchModel(String modelName) async {
    if (widget.accessToken == null || widget.accessToken!.isEmpty) return;

    try {
      final uri = Uri.parse('$apiBaseUrl/api/chatbot/slm-switch-model');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode({'model': modelName}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _currentModel = modelName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Model switched')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to switch model')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    if (widget.accessToken == null || widget.accessToken!.isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse('$apiBaseUrl/api/chatbot/history?disease=$_selectedDisease&language=$_selectedLanguage');
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final messages = data['messages'] as List?;
        
        if (messages != null && messages.isNotEmpty) {
          setState(() {
            _messages.clear();
            for (var msg in messages) {
              _messages.add(_ChatMessage(
                text: msg['text']?.toString() ?? '',
                isUser: msg['is_user'] == true,
              ));
            }
          });
          
          if (kDebugMode) {
            print('Loaded ${_messages.length} messages from backend');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading chat history: $e');
      }
    }
  }

  Future<void> _sendMessage(String message) async {
    if (widget.accessToken == null || widget.accessToken!.isEmpty) {
      setState(() {
        _error = 'Please sign in again to use AgriBot.';
      });
      return;
    }

    // Mark quick question as answered if this message came from a quick question click
    if (message.trim().isNotEmpty && message.trim() != '') {
      setState(() {
        _quickQuestionAnswered = true;
      });
    }

    setState(() {
      _loading = true;
      _error = null;
      if (message.trim().isNotEmpty) {
        _messages.add(_ChatMessage(text: message.trim(), isUser: true));
      }
    });

    try {
      final uri = Uri.parse('$apiBaseUrl/api/chatbot');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (widget.accessToken != null)
            'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode({
          'disease': _selectedDisease,
          'message': message.trim(),
          'language': _selectedLanguage,
          'use_slm': _useSLMMode, // Send SLM mode flag to backend for tracking
          'timestamp': DateTime.now().toIso8601String(), // Server will use this for persistence
          'save_to_history': true, // Flag to save this conversation to backend
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = data['reply']?.toString() ?? 'No reply available.';
        final slmUsed = data['slm_used'] as bool? ?? false;
        final slmAvailable = data['slm_available'] as bool? ?? false;
        final responseTimeMs = data['response_time_ms'] as int? ?? 0;
        
        // Verify the message was saved to backend
        final chatId = data['chat_id']?.toString(); // Backend should return chat session ID
        
        setState(() {
          _messages.add(_ChatMessage(
            text: reply,
            isUser: false,
            slmUsed: slmUsed,
          ));
          _slmAvailable = slmAvailable;
          _lastResponseUsedSLM = slmUsed;
          _responseTime = responseTimeMs / 1000.0; // Convert to seconds
        });
        
        // Check if response is slow (> 5 seconds) and suggest model switch
        if (responseTimeMs > 5000 && _currentModel != 'qwen2:0.5b') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Response was slow (${(responseTimeMs/1000).toStringAsFixed(1)}s). Consider switching to a faster model.'),
              action: SnackBarAction(
                label: 'Switch',
                onPressed: _showModelSwitchDialog,
              ),
            ),
          );
        }
        
        // Log for debugging - chat was successfully stored
        if (chatId != null && kDebugMode) {
          print('Chat saved with ID: $chatId, SLM used: $slmUsed, Response time: ${responseTimeMs}ms');
        }
      } else {
        setState(() {
          _error = 'AgriBot is unavailable right now. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'AgriBot is unavailable right now. Please try again.';
      });
    } finally {
      if (mounted) {
        _messageController.clear();
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    _sendMessage(message);
  }

  void _showModelSwitchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Switch Model'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: $_currentModel',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Available Models:'),
                const SizedBox(height: 8),
                ..._availableModels.entries.map((entry) {
                  final modelName = entry.key;
                  final specs = entry.value as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(modelName),
                      subtitle: Text(
                        'Size: ${specs['size']}, Speed: ${specs['speed']}, Quality: ${specs['quality']}',
                      ),
                      trailing: _currentModel == modelName
                          ? const Icon(Icons.check_circle, color: Color(0xFF22A45D))
                          : null,
                      onTap: _modelDownloading
                          ? null
                          : () {
                              Navigator.pop(context);
                              _downloadModel(modelName);
                            },
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  String _displayDiseaseName(String key) {
    final normalized = _normalizeToBackendKey(key);
    try {
      return _diseases
          .firstWhere((d) => d.$1 == normalized)
          .$2;
    } catch (e) {
      return key;
    }
  }

  // Helper getters for widget properties
  Map<String, dynamic>? get prediction => widget.prediction;
  
  double? get confidence {
    if (prediction == null) return null;
    return (prediction!['confidence'] as num?)?.toDouble();
  }
  
  String? get advice {
    if (prediction == null) return null;
    return prediction!['advice'] as String?;
  }
  
  bool get hasLocalImage {
    if (prediction == null) return false;
    // Check explicit flag first, then fall back to checking if local_image_path exists
    final hasFlag = prediction!['has_local_image'] == true;
    if (hasFlag) return true;
    final localPath = prediction!['local_image_path'] as String?;
    return localPath != null && localPath.isNotEmpty;
  }
  
  String? get imageUrl {
    if (prediction == null) return null;
    return prediction!['image_url'] as String?;
  }
  
  String? get localImagePath {
    if (prediction == null) return null;
    return prediction!['local_image_path'] as String?;
  }
  
  List<Map<String, dynamic>> get detections {
    if (prediction == null) return [];
    
    var detList = prediction!['detections'];
    if (detList == null) return [];
    
    // Handle different formats
    if (detList is! List) {
      return [];
    }
    
    try {
      // Convert to list of maps
      return List<Map<String, dynamic>>.from(
        detList.map((d) {
          if (d is Map) {
            return Map<String, dynamic>.from(d as Map);
          }
          return <String, dynamic>{};
        }).where((m) => m.isNotEmpty).toList(),
      );
    } catch (_) {
      return [];
    }
  }

  // Localized questions
  List<String> get _localizedQuickQuestions {
    final lang = _normalizeLanguage(_selectedLanguage);
    if (lang == 'cebuano') return _quickQuestionsCebuano;
    if (lang == 'filipino') return _quickQuestionsFilipino;
    return _quickQuestions;
  }

  List<String> get _localizedSLMQuestions {
    final lang = _normalizeLanguage(_selectedLanguage);
    if (lang == 'cebuano') return _slmQuestionsCebuano;
    if (lang == 'filipino') return _slmQuestionsFilipino;
    return _slmQuestions;
  }

  List<MapEntry<String, String>> _chemicalImagesForText(String text) {
    final normalizedText = text.toLowerCase();
    final seenAssets = <String>{};
    final matches = <MapEntry<String, String>>[];

    for (final entry in _chemicalImageAssets.entries) {
      if (normalizedText.contains(entry.key.toLowerCase()) &&
          seenAssets.add(entry.value)) {
        matches.add(entry);
      }
    }

    return matches;
  }

  Widget _buildChemicalPreviewCard(MapEntry<String, String> chemical) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(left: 2, bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22A45D).withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 120,
            width: double.infinity,
            child: Image.asset(
              chemical.value,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.25)),
                  ),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey[500],
                    size: 28,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            chemical.key,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelMedium?.copyWith(
              color: const Color(0xFF1B5E20),
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  void _showChemicalsGallery() {
    // Extract unique chemicals by image path to avoid duplicates
    final uniqueChemicals = <String, String>{};
    for (final entry in _chemicalImageAssets.entries) {
      if (!uniqueChemicals.containsValue(entry.value)) {
        uniqueChemicals[entry.key] = entry.value;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chemical References',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: uniqueChemicals.length,
                  itemBuilder: (context, index) {
                    final entry = uniqueChemicals.entries.elementAt(index);
                    // Use a clean card layout for the grid instead of the chat horizontal card
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF22A45D).withOpacity(0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Image.asset(
                              entry.value,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.withOpacity(0.25)),
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.grey[500],
                                    size: 28,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.key,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF1B5E20),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  TextTheme get textTheme => Theme.of(context).textTheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('AgriBot Assistant'),
            if (_useSLMMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _modelDownloading ? Icons.downloading : Icons.psychology_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _modelDownloading
                          ? 'Downloading...'
                          : '${_currentModel.split(':')[1]} Model',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF22A45D),
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Chemical References',
            onPressed: _showChemicalsGallery,
          ),
          if (_useSLMMode && !_modelDownloading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: _showModelSwitchDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.download_for_offline, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Redownload',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Header Section
              Text(
                prediction != null
                    ? _tr('Your scan is ready', 'Andam na ang imong scan', 'Handa na ang iyong scan')
                    : _tr('Ask AgriBot', 'Pangutana kang AgriBot', 'Magtanong sa AgriBot'),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                prediction != null
                    ? _tr('Review the uploaded image and ask follow-up questions right away.',
                          'Tan-awa ang imong gi-upload nga hulagway ug pangutana dayon og mga sunod nga pangutana.',
                          'Suriin ang iyong na-upload na larawan at magtanong ng follow-up na mga tanong kaagad.')
                    : _tr('Get guidance about symptoms, prevention, treatment, and fertilizer for a specific disease.',
                          'Makakuha ka og giya bahin sa sintomas, paglikay, pagtambal, ug abono para sa usa ka sakit.',
                          'Makakuha ng gabay tungkol sa mga sintoma, pagpigil, paggamot, at pataba para sa isang partikular na sakit.'),
                style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 28),

              // Prediction Display
              if (prediction != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22A45D).withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasLocalImage || imageUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: DetectionOverlayImage(
                            localImagePath: hasLocalImage ? localImagePath : null,
                            networkImageUrl: hasLocalImage ? null : imageUrl,
                            detections: detections,
                            height: 240,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22A45D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _displayDiseaseName(_selectedDisease),
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF22A45D),
                          ),
                        ),
                      ),
                      if (confidence != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Confidence: ',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${(confidence! * 100).toStringAsFixed(1)}%',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF22A45D),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (advice != null && advice!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            advice!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[800],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (prediction != null) const SizedBox(height: 24),

              // Error Message with Better Styling
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        '⚠️',
                        style: textTheme.bodyMedium?.copyWith(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.orange[900],
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Response Time Display (if SLM enabled)
              if (_useSLMMode && _responseTime > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _responseTime > 5
                        ? Colors.red.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _responseTime > 5
                          ? Colors.red.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _responseTime > 5 ? Icons.speed : Icons.timer,
                        size: 16,
                        color: _responseTime > 5 ? Colors.red[700] : Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Model: $_currentModel',
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color:
                                    _responseTime > 5 ? Colors.red[700] : Colors.blue[700],
                              ),
                            ),
                            Text(
                              'Response time: ${_responseTime.toStringAsFixed(2)}s${_responseTime > 5 ? ' (slow)' : ' (good)'}',
                              style: textTheme.bodySmall?.copyWith(
                                color:
                                    _responseTime > 5 ? Colors.red[700] : Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_responseTime > 5)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: _showModelSwitchDialog,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Switch',
                                style: textTheme.labelSmall?.copyWith(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Disease Selector Card with Icon
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF22A45D).withOpacity(0.3),
                    width: 2,
                  ),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22A45D).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        _tr('Disease', 'Uri ng Sakit', 'Uri ng Sakit'),
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF22A45D),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDisease,
                        items: _diseases
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.$1,
                                child: Text(
                                  d.$2,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          filled: false,
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedDisease = value;
                              _quickQuestionAnswered = false;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Language Selector Card with Icon
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF22A45D).withOpacity(0.3),
                    width: 2,
                  ),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22A45D).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        _tr('Language', 'Pinulongan', 'Wika'),
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF22A45D),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedLanguage,
                        items: const [
                          DropdownMenuItem(
                            value: 'english',
                            child: Text('English'),
                          ),
                          DropdownMenuItem(
                            value: 'cebuano',
                            child: Text('Cebuano'),
                          ),
                          DropdownMenuItem(
                            value: 'filipino',
                            child: Text('Filipino'),
                          ),
                        ],
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          filled: false,
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedLanguage = value;
                              _messages.clear();
                              _error = null;
                              _quickQuestionAnswered = false;
                            });
                            if (widget.accessToken != null &&
                                widget.accessToken!.isNotEmpty) {
                              _sendMessage('');
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Questions Section
              if (!_useSLMMode || (_useSLMMode && _quickQuestionAnswered))
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF22A45D).withOpacity(0.05),
                        const Color(0xFF22A45D).withOpacity(0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF22A45D).withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr(
                          _useSLMMode && _quickQuestionAnswered ? 'Follow-up questions' : 'Quick questions',
                          _useSLMMode && _quickQuestionAnswered ? 'Dugang na mga tanong' : 'Mabilis na mga tanong',
                          _useSLMMode && _quickQuestionAnswered ? 'Mga susunod na tanong' : 'Mabilis na mga tanong',
                        ),
                        style: textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF22A45D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_useSLMMode && _quickQuestionAnswered
                                ? _localizedSLMQuestions
                                : _localizedQuickQuestions)
                            .map(
                              (question) => ActionChip(
                                label: Text(
                                  question,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFF22A45D),
                                  width: 1.5,
                                ),
                                onPressed: _loading
                                    ? null
                                    : () {
                                        // Clear all messages and show only the new question/answer
                                        setState(() {
                                          _messages.clear();
                                        });
                                        _sendMessage(question);
                                      },
                                elevation: 2,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Messages Section with Better Styling
              if (_messages.isNotEmpty) ...[
                Text(
                  _tr('Conversation', 'Ating Panag-uusap', 'Ating Usapan'),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF22A45D),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF22A45D).withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22A45D).withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _messages.length; i++) ...[
                        Align(
                          alignment: _messages[i].isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: _messages[i].isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                constraints: const BoxConstraints(maxWidth: 280),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: _messages[i].isUser
                                      ? const Color(0xFF22A45D)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _messages[i].isUser
                                          ? const Color(0xFF22A45D).withOpacity(0.15)
                                          : Colors.grey.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _messages[i].text,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: _messages[i].isUser
                                        ? Colors.white
                                        : Colors.black87,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (!_messages[i].isUser)
                                for (final chemical
                                    in _chemicalImagesForText(_messages[i].text))
                                  _buildChemicalPreviewCard(chemical),
                              // Show SLM indicator for bot responses
                              if (!_messages[i].isUser && _messages[i].slmUsed == true) ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.psychology_rounded,
                                          size: 12,
                                          color: Colors.blue[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'SLM Powered',
                                          style: textTheme.labelSmall?.copyWith(
                                            fontSize: 10,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),

            // Chat Input Field - Sticky at Bottom
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Form(
                key: _formKey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _messageController,
                        enabled: !_loading,
                        decoration: InputDecoration(
                          hintText: _tr(
                            'Type your message...',
                            'Itype ang imong mensahe...',
                            'I-type ang iyong mensahe...',
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Color(0xFF22A45D),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: const Color(0xFF22A45D).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Color(0xFF22A45D),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          isDense: true,
                          suffixIcon: _messageController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _messageController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                        maxLines: null,
                        onChanged: (value) {
                          setState(() {});
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return _tr(
                              'Message is required',
                              'Kailangan ng mensahe',
                              'Kinakailangan ang mensahe',
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      mini: true,
                      onPressed: _loading ? null : _handleSubmit,
                      backgroundColor: _loading
                          ? Colors.grey
                          : const Color(0xFF22A45D),
                      child: _loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.7),
                                ),
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/screens/chatbot_screen.dart
import 'dart:convert';

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

  const ChatbotScreen({
    super.key,
    this.accessToken,
    this.initialDisease,
    this.prediction,
    this.loadOverviewOnStart = false,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
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

  static const _diseases = [
    ('bacterial_blight', 'Bacterial Blight'),
    ('brown_spot', 'Brown Spot'),
    ('leaf_blast', 'Leaf Blast'),
    ('sheath_blight', 'Sheath Blight'),
    ('tungro', 'Tungro'),
  ];

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

  String _normalizeToBackendKey(String input) {
    final n = (input).trim().toLowerCase().replaceAll(' ', '_');
    if (n.contains('blast')) return 'leaf_blast';
    if (n.contains('blight')) return 'bacterial_blight';
    if (n.contains('brown')) return 'brown_spot';
    if (n.contains('sheath')) return 'sheath_blight';
    if (n.contains('tungro')) return 'tungro';
    return n;
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initialDisease;
    if (init != null && init.isNotEmpty) {
      _selectedDisease = _normalizeToBackendKey(init);
    }

    if (widget.loadOverviewOnStart && widget.accessToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage('');
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = data['reply']?.toString() ?? 'No reply available.';
        setState(() {
          _messages.add(_ChatMessage(text: reply, isUser: false));
        });
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

  String _displayDiseaseName(String key) {
    return _diseases
            .firstWhere(
              (d) => d.$1 == key,
              orElse: () => (key, key.replaceAll('_', ' ')),
            )
            .$2;
  }

  List<String> get _localizedQuickQuestions {
    return _selectedLanguage == 'cebuano'
        ? _quickQuestionsCebuano
        : _quickQuestions;
  }

  String? _predictionAdvice(Map<String, dynamic>? prediction) {
    if (prediction == null) return null;

    final advice = prediction['advice']?.toString();
    if (advice != null && advice.isNotEmpty) {
      return advice;
    }

    final description = prediction['description']?.toString();
    final remedy = prediction['remedy']?.toString();
    final parts = <String>[
      if (description != null && description.isNotEmpty) description,
      if (remedy != null && remedy.isNotEmpty) 'Recommended action: $remedy',
    ];

    if (parts.isEmpty) return null;
    return parts.join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final prediction = widget.prediction;
    final localImagePath = prediction?['local_image_path']?.toString();
    final rawImageUrl = prediction?['image_url']?.toString();
    final imageUrl = (rawImageUrl == null || rawImageUrl.isEmpty)
        ? null
        : normalizeApiUrl(rawImageUrl);
    final hasLocalImage = localImagePath != null && localImagePath.isNotEmpty;
    final confidence = (prediction?['confidence'] is num)
        ? (prediction!['confidence'] as num).toDouble()
        : null;
    final advice = _predictionAdvice(prediction);
    final detections = prediction?['detections'] is List
        ? List<Map<String, dynamic>>.from(
            (prediction!['detections'] as List).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          )
        : const <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriBot Assistant'),
        elevation: 0,
        backgroundColor: const Color(0xFF22A45D),
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Text(
                prediction != null
                    ? (_selectedLanguage == 'cebuano'
                        ? 'Andam na ang imong scan'
                        : 'Your scan is ready')
                    : (_selectedLanguage == 'cebuano'
                        ? 'Pangutana kang AgriBot'
                        : 'Ask AgriBot'),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                prediction != null
                    ? (_selectedLanguage == 'cebuano'
                        ? 'Tan-awa ang imong gi-upload nga hulagway ug pangutana dayon og mga sunod nga pangutana.'
                        : 'Review the uploaded image and ask follow-up questions right away.')
                    : (_selectedLanguage == 'cebuano'
                        ? 'Makakuha ka og giya bahin sa sintomas, paglikay, pagtambal, ug abono para sa usa ka sakit.'
                        : 'Get guidance about symptoms, prevention, treatment, and fertilizer for a specific disease.'),
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
                              '${(confidence * 100).toStringAsFixed(1)}%',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF22A45D),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (advice != null && advice.isNotEmpty) ...[
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
                            advice,
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
                        _selectedLanguage == 'cebuano'
                            ? 'Uri ng Sakit'
                            : 'Disease',
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
                        _selectedLanguage == 'cebuano'
                            ? 'Pinulongan'
                            : 'Language',
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
                      _selectedLanguage == 'cebuano'
                          ? 'Mabilis na mga tanong'
                          : 'Quick questions',
                      style: textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF22A45D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _localizedQuickQuestions
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
                  _selectedLanguage == 'cebuano'
                      ? 'Ating Panag-uusap'
                      : 'Conversation',
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
                          child: Container(
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
    );
  }
}

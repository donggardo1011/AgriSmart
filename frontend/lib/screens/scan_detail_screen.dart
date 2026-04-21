import 'package:flutter/material.dart';
import 'chatbot_screen.dart';
import '../core/network.dart';
import '../widgets/detection_overlay.dart';

class ScanDetailScreen extends StatelessWidget {
  final Map<String, dynamic> prediction;
  final String? accessToken;

  const ScanDetailScreen({
    super.key,
    required this.prediction,
    this.accessToken,
  });

  String _displayDiseaseName(String key) {
    switch (key.trim().toLowerCase()) {
      case 'bacterial_blight':
        return 'Bacterial Blight';
      case 'brown_spot':
        return 'Brown Spot';
      case 'leaf_blast':
        return 'Leaf Blast';
      case 'sheath_blight':
      case 'smut':
        return 'Sheath Blight';
      case 'tungro':
        return 'Tungro';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  String _predictionAdvice() {
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

    return parts.join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = prediction['label']?.toString() ?? 'Unknown';
    final confidence = (prediction['confidence'] is num)
        ? (prediction['confidence'] as num).toDouble()
        : null;
    final advice = _predictionAdvice();
    final localImagePath = prediction['local_image_path']?.toString();
    final rawImageUrl = prediction['image_url']?.toString();
    final imageUrl = (rawImageUrl == null || rawImageUrl.isEmpty)
        ? null
        : normalizeApiUrl(rawImageUrl);
    final hasLocalImage = localImagePath != null && localImagePath.isNotEmpty;
    final detections = prediction['detections'] is List
        ? List<Map<String, dynamic>>.from(
            (prediction['detections'] as List).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          )
        : const <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasLocalImage || (imageUrl != null && imageUrl.isNotEmpty))
              DetectionOverlayImage(
                localImagePath: hasLocalImage ? localImagePath : null,
                networkImageUrl: hasLocalImage ? null : imageUrl,
                detections: detections,
                height: 220,
              ),
            const SizedBox(height: 16),
            Text(
              _displayDiseaseName(label),
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (confidence != null) ...[
              const SizedBox(height: 4),
              Text(
                'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                style: textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              ),
            ],
            if (prediction['cached_at'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Available offline on this device',
                style: textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Advice',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              advice,
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey[800]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatbotScreen(
                      accessToken: accessToken,
                      initialDisease: label,
                      prediction: prediction,
                      loadOverviewOnStart: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Ask AgriBot about this disease'),
            ),
          ],
        ),
      ),
    );
  }
}

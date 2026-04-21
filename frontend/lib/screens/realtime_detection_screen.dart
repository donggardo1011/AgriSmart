import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/prediction_service.dart';
import '../services/scan_cache_service.dart';
import '../screens/chatbot_screen.dart';

class RealtimeDetectionScreen extends StatefulWidget {
  final String accessToken;
  final List<CameraDescription> cameras;

  const RealtimeDetectionScreen({
    super.key,
    required this.accessToken,
    required this.cameras,
  });

  @override
  State<RealtimeDetectionScreen> createState() => _RealtimeDetectionScreenState();
}

class _RealtimeDetectionScreenState extends State<RealtimeDetectionScreen> {
  late CameraController _controller;
  late PredictionService _predictionService;
  Timer? _frameTimer;
  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _error;
  Map<String, dynamic>? _latestDetection;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _predictionService = PredictionService(widget.accessToken);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      if (widget.cameras.isEmpty) {
        _setError('No cameras available on this device');
        return;
      }

      // Use back camera by default
      final camera = widget.cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => widget.cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller.initialize();
      if (!mounted) return;

      setState(() => _isInitialized = true);
      _startFrameCapture();
    } catch (e) {
      _setError('Failed to initialize camera: $e');
    }
  }

  void _startFrameCapture() {
    // Capture frame every 500ms (2 FPS) to avoid overwhelming the API
    _frameTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_isProcessing && _isInitialized) {
        _captureAndAnalyzeFrame();
      }
    });
  }

  Future<void> _captureAndAnalyzeFrame() async {
    if (_isProcessing || !_isInitialized) return;

    try {
      setState(() => _isProcessing = true);

      // Capture image from camera
      final imageFile = await _controller.takePicture();
      _frameCount++;

      // Send to server for real-time inference (skipCache=true to prevent auto-save)
      try {
        final prediction = await _predictionService.analyzeLeafImageOnline(
          imageFile.path,
          'frame_$_frameCount.jpg',
          skipCache: true,
        );

        // Only update if detection has confidence > 0 (disease detected)
        if (mounted) {
          final confidence = (prediction['confidence'] as num?)?.toDouble() ?? 0.0;
          if (confidence > 0) {
            setState(() {
              _latestDetection = prediction;
              _error = null;
            });
          }
        }

        // Delete temp file to save space
        final tempFile = File(imageFile.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Inference error: $e';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to capture frame: $e';
          _isProcessing = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() => _error = message);
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Real-Time Detection')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Real-Time Detection')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing camera...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Detection'),
        actions: [
          if (_isProcessing)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          CameraPreview(_controller),

          // Detection overlay with boxes on each disease
          if (_latestDetection != null)
            Positioned.fill(
              child: _buildDetectionOverlay(),
            ),

          // Bottom info panel (minimal)
          if (_latestDetection != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildInfoPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildDetectionOverlay() {
    final detections = (_latestDetection?['detections'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    if (detections.isEmpty) {
      return const SizedBox.expand();
    }

    return CustomPaint(
      painter: _LiveDetectionPainter(detections, _latestDetection ?? {}),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildInfoPanel() {
    final detectionCount = (_latestDetection?['detections'] as List?)?.length ?? 0;

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Detections: $detectionCount disease(s) found',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Discard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _latestDetection != null
                      ? () async => await _savePredictionAndGoToChatbot()
                      : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Save & Ask'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _savePredictionAndGoToChatbot() async {
    if (_latestDetection == null) return;

    try {
      // Explicitly cache the prediction when user clicks Save & Ask
      final prediction = _latestDetection!;
      await ScanCacheService.cachePrediction(prediction);
      
      // Navigate to chatbot with the prediction
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatbotScreen(
              accessToken: widget.accessToken,
              initialDisease: prediction['label']?.toString(),
              prediction: prediction,
              loadOverviewOnStart: true,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

// CustomPainter for drawing detection boxes on live camera feed
class _LiveDetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Map<String, dynamic> predictionData;

  _LiveDetectionPainter(this.detections, this.predictionData);

  Color _getSeverityColor(String label) {
    const severityMap = {
      'bacterial_blight': Colors.red,
      'leaf_blast': Colors.red,
      'smut': Colors.red,
      'brown_spot': Colors.orange,
      'tungro': Colors.orange,
    };
    return severityMap[label] ?? Colors.yellow;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final labelRects = <Rect>[];

    for (final detection in detections) {
      var left = (detection['left'] as double?) ?? 0;
      var top = (detection['top'] as double?) ?? 0;
      var right = (detection['right'] as double?) ?? 0;
      var bottom = (detection['bottom'] as double?) ?? 0;
      final label = (detection['label'] as String?) ?? 'Unknown';
      final confidence = (detection['confidence'] as double?) ?? 0.0;

      final normalized = left <= 1.0 && top <= 1.0 && right <= 1.0 && bottom <= 1.0;
      if (normalized) {
        left *= size.width;
        top *= size.height;
        right *= size.width;
        bottom *= size.height;
      } else {
        const modelWidth = 640.0;
        const modelHeight = 640.0;
        left *= size.width / modelWidth;
        top *= size.height / modelHeight;
        right *= size.width / modelWidth;
        bottom *= size.height / modelHeight;
      }

      final rect = Rect.fromLTRB(left, top, right, bottom).intersect(Rect.fromLTWH(0, 0, size.width, size.height));

      if (rect.width <= 0 || rect.height <= 0) {
        continue;
      }

      final boxColor = _getSeverityColor(label);

      // Draw translucent fill inside the box to highlight the region
      final fillPaint = Paint()
        ..color = boxColor.withAlpha((0.14 * 255).round())
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        fillPaint,
      );

      // Draw bounding box with rounded corners
      final boxPaint = Paint()
        ..color = boxColor
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        boxPaint,
      );

      final labelText = '${label.replaceAll('_', ' ')} ${(confidence * 100).toStringAsFixed(0)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: size.width * 0.7);

      final labelBoxWidth = textPainter.width + 12;
      final labelBoxHeight = textPainter.height + 8;
      double labelLeft = rect.left.clamp(8.0, size.width - labelBoxWidth - 8.0);
      double labelTop = rect.top - labelBoxHeight - 6;
      if (labelTop < 8) {
        labelTop = rect.bottom + 6;
      }

      var labelRect = Rect.fromLTWH(labelLeft, labelTop, labelBoxWidth, labelBoxHeight);

      // Avoid label collisions by nudging if overlapping previous labels
      for (final occupied in labelRects) {
        if (labelRect.overlaps(occupied)) {
          labelRect = labelRect.translate(0, occupied.bottom - labelRect.top + 4);
        }
      }

      if (labelRect.bottom > size.height - 8) {
        labelRect = labelRect.shift(Offset(0, -(labelRect.bottom - size.height + 8)));
      }
      if (labelRect.top < 8) {
        labelRect = labelRect.shift(Offset(0, 8 - labelRect.top));
      }

      labelRects.add(labelRect);

      final labelBoxPaint = Paint()
        ..color = boxColor.withAlpha((0.9 * 255).round())
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(8)),
        labelBoxPaint,
      );

      if (labelRect.top <= rect.top - 6) {
        final linePaint = Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.2;
        canvas.drawLine(
          Offset(labelRect.left + 6, labelRect.bottom),
          Offset(labelRect.left + 6, rect.top - 4),
          linePaint,
        );
      }

      final textOffset = Offset(labelRect.left + 6, labelRect.top + 4);
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(_LiveDetectionPainter oldDelegate) {
    return detections != oldDelegate.detections;
  }
}

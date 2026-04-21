import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class OfflineDiagnosisUnavailable implements Exception {
  final String message;

  const OfflineDiagnosisUnavailable(this.message);

  @override
  String toString() => message;
}

class OfflineLeafDiagnosisService {
  static const String modelAssetPath = 'assets/models/best.tflite';
  static const List<String> alternativeModelAssetPaths = [
    'assets/models/best.tflite',
    'assets/best.tflite',
  ];
  static const List<String> diseaseClasses = [
    'bacterial_blight',
    'brown_spot',
    'leaf_blast',
    'smut',
    'tungro',
  ];
  static const int inputSize = 640;
  // STRICT: Only high-confidence detections to avoid false positives on non-rice images
  static const double confidenceThreshold = 0.72; // Minimum for detection (72%)
  static const double nmsThreshold = 0.5;

  static String? _cachedModelPath;

  static Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    try {
      final modelPath = await _ensureLocalModelFile();
      final result = await compute<Map<String, dynamic>, Map<String, dynamic>>(
        _runOfflineDetection,
        {
          'imagePath': imagePath,
          'modelPath': modelPath,
          'labels': diseaseClasses,
          'inputSize': inputSize,
          'confidenceThreshold': confidenceThreshold,
          'nmsThreshold': nmsThreshold,
        },
      );

      return {
        ...result,
        'image_url': 'local_image',
        'local_image_path': imagePath,
        'created_at': DateTime.now().toIso8601String(),
        'analysis_type': 'offline',
        'source': 'offline_model',
      };
    } catch (e) {
      throw OfflineDiagnosisUnavailable(
        'Offline detection failed: $e. Ensure best.tflite is bundled at '
        '$modelAssetPath.',
      );
    }
  }

  static Future<bool> isOfflineModelAvailable() async {
    try {
      await _ensureLocalModelFile();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> dispose() async {}

  static Future<String> _ensureLocalModelFile() async {
    if (_cachedModelPath != null && await File(_cachedModelPath!).exists()) {
      return _cachedModelPath!;
    }

    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(tempDir.path, 'best.tflite');
    final targetFile = File(targetPath);

    for (final assetPath in alternativeModelAssetPaths) {
      try {
        final byteData = await rootBundle.load(assetPath);
        await targetFile.writeAsBytes(
          byteData.buffer.asUint8List(),
          flush: true,
        );
        _cachedModelPath = targetFile.path;
        return _cachedModelPath!;
      } catch (_) {
        continue;
      }
    }

    throw Exception('Could not locate the offline model in assets. Expected one of: ${alternativeModelAssetPaths.join(', ')}');
  }
}

Future<Map<String, dynamic>> _runOfflineDetection(
  Map<String, dynamic> args,
) async {
  final imagePath = args['imagePath'] as String;
  final modelPath = args['modelPath'] as String;
  final labels = List<String>.from(args['labels'] as List);
  final inputSize = args['inputSize'] as int;
  final confidenceThreshold = (args['confidenceThreshold'] as num).toDouble();
  final nmsThreshold = (args['nmsThreshold'] as num).toDouble();

  final imageBytes = await File(imagePath).readAsBytes();
  final decodedImage = img.decodeImage(imageBytes);
  if (decodedImage == null) {
    throw Exception('Failed to decode image.');
  }

  final resized = img.copyResize(
    decodedImage,
    width: inputSize,
    height: inputSize,
    interpolation: img.Interpolation.linear,
  );

  final input = List.generate(
    1,
    (_) => List.generate(
      inputSize,
      (y) => List.generate(
        inputSize,
        (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r.toDouble() / 255.0,
            pixel.g.toDouble() / 255.0,
            pixel.b.toDouble() / 255.0,
          ];
        },
      ),
    ),
  );

  final output = List.generate(
    1,
    (_) => List.generate(
      84,
      (_) => List<double>.filled(8400, 0),
    ),
  );

  final interpreter = Interpreter.fromFile(File(modelPath));
  try {
    interpreter.run(input, output);
  } finally {
    interpreter.close();
  }

  final detections = _parseYoloV8Output(
    output: output,
    labels: labels,
    confidenceThreshold: confidenceThreshold,
    nmsThreshold: nmsThreshold,
    inputSize: inputSize,
  );

  // Confidence thresholds for rice leaf detection validation (STRICT)
  const double minConfidenceThreshold = 0.72;  // Must be >= 72%
  const double stricterConfidenceThreshold = 0.80;  // Must be >= 80% for diagnosis

  if (detections.isEmpty) {
    // No detections at all = no rice leaf
    return {
      'label': 'invalid_image',
      'confidence': 0.0,
      'disease_name': 'Invalid Image',
      'description': 'No rice leaf detected in image.',
      'remedy': 'Please ensure the image contains rice leaves.',
      'advice': 'No rice leaf detected in image. Please ensure:\n'
          '• The image shows ONLY rice leaves\n'
          '• The image is clear and well-lit\n'
          '• People or other objects are NOT in the frame\n\n'
          'This app specifically analyzes individual rice leaf diseases. '
          'Please upload a clean photo with only rice leaves.',
      'severity': 'none',
      'detections': <Map<String, dynamic>>[],
      'input_image_size': {
        'width': decodedImage.width,
        'height': decodedImage.height,
      },
      'model_input_size': {
        'width': inputSize,
        'height': inputSize,
      },
    };
  }

  final topDetection = detections.first;
  final topLabel = topDetection['label'] as String;
  final topConfidence = (topDetection['confidence'] as num).toDouble();

  // Validate rice leaf presence based on confidence
  if (topConfidence < minConfidenceThreshold) {
    return {
      'label': 'invalid_image',
      'confidence': 0.0,
      'disease_name': 'Invalid Image',
      'description': 'Image not clear enough.',
      'remedy': 'Please upload a clearer image.',
      'advice': 'Image contains people, objects, or unclear rice detection (${(topConfidence * 100).toStringAsFixed(1)}% confidence).\n\n'
          'Please try:\n'
          '• Remove people from the photo\n'
          '• Focus ONLY on rice leaves\n'
          '• Take a clearer, well-lit photo\n'
          '• Get closer to the leaf\n',
      'severity': 'none',
      'detections': <Map<String, dynamic>>[],
      'input_image_size': {
        'width': decodedImage.width,
        'height': decodedImage.height,
      },
      'model_input_size': {
        'width': inputSize,
        'height': inputSize,
      },
    };
  }

  if (topConfidence < stricterConfidenceThreshold) {
    return {
      'label': 'invalid_image',
      'confidence': 0.0,
      'disease_name': 'Uncertain Detection',
      'description': 'Confidence too low.',
      'remedy': 'Please upload a clearer image.',
      'advice': 'Detection confidence is too low (${(topConfidence * 100).toStringAsFixed(1)}%).\n\n'
          'Please try:\n'
          '• Take a clearer, well-lit photo\n'
          '• Get closer to the rice leaf with visible symptoms\n'
          '• Ensure good lighting\n'
          '• Remove any people or objects from the frame\n',
      'severity': 'none',
      'detections': <Map<String, dynamic>>[],
      'input_image_size': {
        'width': decodedImage.width,
        'height': decodedImage.height,
      },
      'model_input_size': {
        'width': inputSize,
        'height': inputSize,
      },
    };
  }

  return {
    'label': topLabel,
    'confidence': topConfidence,
    'disease_name': _formatDiseaseName(topLabel),
    'description': _getDiseaseDescription(topLabel),
    'remedy': _getRemedy(topLabel),
    'advice':
        '${_getDiseaseDescription(topLabel)}\n\nRecommended action: ${_getRemedy(topLabel)}',
    'severity': _getSeverity(topLabel),
    'detections': detections,
    'input_image_size': {
      'width': decodedImage.width,
      'height': decodedImage.height,
    },
    'model_input_size': {
      'width': inputSize,
      'height': inputSize,
    },
  };
}

List<Map<String, dynamic>> _parseYoloV8Output({
  required List<List<List<double>>> output,
  required List<String> labels,
  required double confidenceThreshold,
  required double nmsThreshold,
  required int inputSize,
}) {
  final tensor = output.first;
  final classCount = math.min(labels.length, tensor.length - 4);
  final proposals = <Map<String, dynamic>>[];

  for (int anchorIndex = 0; anchorIndex < 8400; anchorIndex++) {
    double bestScore = 0;
    int bestClassIndex = -1;

    for (int classIndex = 0; classIndex < classCount; classIndex++) {
      final score = tensor[classIndex + 4][anchorIndex];
      if (score > bestScore) {
        bestScore = score;
        bestClassIndex = classIndex;
      }
    }

    if (bestClassIndex < 0 || bestScore < confidenceThreshold) {
      continue;
    }

    final cx = tensor[0][anchorIndex];
    final cy = tensor[1][anchorIndex];
    final width = tensor[2][anchorIndex];
    final height = tensor[3][anchorIndex];

    final left = (cx - (width / 2)).clamp(0, inputSize.toDouble());
    final top = (cy - (height / 2)).clamp(0, inputSize.toDouble());
    final right = (cx + (width / 2)).clamp(0, inputSize.toDouble());
    final bottom = (cy + (height / 2)).clamp(0, inputSize.toDouble());

    if (right <= left || bottom <= top) {
      continue;
    }

    proposals.add({
      'classIndex': bestClassIndex,
      'label': labels[bestClassIndex],
      'confidence': bestScore,
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
      'width': right - left,
      'height': bottom - top,
    });
  }

  proposals.sort(
    (a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double),
  );

  final selected = <Map<String, dynamic>>[];
  final suppressed = List<bool>.filled(proposals.length, false);

  for (int i = 0; i < proposals.length; i++) {
    if (suppressed[i]) continue;
    final candidate = proposals[i];
    selected.add(candidate);

    for (int j = i + 1; j < proposals.length; j++) {
      if (suppressed[j]) continue;
      final other = proposals[j];
      if (candidate['classIndex'] != other['classIndex']) {
        continue;
      }
      if (_iou(candidate, other) >= nmsThreshold) {
        suppressed[j] = true;
      }
    }
  }

  return selected;
}

double _iou(Map<String, dynamic> a, Map<String, dynamic> b) {
  final left = math.max(a['left'] as double, b['left'] as double);
  final top = math.max(a['top'] as double, b['top'] as double);
  final right = math.min(a['right'] as double, b['right'] as double);
  final bottom = math.min(a['bottom'] as double, b['bottom'] as double);

  final intersectionWidth = math.max(0, right - left);
  final intersectionHeight = math.max(0, bottom - top);
  final intersection = intersectionWidth * intersectionHeight;

  final areaA = (a['width'] as double) * (a['height'] as double);
  final areaB = (b['width'] as double) * (b['height'] as double);
  final union = areaA + areaB - intersection;

  if (union <= 0) {
    return 0;
  }

  return intersection / union;
}

String _formatDiseaseName(String label) {
  return label
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String _getDiseaseDescription(String label) {
  const descriptions = {
    'bacterial_blight': 'Bacterial blight causes water-soaked lesions on leaves.',
    'brown_spot': 'Brown spot disease creates circular brown lesions on leaves.',
    'leaf_blast': 'Leaf blast appears as diamond-shaped lesions with gray centers.',
    'smut': 'Smut produces black, sooty masses on rice grains.',
    'tungro': 'Tungro virus causes yellowing and stunting of plants.',
    'healthy': 'The leaf appears healthy with no visible disease.',
  };
  return descriptions[label] ?? 'Disease detected on rice leaf.';
}

String _getRemedy(String label) {
  const remedies = {
    'bacterial_blight': 'Use disease-resistant varieties. Apply copper fungicides. Improve drainage and avoid overhead irrigation.',
    'brown_spot': 'Apply appropriate fungicides. Remove infected plant debris. Improve field sanitation.',
    'leaf_blast': 'Use resistant varieties. Apply fungicides at heading stage. Maintain proper fertilizer balance.',
    'smut': 'Use clean seeds. Apply fungicide seed treatments. Avoid high nitrogen fertilization.',
    'tungro': 'Use resistant varieties. Control vector insects (leafhoppers). Remove infected plants.',
    'healthy': 'Continue with regular monitoring and maintenance.',
  };
  return remedies[label] ?? 'Consult with a rice specialist.';
}

String _getSeverity(String label) {
  const severities = {
    'bacterial_blight': 'high',
    'brown_spot': 'medium',
    'leaf_blast': 'high',
    'smut': 'high',
    'tungro': 'medium',
    'healthy': 'none',
  };
  return severities[label] ?? 'unknown';
}

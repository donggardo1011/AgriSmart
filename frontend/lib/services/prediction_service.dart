import 'dart:convert';

import '../core/constants.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';
import 'package:http/http.dart' as http;
import 'offline_leaf_diagnosis_service.dart';
import 'scan_cache_service.dart';

class PredictionService {
  final String token;

  PredictionService(this.token);

  ApiClient get _client =>
      ApiClient(baseUrl: AppConstants.apiBaseUrl, token: token);

  Future<List<Map<String, dynamic>>> fetchPredictions() async {
    try {
      final res = await _client.get('/api/predictions');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        final remote = data.cast<Map<String, dynamic>>();
        return ScanCacheService.mergeWithRemote(remote);
      }

      throw Exception(
        'Failed to load predictions (${res.statusCode}): ${res.body}',
      );
    } catch (_) {
      return ScanCacheService.loadPredictions();
    }
  }

  Future<Map<String, dynamic>> analyzeLeafImage(
    String filePath,
    String filename, {
    bool forceOffline = false,
    bool allowOfflineFallback = true,
    double? confidenceThreshold,
  }) async {
    // Check connectivity
    final isOnline = await ConnectivityService().checkNow();

    // Force offline mode if requested
    if (forceOffline) {
      try {
        final offlinePrediction = await OfflineLeafDiagnosisService.analyzeImage(
          filePath,
        );
        final cached = await ScanCacheService.cachePrediction(
          offlinePrediction,
          sourceImagePath: filePath,
        );

        // Queue for later upload if offline
        if (!isOnline) {
          await OfflineQueueService.queueOfflineDetection(
            prediction: cached,
            imagePath: filePath,
            imageFileName: filename,
          );
        }

        return cached;
      } on OfflineDiagnosisUnavailable catch (e) {
        throw Exception('offline_detection_unavailable: ${e.message}');
      }
    }

    // Try online mode first, optionally fallback to offline
    if (isOnline) {
      try {
        final fields = <String, String>{};
        if (confidenceThreshold != null) {
          fields['confidence_threshold'] = confidenceThreshold.toString();
        }

        final streamed = await _client.multipartPost(
          '/api/predictions',
          fileField: 'image',
          filePath: filePath,
          filename: filename,
          fields: fields.isNotEmpty ? fields : null,
        ).timeout(Duration(seconds: 30));

        final res = await http.Response.fromStream(streamed);

        if (res.statusCode == 200) {
          final prediction = _normalizePrediction(
            jsonDecode(res.body) as Map<String, dynamic>,
          );
          return ScanCacheService.cachePrediction(
            prediction,
            sourceImagePath: filePath,
          );
        }

        throw Exception('Upload failed (${res.statusCode}): ${res.body}');
      } catch (onlineError) {
        if (!allowOfflineFallback) {
          rethrow;
        }

        // Fallback to offline for network errors
        try {
          final offlinePrediction = await OfflineLeafDiagnosisService.analyzeImage(
            filePath,
          );
          final cached = await ScanCacheService.cachePrediction(
            offlinePrediction,
            sourceImagePath: filePath,
          );

          // Queue for later upload
          await OfflineQueueService.queueOfflineDetection(
            prediction: cached,
            imagePath: filePath,
            imageFileName: filename,
          );

          return cached;
        } on OfflineDiagnosisUnavailable catch (offlineError) {
          throw Exception('offline_detection_unavailable: ${offlineError.message}');
        }
      }
    } else {
      // Offline mode (no internet)
      if (!allowOfflineFallback) {
        throw Exception('No internet connection available');
      }

      try {
        final offlinePrediction = await OfflineLeafDiagnosisService.analyzeImage(
          filePath,
        );
        final cached = await ScanCacheService.cachePrediction(
          offlinePrediction,
          sourceImagePath: filePath,
        );

        // Queue for later upload
        await OfflineQueueService.queueOfflineDetection(
          prediction: cached,
          imagePath: filePath,
          imageFileName: filename,
        );

        return cached;
      } on OfflineDiagnosisUnavailable catch (offlineError) {
        throw Exception('offline_detection_unavailable: ${offlineError.message}');
      }
    }
  }

  Future<Map<String, dynamic>> analyzeLeafImageOnline(
    String filePath,
    String filename, {
    bool skipCache = false,
  }) async {
    final streamed = await _client.multipartPost(
      '/api/predictions',
      fileField: 'image',
      filePath: filePath,
      filename: filename,
    );

    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200) {
      final prediction = _normalizePrediction(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      
      // Only cache if:
      // 1. skipCache is false (not skipping)
      // 2. confidence > 0.0 (valid detection)
      // 3. label is not "invalid_image"
      final confidence = (prediction['confidence'] as num?)?.toDouble() ?? 0.0;
      final label = prediction['label']?.toString() ?? '';
      
      if (!skipCache && confidence > 0.0 && label != 'invalid_image') {
        return ScanCacheService.cachePrediction(
          prediction,
          sourceImagePath: filePath,
        );
      }
      
      return prediction;
    }

    throw Exception('Upload failed (${res.statusCode}): ${res.body}');
  }

  Map<String, dynamic> _normalizePrediction(Map<String, dynamic> prediction) {
    final description = prediction['description']?.toString();
    final remedy = prediction['remedy']?.toString();
    final advice = prediction['advice']?.toString();

    return {
      ...prediction,
      'advice': (advice != null && advice.isNotEmpty)
          ? advice
          : [
              if (description != null && description.isNotEmpty) description,
              if (remedy != null && remedy.isNotEmpty)
                'Recommended action: $remedy',
            ].join('\n\n'),
    };
  }

  /// Delete a prediction by ID (handles both online and local cache)
  Future<void> deletePrediction(dynamic predictionId) async {
    try {
      // Try to delete from backend
      final res = await _client.delete('/api/predictions/$predictionId');

      if (res.statusCode != 200 && res.statusCode != 204) {
        // If backend deletion fails, still delete from local cache
        await ScanCacheService.deletePrediction(predictionId);
        throw Exception('Delete failed (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      // Even if backend fails, delete from local cache
      await ScanCacheService.deletePrediction(predictionId);
      
      // Only throw if it wasn't a 404 (prediction already gone)
      if (!e.toString().contains('404')) {
        throw Exception('Failed to delete prediction: $e');
      }
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

class ScanCacheService {
  const ScanCacheService._();

  static Future<String?> cacheCapturedImage(String sourceImagePath) async {
    return _ensureLocalImage(sourceImagePath);
  }

  static Future<List<Map<String, dynamic>>> loadPredictions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.cachedPredictionsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  static Future<void> savePredictions(List<Map<String, dynamic>> predictions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.cachedPredictionsKey,
      jsonEncode(predictions),
    );
  }

  static Future<Map<String, dynamic>> cachePrediction(
    Map<String, dynamic> prediction, {
    String? sourceImagePath,
  }) async {
    final cached = List<Map<String, dynamic>>.from(await loadPredictions());
    final localImagePath = await _ensureLocalImage(
      sourceImagePath,
      fallbackPath: prediction['local_image_path']?.toString(),
    );

    final normalized = <String, dynamic>{
      ...prediction,
      'local_image_path': localImagePath,
      'created_at': prediction['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'cached_at': DateTime.now().toIso8601String(),
    };

    final stableId = normalized['id']?.toString();
    final index = stableId == null
        ? -1
        : cached.indexWhere((item) => item['id']?.toString() == stableId);

    if (index >= 0) {
      cached[index] = {...cached[index], ...normalized};
    } else {
      cached.insert(0, normalized);
    }

    cached.sort((a, b) {
      final ad = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    await savePredictions(cached.take(100).toList());
    return normalized;
  }

  static Future<List<Map<String, dynamic>>> mergeWithRemote(
    List<Map<String, dynamic>> remotePredictions,
  ) async {
    final cached = await loadPredictions();
    final byId = <String, Map<String, dynamic>>{};

    for (final item in cached) {
      final id = item['id']?.toString();
      if (id != null && id.isNotEmpty) {
        byId[id] = item;
      }
    }

    final merged = <Map<String, dynamic>>[];
    for (final remote in remotePredictions) {
      final id = remote['id']?.toString();
      final cachedVersion = id == null ? null : byId[id];
      merged.add({
        ...remote,
        if (cachedVersion != null) ...cachedVersion,
        ...remote,
        'local_image_path': cachedVersion?['local_image_path'],
      });
    }

    await savePredictions(merged);
    return merged;
  }

  static Future<String?> _ensureLocalImage(
    String? sourceImagePath, {
    String? fallbackPath,
  }) async {
    final candidate = sourceImagePath ?? fallbackPath;
    if (candidate == null || candidate.isEmpty) {
      return fallbackPath;
    }

    final source = File(candidate);
    if (!await source.exists()) {
      return fallbackPath;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(appDir.path, 'cached_scans'));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final extension = p.extension(source.path);
    final targetPath = p.join(
      targetDir.path,
      'scan_${DateTime.now().millisecondsSinceEpoch}${extension.isEmpty ? '.jpg' : extension}',
    );

    final copied = await source.copy(targetPath);
    return copied.path;
  }

  /// Delete a prediction from local cache
  static Future<void> deletePrediction(dynamic predictionId) async {
    final cached = List<Map<String, dynamic>>.from(await loadPredictions());
    final idStr = predictionId?.toString();
    
    if (idStr != null && idStr.isNotEmpty) {
      cached.removeWhere((item) => item['id']?.toString() == idStr);
    }
    
    await savePredictions(cached);
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineQueueService {
  static const String _queueKey = 'offline_upload_queue';
  static const String _uploadDirName = 'offline_uploads';

  const OfflineQueueService._();

  /// Get the offline uploads directory
  static Future<Directory> _getUploadDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _uploadDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Add a detection to the offline queue
  static Future<void> queueOfflineDetection({
    required Map<String, dynamic> prediction,
    required String imagePath,
    String? imageFileName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _loadQueue();

    // Copy image to offline storage
    final uploadDir = await _getUploadDir();
    final fileName = imageFileName ?? DateTime.now().millisecondsSinceEpoch.toString();
    final storedImagePath = p.join(uploadDir.path, fileName);

    try {
      final sourceFile = File(imagePath);
      await sourceFile.copy(storedImagePath);
    } catch (e) {
      // Image may already be in storage
    }

    // Add entry to queue
    final queueEntry = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'timestamp': DateTime.now().toIso8601String(),
      'prediction': prediction,
      'image_path': storedImagePath,
      'image_file_name': fileName,
      'synced': false,
      'sync_attempts': 0,
      'last_sync_error': null,
    };

    queue.insert(0, queueEntry);
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  /// Load the offline queue
  static Future<List<Map<String, dynamic>>> loadQueue() async {
    return _loadQueue();
  }

  static Future<List<Map<String, dynamic>>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry('$key', value)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Mark a queue item as synced
  static Future<void> markAsSynced(int queueId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _loadQueue();

    final index = queue.indexWhere((item) => item['id'] == queueId);
    if (index >= 0) {
      queue[index]['synced'] = true;
      await prefs.setString(_queueKey, jsonEncode(queue));
    }
  }

  /// Update sync error for a queue item
  static Future<void> updateSyncError(int queueId, String? error) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _loadQueue();

    final index = queue.indexWhere((item) => item['id'] == queueId);
    if (index >= 0) {
      queue[index]['sync_attempts'] = ((queue[index]['sync_attempts'] ?? 0) as int) + 1;
      queue[index]['last_sync_error'] = error;
      await prefs.setString(_queueKey, jsonEncode(queue));
    }
  }

  /// Remove a synced item from queue
  static Future<void> removeSyncedItem(int queueId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _loadQueue();

    queue.removeWhere((item) => item['id'] == queueId);
    await prefs.setString(_queueKey, jsonEncode(queue));

    // Clean up image files
    try {
      final uploadDir = await _getUploadDir();
      final files = uploadDir.listSync();
      final queueFileNames = queue.map((item) => item['image_file_name']).toSet();
      
      for (final file in files) {
        if (file is File) {
          final fileName = p.basename(file.path);
          if (!queueFileNames.contains(fileName)) {
            await file.delete();
          }
        }
      }
    } catch (_) {
      // Silently fail cleanup
    }
  }

  /// Get pending items to sync
  static Future<List<Map<String, dynamic>>> getPendingItems() async {
    final queue = await _loadQueue();
    return queue.where((item) => !(item['synced'] == true)).toList();
  }

  /// Clear entire queue (use with caution)
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode([]));

    // Clean up files
    try {
      final uploadDir = await _getUploadDir();
      if (await uploadDir.exists()) {
        await uploadDir.delete(recursive: true);
      }
    } catch (_) {
      // Silently fail
    }
  }

  /// Get queue stats
  static Future<Map<String, dynamic>> getQueueStats() async {
    final queue = await _loadQueue();
    final pending = queue.where((item) => !(item['synced'] == true)).toList();
    final synced = queue.where((item) => item['synced'] == true).toList();

    return {
      'total': queue.length,
      'pending': pending.length,
      'synced': synced.length,
      'pending_items': pending,
    };
  }
}

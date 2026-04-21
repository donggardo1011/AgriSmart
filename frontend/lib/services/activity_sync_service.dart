import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../core/constants.dart';
import 'offline_activity_service.dart';

class ActivitySyncService {
  static final ActivitySyncService _instance = ActivitySyncService._();

  factory ActivitySyncService() {
    return _instance;
  }

  ActivitySyncService._();

  Timer? _syncTimer;
  bool _isSyncing = false;

  /// Initialize the sync service
  Future<void> initialize(String token) async {
    // Sync pending activities every 60 seconds when online
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      syncPendingActivities(token);
    });
  }

  /// Sync all pending offline activities to backend
  Future<void> syncPendingActivities(String token) async {
    if (_isSyncing) return;

    _isSyncing = true;
    try {
      final pending =
          await OfflineActivityService.getPendingActivities();

      if (pending.isEmpty) {
        _isSyncing = false;
        return;
      }

      for (final activity in pending) {
        try {
          await _syncActivityToBackend(activity, token);
          // Mark as synced after successful sync
          await OfflineActivityService.markActivityAsSynced(
            activity['id'] as int,
          );
          // Remove from local queue
          await OfflineActivityService.removeSyncedActivity(
            activity['id'] as int,
          );
        } catch (e) {
          // Update error but continue with next activities
          await OfflineActivityService.updateSyncError(
            activity['id'] as int,
            e.toString(),
          );
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single activity to backend
  Future<void> _syncActivityToBackend(
    Map<String, dynamic> activity,
    String token,
  ) async {
    final uri =
        Uri.parse('${AppConstants.apiBaseUrl}/activities/');

    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'action': activity['action'],
            'description': activity['description'],
            'timestamp': activity['timestamp'],
            'details': activity['details'],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        'Failed to sync activity (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Manually trigger sync
  Future<void> manualSync(String token) async {
    await syncPendingActivities(token);
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
  }
}

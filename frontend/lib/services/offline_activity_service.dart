import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineActivityService {
  static const String _activitiesKey = 'offline_activities';
  static const String _guestModeKey = 'offline_guest_mode';
  static const String _syncedActivitiesKey = 'synced_activities';

  const OfflineActivityService._();

  /// Save an activity locally when offline or in guest mode
  static Future<void> logActivity({
    required String action,
    required String description,
    Map<String, dynamic>? details,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final activities = _loadActivities(prefs);

    final activity = {
      'id': DateTime.now().millisecondsSinceEpoch, // Unique ID
      'action': action,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
      'details': details,
      'user_id': userId,
      'synced': false,
      'sync_attempts': 0,
      'last_sync_error': null,
    };

    activities.add(activity);
    await prefs.setString(_activitiesKey, jsonEncode(activities));
  }

  /// Load all pending activities
  static Future<List<Map<String, dynamic>>> getPendingActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final activities = _loadActivities(prefs);
    return activities.where((a) => !(a['synced'] == true)).toList();
  }

  /// Load all activities
  static Future<List<Map<String, dynamic>>> getAllActivities() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadActivities(prefs);
  }

  /// Mark activity as synced
  static Future<void> markActivityAsSynced(int activityId) async {
    final prefs = await SharedPreferences.getInstance();
    final activities = _loadActivities(prefs);

    final index =
        activities.indexWhere((a) => a['id'] == activityId);
    if (index >= 0) {
      activities[index]['synced'] = true;
      await prefs.setString(_activitiesKey, jsonEncode(activities));
    }
  }

  /// Update sync error for an activity
  static Future<void> updateSyncError(int activityId, String? error) async {
    final prefs = await SharedPreferences.getInstance();
    final activities = _loadActivities(prefs);

    final index =
        activities.indexWhere((a) => a['id'] == activityId);
    if (index >= 0) {
      activities[index]['sync_attempts'] =
          ((activities[index]['sync_attempts'] ?? 0) as int) + 1;
      activities[index]['last_sync_error'] = error;
      await prefs.setString(_activitiesKey, jsonEncode(activities));
    }
  }

  /// Remove activity after successful sync
  static Future<void> removeSyncedActivity(int activityId) async {
    final prefs = await SharedPreferences.getInstance();
    final activities = _loadActivities(prefs);
    activities.removeWhere((a) => a['id'] == activityId);
    await prefs.setString(_activitiesKey, jsonEncode(activities));
  }

  /// Clear all activities
  static Future<void> clearActivities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activitiesKey);
  }

  /// Enable guest mode
  static Future<void> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, true);
  }

  /// Disable guest mode
  static Future<void> disableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
  }

  /// Check if in guest mode
  static Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestModeKey) ?? false;
  }

  /// Get activity statistics
  static Future<Map<String, dynamic>> getActivityStats() async {
    final prefs = await SharedPreferences.getInstance();
    final activities = _loadActivities(prefs);
    final pending =
        activities.where((a) => !(a['synced'] == true)).toList();
    final synced =
        activities.where((a) => a['synced'] == true).toList();

    return {
      'total_count': activities.length,
      'pending_count': pending.length,
      'synced_count': synced.length,
      'last_activity': activities.isNotEmpty
          ? activities.last['timestamp']
          : null,
    };
  }

  /// Helper method to load activities from preferences
  static List<Map<String, dynamic>> _loadActivities(
    SharedPreferences prefs,
  ) {
    final jsonString = prefs.getString(_activitiesKey) ?? '[]';
    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Record common activities
  static Future<void> logScan({
    required String imageFile,
    required String diseaseDetected,
    String? confidence,
  }) async {
    await logActivity(
      action: 'scan.create',
      description: 'Created scan: $diseaseDetected',
      details: {
        'image_file': imageFile,
        'disease_detected': diseaseDetected,
        'confidence': confidence,
      },
    );
  }

  static Future<void> logDashboardView() async {
    await logActivity(
      action: 'dashboard.view',
      description: 'Viewed dashboard',
    );
  }

  static Future<void> logSettingsUpdate(String field, String value) async {
    await logActivity(
      action: 'settings.update',
      description: 'Updated settings: $field',
      details: {
        'field': field,
        'value': value,
      },
    );
  }
}

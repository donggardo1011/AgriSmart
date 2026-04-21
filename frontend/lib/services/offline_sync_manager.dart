import 'dart:async';
import 'package:http/http.dart' as http;

import 'connectivity_service.dart';
import 'offline_queue_service.dart';
import 'prediction_service.dart';
import '../core/constants.dart';

class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._();

  factory OfflineSyncManager() {
    return _instance;
  }

  OfflineSyncManager._();

  late PredictionService _predictionService;
  final _syncController = StreamController<SyncStatus>.broadcast();
  Timer? _syncTimer;
  bool _isSyncing = false;

  Future<void> initialize(String token) async {
    _predictionService = PredictionService(token);
    
    // Start sync when connection is restored
    ConnectivityService().connectivityStream.listen((isOnline) {
      if (isOnline) {
        syncPendingItems();
      }
    });

    // Check for pending items every 60 seconds if online
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (ConnectivityService().isOnline) {
        syncPendingItems();
      }
    });
  }

  /// Sync all pending items in the queue
  Future<void> syncPendingItems() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncController.add(SyncStatus.syncing());

    try {
      final pending = await OfflineQueueService.getPendingItems();
      if (pending.isEmpty) {
        _syncController.add(SyncStatus.synced());
        return;
      }

      int successCount = 0;
      int failureCount = 0;

      for (final item in pending) {
        try {
          final queueId = item['id'] as int;
          final imagePath = item['image_path'] as String;
          final fileName = item['image_file_name'] as String;
          final prediction = item['prediction'] as Map<String, dynamic>;

          _syncController.add(
            SyncStatus.syncingItem(
              itemId: queueId,
              itemName: fileName,
              totalPending: pending.length,
            ),
          );

          // Upload to backend
          await _predictionService.analyzeLeafImageOnline(imagePath, fileName);

          // Mark as synced
          await OfflineQueueService.markAsSynced(queueId);
          await OfflineQueueService.removeSyncedItem(queueId);
          successCount++;

          _syncController.add(SyncStatus.itemSynced(queueId));
        } catch (e) {
          failureCount++;
          final queueId = item['id'] as int;
          await OfflineQueueService.updateSyncError(
            queueId,
            e.toString(),
          );

          _syncController.add(SyncStatus.itemSyncFailed(queueId, e.toString()));
        }
      }

      final remaining = await OfflineQueueService.getPendingItems();
      if (remaining.isEmpty) {
        _syncController.add(
          SyncStatus.completed(
            successCount: successCount,
            failureCount: failureCount,
          ),
        );
      } else {
        _syncController.add(
          SyncStatus.partialSync(
            successCount: successCount,
            failureCount: failureCount,
            remainingCount: remaining.length,
          ),
        );
      }
    } catch (e) {
      _syncController.add(SyncStatus.error(e.toString()));
    } finally {
      _isSyncing = false;
    }
  }

  /// Get sync status stream
  Stream<SyncStatus> get syncStream => _syncController.stream;

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  void dispose() {
    _syncTimer?.cancel();
    _syncController.close();
  }
}

sealed class SyncStatus {
  const SyncStatus();

  factory SyncStatus.syncing() => const _Syncing();
  factory SyncStatus.syncingItem({
    required int itemId,
    required String itemName,
    required int totalPending,
  }) =>
      _SyncingItem(itemId, itemName, totalPending);

  factory SyncStatus.itemSynced(int itemId) => _ItemSynced(itemId);
  factory SyncStatus.itemSyncFailed(int itemId, String error) =>
      _ItemSyncFailed(itemId, error);

  factory SyncStatus.completed({
    required int successCount,
    required int failureCount,
  }) =>
      _Completed(successCount, failureCount);

  factory SyncStatus.partialSync({
    required int successCount,
    required int failureCount,
    required int remainingCount,
  }) =>
      _PartialSync(successCount, failureCount, remainingCount);

  factory SyncStatus.error(String message) => _Error(message);
  factory SyncStatus.synced() => const _Synced();
}

class _Syncing extends SyncStatus {
  const _Syncing();
}

class _Synced extends SyncStatus {
  const _Synced();
}

class _SyncingItem extends SyncStatus {
  final int itemId;
  final String itemName;
  final int totalPending;

  const _SyncingItem(this.itemId, this.itemName, this.totalPending);
}

class _ItemSynced extends SyncStatus {
  final int itemId;

  const _ItemSynced(this.itemId);
}

class _ItemSyncFailed extends SyncStatus {
  final int itemId;
  final String error;

  const _ItemSyncFailed(this.itemId, this.error);
}

class _Completed extends SyncStatus {
  final int successCount;
  final int failureCount;

  const _Completed(this.successCount, this.failureCount);
}

class _PartialSync extends SyncStatus {
  final int successCount;
  final int failureCount;
  final int remainingCount;

  const _PartialSync(this.successCount, this.failureCount, this.remainingCount);
}

class _Error extends SyncStatus {
  final String message;

  const _Error(this.message);
}

# Offline Detection - Technical Reference

## Architecture Overview

```
┌─────────────────────────────────────————────────────┐
│                  Flutter App                        │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────────────────────────────────┐  │
│  │ User Actions                                 │  │
│  │ • Take Photo                                 │  │
│  │ • Select from Gallery                        │  │
│  │ • Force Offline Mode                         │  │
│  └─────────────────┬──────────────────────────┘  │
│                    │                              │
│  ┌─────────────────▼──────────────────────────┐  │
│  │ ConnectivityService                        │  │
│  │ • Monitors internet status                 │  │
│  │ • Broadcasts via Stream                    │  │
│  │ • Checks every 30 seconds                  │  │
│  └─────────────────┬──────────────────────────┘  │
│                    │                              │
│  ┌────────────────┴────────────────────────┐    │
│  │              PredictionService          │    │
│  │  • Creates predictions                  │    │
│  │  • Checks connectivity                  │    │
│  │  • Routes online/offline                │    │
│  └────────────┬─────────────────┬──────────┘    │
│               │                 │                 │
│    ┌──────────▼─────┐     ┌─────▼──────────┐    │
│    │ Online Path    │     │ Offline Path   │    │
│    │ Upload to      │     │ Local TFLite   │    │
│    │ Backend API    │     │ Model          │    │
│    └──────────┬─────┘     └─────┬──────────┘    │
│               │                 │                 │
│    ┌──────────▼────────────────▼───────────┐    │
│    │    ScanCacheService                    │    │
│    │    • Caches all results               │    │
│    │    • SharedPreferences                │    │
│    └──────────┬───────────────────────────┘    │
│               │                                  │
│    ┌──────────▼────────────────────────────┐    │
│    │  OfflineQueueService                   │    │
│    │  • Stores offline images              │    │
│    │  • Manages upload queue               │    │
│    │  • Persists to file system            │    │
│    └──────────┬────────────────────────────┘    │
│               │                                  │
│    ┌──────────▼────────────────────────────┐    │
│    │  OfflineSyncManager                    │    │
│    │  • Monitors connectivity               │    │
│    │  • Auto-triggers sync                 │    │
│    │  • Broadcasts sync status             │    │
│    └──────────┬────────────────────────────┘    │
│               │                                  │
│    ┌──────────▼────────────────────────────┐    │
│    │  Backend API                           │    │
│    │  • POST /api/predictions               │    │
│    │  • Creates activity log                │    │
│    └────────────────────────────────────────┘    │
│                                                  │
└──────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### Online Detection Flow
```
User selects image
    → PredictionService.analyzeLeafImage()
    → ConnectivityService.checkNow() = true
    → _client.multipartPost(/api/predictions)
    → Backend processes → Returns result
    → ScanCacheService.cachePrediction()
    → Display result immediately
```

### Offline Detection Flow
```
User selects image
    → PredictionService.analyzeLeafImage()
    → ConnectivityService.checkNow() = false
    → OfflineLeafDiagnosisService.analyzeImage()
    → TFLite model runs on device
    → ScanCacheService.cachePrediction()
    → OfflineQueueService.queueOfflineDetection()
    → Save image locally
    → Display result immediately
    → Queue for later upload
```

### Auto-Sync Flow
```
ConnectivityService detects connection
    → Broadcasts true via stream
    → OfflineSyncManager catches event
    → OfflineSyncManager.syncPendingItems()
    → OfflineQueueService.getPendingItems()
    → For each item:
        → PredictionService.analyzeLeafImageOnline()
        → Upload to backend
        → Backend processes -> logs activity
        → OfflineQueueService.markAsSynced()
        → OfflineQueueService.removeSyncedItem()
    → Broadcast sync status to UI
    → ScanScreen updates UI
```

## Service Interactions

### ConnectivityService
```dart
class ConnectivityService {
  late StreamController<bool> _connectivityController;
  bool _isOnline = false;
  Timer? _connectivityTimer;
  
  Future<void> initialize()          // Call on app start
  Future<bool> checkNow()            // Force check
  bool get isOnline                  // Sync access
  Stream<bool> get connectivityStream // Async access
  void dispose()                      // Cleanup
}
```

**Used by**:
- PredictionService (checks before upload)
- ScanScreen (updates UI badge)
- OfflineSyncManager (triggers on change)

---

### OfflineQueueService
```dart
static Future<void> queueOfflineDetection({
  required Map<String, dynamic> prediction,
  required String imagePath,
  String? imageFileName,
})

static Future<List<Map<String, dynamic>>> getPendingItems()
static Future<void> markAsSynced(int queueId)
static Future<void> removeSyncedItem(int queueId)
static Future<Map<String, dynamic>> getQueueStats()
static Future<void> clearQueue()
```

**Storage Format**:
```json
{
  "offline_upload_queue": [
    {
      "id": 1712800000000,
      "timestamp": "2026-04-10T12:00:00Z",
      "prediction": { /* detection result */ },
      "image_path": "/path/to/image.jpg",
      "image_file_name": "1712800000000.jpg",
      "synced": false,
      "sync_attempts": 0,
      "last_sync_error": null
    }
  ]
}
```

---

### OfflineSyncManager
```dart
class OfflineSyncManager {
  Future<void> initialize(String token)
  Future<void> syncPendingItems()
  Stream<SyncStatus> get syncStream
  bool get isSyncing
  void dispose()
}

sealed class SyncStatus {
  factory SyncStatus.syncing()
  factory SyncStatus.syncingItem({required int itemId, required String itemName, required int totalPending})
  factory SyncStatus.itemSynced(int itemId)
  factory SyncStatus.itemSyncFailed(int itemId, String error)
  factory SyncStatus.completed({required int successCount, required int failureCount})
  factory SyncStatus.partialSync({required int successCount, required int failureCount, required int remainingCount})
  factory SyncStatus.error(String message)
}
```

**Internal Flow**:
1. Check if already syncing (guard against concurrent syncs)
2. Get pending items from OfflineQueueService
3. For each item:
   - Emit syncingItem status
   - Upload via PredictionService
   - Mark as synced
   - Remove from queue
4. Emit completed/partialSync status

---

### Updated PredictionService
```dart
Future<Map<String, dynamic>> analyzeLeafImage(
  String filePath,
  String filename, {
  bool forceOffline = false,
  bool allowOfflineFallback = true,
})

// New logic:
if (forceOffline) {
  // Run offline model
  // Queue for upload
  return result
}

final isOnline = await ConnectivityService().checkNow()
if (isOnline) {
  // Try upload
  // On failure, fallback to offline
} else {
  // Run offline
  // Queue for upload
}
```

## State Management

### No Redux/Provider - Simple Approach
- **ConnectivityService**: Stream-based (one source of truth)
- **OfflineQueueService**: SharedPreferences + file system
- **OfflineSyncManager**: Firebase-like sealed class events
- **ScanScreen**: Basic setState() for UI

### Data Persistence
```
SharedPreferences
├── admin_access_token          (auth)
├── cached_predictions          (all results)
└── offline_upload_queue        (pending items)

File System
└── app_documents/offline_uploads/
    ├── 1712800000000.jpg       (image 1)
    ├── 1712800120000.jpg       (image 2)
    └── ...
```

## API Endpoints Used

### Prediction Upload
```
POST /api/predictions
Content-Type: multipart/form-data

Fields:
  - image: <file binary>
  - (optional) model_version: string

Response:
{
  "id": 123,
  "label": "leaf_blast",
  "confidence": 0.95,
  "disease_name": "Rice Leaf Blast Disease",
  "description": "...",
  "remedy": "...",
  "created_at": "2026-04-10T12:00:00Z"
}
```

### Activity Logging
```
Auto-triggered when syncing predictions
POST /admin/activities

Logged by backend with:
{
  "user_id": 123,
  "action": "prediction.create",
  "detail": {
    "image_file_name": "1712800000000.jpg",
    "synced_at": "2026-04-10T12:00:00Z",
    "offline_mode": true
  }
}
```

## Error Handling Strategy

### Network Errors
```
If online upload fails:
  → Fallback to offline mode
  → Run local model instead
  → Queue for later sync
  → Show result (offline source noted)
```

### Offline Model Missing
```
If local model unavailable:
  → Check asset bundling
  → Return OfflineDiagnosisUnavailable error
  → ScanScreen shows helpful message
  → Suggest bundling model or using online
```

### Sync Failures
```
If upload fails during sync:
  → Log error with timestamp
  → Increment sync_attempts
  → Store error message
  → Continue with other items
  → Show partialSync status
  → Retry automatically in 60 seconds
```

### Corrupted Data
```
If queue item is corrupted:
  → Skip item and log
  → Continue with next item
  → Mark attempted in stats
  → User sees partial sync
```

## Performance Characteristics

### Detection Speed
```
Offline TFLite:    1.5-5 seconds per image
Online (with upload): 5-15 seconds per image
Backend processing: ~500ms
```

### Storage Efficiency
```
Per image stored:     ~2-3 MB (at 85% quality)
Per queue entry:      ~100 bytes
Per cached prediction: ~500 bytes
```

### Memory Usage
```
Idle:                 ~80-100 MB
TFLite inference:     +100-150 MB spike
100 cached results:   +20 MB
```

### Connectivity Check
```
Check interval:       30 seconds
Timeout per check:    3 seconds
Network test server:  google.com
```

## Debugging Tips

### Enable Detailed Logging
```dart
// In ConnectivityService.initialize()
debugPrint('Connectivity changed: $isOnline');
```

### Check Queue Status
```dart
final stats = await OfflineQueueService.getQueueStats();
print('Pending: ${stats['pending']}, Synced: ${stats['synced']}');
```

### Monitor Sync Stream
```dart
_syncManager.syncStream.listen((status) {
  if (status is _SyncingItem) {
    print('Syncing: ${status.itemName}');
  }
});
```

### Verify Queue Persistence
```dart
// Navigate away and back
// Queue count should persist
// Items should re-load correctly
```

## Known Limitations

1. **No selective upload** - All items sync automatically
2. **No retry scheduling** - Retries every 60 seconds
3. **No compression** - Images uploaded full size
4. **No batch API** - One POST per image
5. **No progress reporting** - Only overall status
6. **No pause/resume** - Auto-triggers on restore

## Future Enhancement Ideas

- [ ] Batch upload endpoint (POST /api/predictions/batch)
- [ ] Image compression before upload
- [ ] Selective sync (checkbox per item)
- [ ] Sync scheduling/throttling
- [ ] Detailed sync history UI
- [ ] Network quality detection (WiFi vs 4G)
- [ ] Upload cancellation
- [ ] Resume interrupted sync

## Testing Scenarios

### Unit Tests (add to test/)
- ConnectivityService stream broadcasts
- OfflineQueueService persistence
- OfflineSyncManager status transitions
- PredictionService routing logic

### Integration Tests
- Full offline detection flow
- Full sync flow
- Queue persistence after app restart
- Concurrent connectivity changes

### Manual Tests
- Offline detection (covered in checklist)
- Auto-sync (covered in checklist)  
- Error scenarios (network timeout, etc)
- Edge cases (rapid wifi toggle, etc)

---

**Last Updated**: April 10, 2026
**Status**: Complete & Ready for Use

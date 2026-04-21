# Offline Detection & Upload Feature

## Overview

Your AgriSmart app now supports **full offline functionality** for disease detection and image uploads. Users can:

- ✅ Detect diseases in real-time using the local machine learning model
- ✅ View detection results immediately without internet
- ✅ Capture and analyze multiple images offline
- ✅ Automatically sync results to the backend when internet is restored
- ✅ See real-time sync status and queue information

## Architecture

### Services

#### 1. **ConnectivityService** (`lib/services/connectivity_service.dart`)
- Monitors internet connectivity status
- Provides real-time stream updates when connection state changes
- Automatically checks connectivity every 30 seconds
- Singleton pattern for app-wide access

#### 2. **OfflineQueueService** (`lib/services/offline_queue_service.dart`)
- Manages a local queue of detections waiting to be uploaded
- Stores images in app documents directory for offline access
- Persists queue state using SharedPreferences
- Provides queue statistics and management functions

#### 3. **OfflineSyncManager** (`lib/services/offline_sync_manager.dart`)
- Handles automatic syncing when internet connection is restored
- Manages retry logic and error tracking
- Provides real-time sync status updates via Stream
- Automatically initiates sync every 60 seconds when online

#### 4. **Updated PredictionService** (`lib/services/prediction_service.dart`)
- Enhanced to check connectivity before upload attempts
- Automatically queues offline detections for later sync
- Falls back to offline model when internet unavailable
- Seamless offline-to-online transition

### Real-Time Detection Offline

When offline:
1. User captures or selects an image
2. Local TensorFlow Lite model (best.tflite) processes the image
3. Detection results are cached locally using SharedPreferences
4. Image is stored in app documents for later viewing
5. Detection is added to offline queue

### Automatic Sync

When internet connection is restored:
1. ConnectivityService detects connection
2. OfflineSyncManager automatically syncs pending items
3. Each queued detection is uploaded to backend API
4. Backend logs the activity with user information
5. Synced items are marked and removed from queue
6. Real-time status updates show sync progress

## UI Components

### Status Indicators

**AppBar Chip (Online/Offline Status)**
- Green "ONLINE" - connected to internet
- Orange "OFFLINE" - no internet connection

**Pending Upload Card**
- Shows count of detections waiting to sync
- Displays "Will sync when connected" when offline
- Updates automatically as queue changes

**OfflineSyncStatus Widget**
- Shows real-time sync progress
- Displays success/failure counts
- Shows error messages if sync fails

## Implementation Details

### Detection Flow Offline

```
User → Pick Image → Check Connectivity
        ↓
     Online? → Yes → Upload to Backend → Get Result
        ↓
        No → Run Local Model → Cache Result → Queue for Upload
```

### Sync Flow Online

```
Internet Restored → DetectConnectivityChange → Get Queue → Upload Items
        ↓
   Success → Remove from Queue → Update UI
        ↓
   Failure → Log Error → Retry on Next Cycle
```

## Storage Structure

```
App Documents/
├── offline_uploads/           # Locally stored images
│   ├── {timestamp}.jpg
│   ├── {timestamp}.jpg
│   └── ...
└── shared_preferences/        # SharedPreferences
    ├── cached_predictions    # All detection results
    └── offline_upload_queue  # Pending uploads
```

## Key Features

### 1. Zero Internet Requirement
- Full app functionality without network connection
- All ML processing happens locally on device
- No server call needed for detection

### 2. Automatic Queue Management
- Images automatically queued offline
- Queue persisted across app restarts
- Old/synced items auto-cleaned

### 3. Intelligent Connectivity Tracking
- Real-time connection monitoring
- Automatic retry logic
- Graceful offline-to-online transitions

### 4. User Activity Logging
- Activities synced to backend when online
- Preserves user trail for analytics
- Admin can see detection history

## Usage in Screens

### ScanScreen
```dart
// Automatically checks connectivity
// Shows online/offline status
// Displays pending queue count
// User can force offline-only mode
```

### ChatbotScreen
```dart
// Works with cached/offline results
// Shows detection details from local storage
// Syncs activity when connection restored
```

## Configuration

### Offline Model
- Location: `assets/models/best.tflite`
- Required for offline detection
- Size: ~50-100MB (configure in build)

### Connectivity Check
- Default interval: 30 seconds
- Test server: google.com
- Timeout: 3 seconds

### Sync Interval
- Default check: 60 seconds (when online)
- Automatic retry on connection restore

## Error Handling

### Offline Model Unavailable
```
Error: offline_detection_unavailable
Solution: ensure best.tflite is bundled in assets/models/
```

### No Internet & No Offline Model
```
Display: informative message to user
Action: queue for upload when connection available
```

### Sync Failures
```
Logged: error message and sync attempts
Retry: automatic on next connectivity check
Display: partial sync status in UI
```

## Testing Offline Flow

1. **Enable Offline Mode**
   - Toggle "Use offline model" switch (if available)
   - Disconnect internet

2. **Capture Image**
   - Take photo or select from gallery
   - Should get instant results

3. **Verify Queue**
   - Check "Pending Upload" card
   - Should show detected count

4. **Restore Connection**
   - Re-enable internet
   - Watch "Syncing" status appear
   - Should auto-complete when done

5. **Verify Backend**
   - Check Admin Dashboard activities
   - Should see the detection logged

## Backend Integration

### API Endpoints Used
- `POST /api/predictions` - Detection upload
- `GET /api/activities` - Activity log (queued when offline)
- `POST /admin/activities` - Backend activity logging

### User Activity Logging
When items sync:
```json
{
  "action": "prediction.create",
  "detail": {
    "image_file_name": "timestamp.jpg",
    "detection_synced_at": "2026-04-10T12:00:00Z",
    "offline_mode": true
  }
}
```

## Performance Considerations

- Local detection: ~2-5 seconds per image
- Offline queue: ~10MB per 100 images
- Sync cost: 1 API call per detection
- Memory: Safe for 1000+ cached results

## Future Enhancements

- [ ] Batch sync (upload multiple at once)
- [ ] Selective sync (choose which items to upload)
- [ ] Manual sync trigger button
- [ ] Sync scheduling (upload at specific times)
- [ ] Network quality detection (4G vs WiFi)
- [ ] Compression before upload
- [ ] Detailed sync history per item

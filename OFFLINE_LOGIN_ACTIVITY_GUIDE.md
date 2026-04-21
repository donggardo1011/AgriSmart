# Offline Login & Activity Sync Implementation

## Overview

Your AgriSmart app now supports **offline access without login** and **automatic activity syncing**. Users can:

- ✅ Access the app without internet connection (no login required)
- ✅ Perform scans and use all features in guest mode (offline)
- ✅ Have activities automatically tracked and stored locally
- ✅ Log in when online to sync all offline activities
- ✅ See sync status and indicators for guest mode

## Architecture

### New Services

#### 1. **OfflineActivityService** (`lib/services/offline_activity_service.dart`)
Local activity tracking for offline and guest mode users.

**Key Methods:**
- `logActivity()` - Log any user action locally
- `getPendingActivities()` - Get activities waiting to sync
- `logScan()`, `logDashboardView()`, `logSettingsUpdate()` - Convenience methods
- `enableGuestMode()` / `disableGuestMode()` - Toggle guest mode
- `isGuestMode()` - Check current mode
- `getActivityStats()` - Get sync statistics

**Storage:**
- Uses SharedPreferences for persistence
- Stores: action, description, timestamp, details, sync status

#### 2. **ActivitySyncService** (`lib/services/activity_sync_service.dart`)
Automatic syncing of activities to backend when online and authenticated.

**Key Methods:**
- `initialize(token)` - Start automatic sync (60-second timer)
- `syncPendingActivities(token)` - Sync all pending items
- `manualSync(token)` - Force immediate sync
- `dispose()` - Clean up resources

**Auto-Sync:**
- Starts automatically at 60-second intervals when user is logged in
- Can be manually triggered after login

### Modified Screens

#### 1. **LoginScreen** 
- Shows "Connected" / "No internet" indicator
- Displays "Continue as Guest" button when offline
- Passes `null` token for guest access
- Logs guest access attempt

#### 2. **AgrismartechApp**
- Tracks both `_accessToken` and `_isGuestMode`
- Loads guest mode state on app start
- Routes to Dashboard for both authenticated and guest users
- Initializes sync managers on login
- Syncs pending activities immediately after login

#### 3. **DashboardScreen**
- Accepts optional `accessToken` (nullable)
- Displays guest mode warning/banner
- Shows login button in AppBar when in guest mode
- Logs dashboard view activity on initialization
- Disables stats for guest users (optional)

## Workflow

### Offline Scenario

1. **User opens app without internet**
   - LoginScreen checks connectivity → shows "No internet connection"
   - "Continue as Guest" button appears
   - User taps button

2. **Guest mode enabled**
   - `OfflineActivityService.enableGuestMode()` called
   - Guest access activity logged
   - `onLoggedIn(null)` passed to app
   - Dashboard loads with guest UI

3. **User performs actions (scans, views, updates)**
   - Each action logged via `OfflineActivityService.logActivity()`
   - Stored in SharedPreferences locally
   - Activities marked with `synced: false`

4. **User sees guest mode indicator**
   - AppBar shows "Guest Mode (Offline)"
   - Warning banner explains activities will sync on login
   - Login button available in AppBar

### Online Sync Scenario

1. **User gets internet and taps Login button**
   - Navigates to LoginScreen
   - Now shows "Connected to server"
   - Can enter credentials

2. **User logs in**
   - Backend authenticates and returns token
   - `_handleLoggedIn(token)` called:
     - Token saved to SharedPreferences
     - Guest mode disabled
     - Sync managers initialized
     - `syncPendingActivities()` immediately called
     - Auto-sync timer started (60-second intervals)

3. **Activities sync to backend**
   - All pending activities sent to `/activities` endpoint
   - Each includes: action, description, timestamp, details
   - After successful sync:
     - Activity marked `synced: true`
     - Removed from local queue
     - Dashboard returns to normal mode

## Activity Tracking

### Tracked Activities

Currently logging:
- `auth.guest_access` - Guest mode entry
- `dashboard.view` - Dashboard viewed
- `scan.create` - Scan performed with disease detection
- `settings.update` - Settings changed

### Data Stored Per Activity

```dart
{
  'id': 1712345678123,              // Unique timestamp ID
  'action': 'scan.create',           // Activity type
  'description': 'Created scan: Leaf Blast',
  'timestamp': '2024-04-12T10:30:00.000Z',
  'details': {                       // Optional details
    'image_file': 'path_to_image',
    'disease_detected': 'Leaf Blast',
    'confidence': '0.95'
  },
  'user_id': null,                   // Set when user logs in
  'synced': false,                   // Sync status
  'sync_attempts': 0,                // Retry counter
  'last_sync_error': null            // Error message if failed
}
```

## Backend Integration

### Activity Endpoint

**Expected to exist:** `POST /activities`

**Request body:**
```json
{
  "action": "scan.create",
  "description": "Created scan: Leaf Blast",
  "timestamp": "2024-04-12T10:30:00.000Z",
  "details": {
    "image_file": "...",
    "disease_detected": "Leaf Blast",
    "confidence": "0.95"
  }
}
```

**Requirements:**
- Authenticated (Bearer token required)
- Returns 200 or 201 on success
- Stores activity linked to authenticated user

### Implementation Note
If the endpoint doesn't exist yet, create it in your FastAPI backend:

```python
@router.post('/activities')
def create_activity(
    activity: ActivitySchema,
    current_user: User = Depends(get_current_user)
):
    # Log activity with user_id
    return {"status": "logged"}
```

## Configuration

### Connectivity Check
- Located in `ConnectivityService`
- Checks connectivity every 30 seconds
- Uses `InternetAddress.lookup('google.com')` for detection
- Customizable endpoint if needed

### Auto-Sync Timer
- Located in `ActivitySyncService.initialize()`
- Default: 60-second interval
- Can be adjusted via `Timer.periodic(Duration(...))`

### SharedPreferences Keys
- `offline_activities` - Activity queue
- `offline_guest_mode` - Guest mode flag
- `offline_token` - Auth token (existing)
- `offline_uploads` - Directory for uploads

## User Experience

### Visual Indicators

**Offline (Guest Mode)**
```
AppBar: "AgriSmart" | "Guest Mode (Offline)" (orange)
⚠️  WARNING: "You are in guest mode. Log in to sync your activities..."
🔑 Login button in AppBar
```

**Online (Connected)**
```
AppBar: "AgriSmart" | "Rice Disease Detector" (normal)
✅ Connected to server indicator
No warnings
```

**After Login**
```
Dashboard loads normally
All offline activities begin syncing
Activities cleared from local queue after sync
Auto-sync continues in background
```

## Error Handling

### Network Errors
- Automatic retry on next sync cycle (60 seconds)
- Stores error message in `last_sync_error`
- Increments `sync_attempts` counter
- Continues with other activities (doesn't block)

### Sync Failures
- Activities remain in queue for retry
- User can see pending count in stats
- Manual sync available via `ActivitySyncService.manualSync(token)`

## Testing Checklist

- [ ] **Offline Access**
  - [ ] Turn off WiFi/Mobile data
  - [ ] See "No internet connection" message
  - [ ] Tap "Continue as Guest"
  - [ ] Dashboard loads and shows guest banner
  - [ ] Can scan and use features
  - [ ] Activities are saved locally

- [ ] **Guest Mode Activities**
  - [ ] Each action is logged locally
  - [ ] Multiple scans are queued
  - [ ] Stats show pending count
  - [ ] Login button visible

- [ ] **Online Sync**
  - [ ] Turn on WiFi/Mobile data
  - [ ] Tap login in AppBar
  - [ ] Log in with credentials
  - [ ] Activities sync in 60 seconds
  - [ ] Dashboard returns to normal
  - [ ] All scans visible in Recent Scans

- [ ] **Multiple Sessions**
  - [ ] Guest mode in session 1
  - [ ] Log in in session 2
  - [ ] Previous activities synced
  - [ ] No duplicate activities

## Future Enhancements

1. **Manual Activity Trigger** - UI button to manually sync
2. **Offline Data Sync** - Sync images/predictions, not just activities
3. **Conflict Resolution** - Handle activity updates/deletes
4. **Analytics Dashboard** - Show activity history and patterns
5. **Export Activities** - CSV/PDF export of activities
6. **Activity Filtering** - Filter by date, type, status
7. **Batch Operations** - Bulk retry/delete failed syncs

## Files Changed

### New Files Created
- `lib/services/offline_activity_service.dart` - Activity tracking
- `lib/services/activity_sync_service.dart` - Backend sync

### Modified Files
- `lib/screens/login_screen.dart` - Added offline/guest mode UI
- `lib/app/agrismartech_app.dart` - Added guest mode state management
- `lib/screens/dashboard_screen.dart` - Made guest mode aware

### No Changes Required
- Backend routes exist (or may need `/activities` endpoint)
- Existing offline sync features remain functional
- Existing scan/prediction features work in guest mode

## Summary

Your AgriSmart app now provides:
✅ **Offline-First Architecture** - Works without internet
✅ **Activity Tracking** - All user actions logged locally
✅ **Automatic Sync** - Background sync when authenticated
✅ **Guest Mode** - Access without login credentials
✅ **User Transparency** - Clear indicators of offline/guest status

Users get a seamless experience whether online or offline!

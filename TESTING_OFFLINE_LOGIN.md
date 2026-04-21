# Quick Testing Guide - Offline Login & Activity Sync

## Prerequisites
- Run your FastAPI backend
- Have the following endpoint ready (or create it):
  ```python
  @router.post('/activities')
  def create_activity(
      activity: ActivitySchema,
      current_user: User = Depends(get_current_user)
  ):
      # Store activity for user
      return {"status": "success", "activity_id": ...}
  ```

## Test Scenario 1: Offline Guest Access

### Steps:
1. **Stop your WiFi/Mobile data** (simulate offline)
2. **Run the Flutter app** fresh or restart it
3. **Expected:** LoginScreen shows "No internet connection" (orange indicator)
4. **Tap "Continue as Guest"** button
5. **Expected:** Dashboard loads with yellow warning banner:
   - "You are in guest mode. Log in to sync your activities and access all features."
   - AppBar shows "Guest Mode (Offline)" instead of "Rice Disease Detector"
   - Login button (key icon) appears in AppBar

### Verify Activity Logging:
```dart
// In app terminal, you can log SharedPreferences to verify:
// (Requires adding debug logging to offline_activity_service.dart)

final prefs = await SharedPreferences.getInstance();
final activities = prefs.getString('offline_activities');
print('Stored activities: $activities');
```

## Test Scenario 2: Offline Actions & Local Storage

### Steps After Guest Access:
1. **Perform actions in the app:**
   - Tap "Scan Leaf" → Take a photo → Get prediction
   - Navigate to different screens
   - Change any settings

2. **Expected:** All actions logged locally without errors

3. **Verify storage:** (Add debug logging)
   - Activities should be in SharedPreferences with:
     - `synced: false`
     - `sync_attempts: 0`
     - `action`, `timestamp`, `details` fields

## Test Scenario 3: Online Sync After Login

### Steps:
1. **Turn WiFi/Mobile back on** (restore connection)
2. **App automatically detects connection** → LoginScreen updates to show "Connected to server"
3. **Tap login button in AppBar** (or navigate to LoginScreen manually)
4. **Log in with valid credentials**
5. **Expected:**
   - Token saved
   - Guest mode disabled
   - Dashboard reloads without warning banner
   - In 60 seconds (or less), activities begin syncing

### Verify Backend Sync:
1. **Check backend logs** - Should see POST requests to `/activities`
2. **Check database** - Activities table should have new entries for your user
3. **Each activity should have:**
   - action, description, timestamp, details from the app

## Test Scenario 4: Multiple Scans in Guest Mode → Sync

### Steps:
1. Go offline (turn off WiFi/Mobile)
2. Tap "Continue as Guest"
3. **Perform 3+ scans:**
   - Each scan creates activity with disease detection data
   - Takes ~5-10 seconds per scan
4. After 3 scans, verify in SharedPreferences:
   - At least 3 activity entries with `synced: false`
   - Dashboard view activity also logged

5. **Go online** (turn WiFi on)
6. Tap Login button → Log in
7. **Wait 60 seconds** for auto-sync
8. **Verify:**
   - Backend received 4+ POST requests to `/activities`
   - Activities linked to your user
   - Local queue cleared (check SharedPreferences)

## Test Scenario 5: Manual Activity Stats

### Implementation for Testing:
Add this to Dashboard or a debug screen:

```dart
onPressed: () async {
  final stats = await OfflineActivityService.getActivityStats();
  print('Activity Stats: $stats');
  // Shows: total_count, pending_count, synced_count, last_activity
},
```

Expected output when offline:
```
Activity Stats: {
  'total_count': 4,
  'pending_count': 4,
  'synced_count': 0,
  'last_activity': '2024-04-12T10:35:00.000Z'
}
```

After login & sync:
```
Activity Stats: {
  'total_count': 0,  // All synced and removed from local queue
  'pending_count': 0,
  'synced_count': 0,
  'last_activity': null
}
```

## Test Scenario 6: Error Handling

### Simulate Backend Failure:
1. Make requests to wrong endpoint or stop backend
2. Perform actions in guest mode
3. Go online and log in
4. **Expected:** Activities fail to sync but don't crash app
5. Check SharedPreferences:
   - Activities still present with `sync_attempts > 0`
   - `last_sync_error` contains error message
6. **Retry:** Wait 60 seconds for auto-retry
7. Start backend again → Activities should sync on next attempt

## Debugging Tips

### Enable Debug Logging:
Add to your services:
```dart
debugPrint('[OfflineActivity] Logged: $action');
debugPrint('[ActivitySync] Syncing ${pending.length} activities');
```

### Check Local Storage:
```dart
// Add a debug route to view all data
final prefs = await SharedPreferences.getInstance();
final activities = prefs.getString('offline_activities');
final isGuest = prefs.getBool('offline_guest_mode');
print('Activities: $activities');
print('Guest Mode: $isGuest');
```

### Monitor Network:
1. In Flutter DevTools → Network tab
2. Should see POST requests to `/activities` endpoint when syncing
3. Check request/response bodies

### Run in Debug Mode:
```bash
cd frontend
flutter run -v
```
Use `-v` flag for verbose output including HTTP requests.

## Expected API Requests

### When Syncing Activities:
```
POST /activities
Authorization: Bearer <user_token>
Content-Type: application/json

{
  "action": "scan.create",
  "description": "Created scan: Leaf Blast",
  "timestamp": "2024-04-12T10:35:00Z",
  "details": {
    "image_file": "...",
    "disease_detected": "Leaf Blast",
    "confidence": "0.95"
  }
}
```

### Expected Response:
```json
{
  "status": "success",
  "activity_id": 123
}
```

Or just `{"status": "success"}` is fine.

## Common Issues & Solutions

### Issue: "Continue as Guest" button doesn't appear
- **Cause:** App thinks it's online (check ConnectivityService)
- **Fix:** Actually turn off WiFi/Mobile data or simulate offline

### Issue: Activities don't sync after login
- **Cause:** Backend `/activities` endpoint doesn't exist
- **Fix:** Create the endpoint as shown above
- **Check:** Backend logs for error responses

### Issue: Same activity logged multiple times
- **Cause:** App lifecycle recreates widgets
- **Fix:** Ensure dashboard initializes only once (move logging)

### Issue: SharedPreferences shows old data
- **Cause:** Prefs not cleared between tests
- **Fix:** Uninstall/reinstall app or add clear in code:
  ```dart
  await OfflineActivityService.clearActivities();
  ```

## Success Criteria

✅ **Offline Access:** Can use app without internet
✅ **Guest Mode:** No login required when offline
✅ **Activity Logging:** All actions tracked locally
✅ **Visual Feedback:** Guest indicator visible
✅ **Auto-Sync:** Activities sync 60 seconds after login
✅ **Sync Complete:** Activities removed from queue after successful sync
✅ **Error Handling:** Sync failures don't crash app
✅ **Retry Logic:** Failed syncs retry automatically

## Next Steps

1. Test all scenarios above
2. Fix any issues in services
3. If backend `/activities` endpoint needed → Create in FastAPI
4. Adjust sync interval if needed (60 seconds → different value)
5. Add more activity types as features are added
6. Consider UI for manual sync trigger

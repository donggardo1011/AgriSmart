# Network Configuration Guide

## API Base URL Settings

The mobile app connects to your backend server using the URL configured in `frontend/lib/core/config.dart`.

### Current Configuration
```
http://10.225.11.187:8000
```

### For Different Testing Scenarios

**1. Android Emulator (on your PC)**
```dart
const String apiBaseUrl = 'http://10.0.2.2:8000';
```
(10.0.2.2 is the emulator's way to reach host machine localhost)

**2. Physical Device on Same LAN**
Find your PC/server IP and use:
```dart
const String apiBaseUrl = 'http://192.168.1.XX:8000';  // Replace XX with actual IP
```
To find your IP:
- Windows PowerShell: `ipconfig` → look for "IPv4 Address"
- Make sure mobile device is on same WiFi network

**3. Different Network / Remote Server**
Use public IP or domain:
```dart
const String apiBaseUrl = 'https://your-domain.com:8000';
```
Requires backend to be accessible and CORS configured.

**4. Docker Container**
If running backend in Docker:
```dart
const String apiBaseUrl = 'http://host.docker.internal:8000';
```

## Recent Changes Made (v2.0)

### Timeout Adjustments
- **Before**: 15 seconds (too tight for mobile networks)
- **After**: 30 seconds (better for slower connections)
- **Location**: 
  - `frontend/lib/services/api_client.dart`
  - `frontend/lib/screens/login_screen.dart`

### Error Messages Improved
Login now shows specific error messages for:
- **Timeout**: "Connection timeout. Server is not responding."
- **Network Error**: "Network error. Cannot reach the server."
- Shows the server IP being used for debugging

## Debugging Steps

If you still get timeout:

1. **Verify Server is Running**
   ```bash
   # From your PC
   curl http://10.225.11.187:8000/health
   ```

2. **Check Network Connectivity**
   - Mobile device: Open browser, go to `http://10.225.11.187:8000`
   - Should see some response (even if 404)

3. **Verify Firewall**
   - Windows Firewall: Allow Python through firewall
   - Router: May need to open port 8000

4. **Check Backend Logs**
   Look at uvicorn output for 401/403/500 errors

## Recommended Workflow

1. Update `apiBaseUrl` for your test environment
2. RUN: `flutter pub get` (to sync any changes)
3. RUN: `flutter run` (rebuild app)
4. TRY: Login again
5. If still failing, check error message shown in app

---
**Note**: The 10.225.11.187 IP appears to be an internal network address specific to your development environment. Update it based on where your backend is actually running.

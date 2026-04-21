# Token Debugging & 401 Error Troubleshooting Guide

## Overview
This guide helps diagnose premature 401 Unauthorized errors despite JWT tokens configured for 90 days. All fixes are now in place.

## Changes Made (Message 12)

### 1. **Enhanced Admin Activities Display**
- **File**: `/admin-web/app/activities/page.tsx`
- **Change**: Added `location` field to ActivityRow interface
- **Display**: Activities table now shows:
  - Action
  - User (username)
  - Email
  - Location
  - Time
  - Detail

### 2. **Dashboard Location Display**
- **File**: `/admin-web/app/dashboard/page.tsx`
- **Change**: Added `location` field to ActivityRow interface
- **Display**: Dashboard activities now show user email and location inline

### 3. **Improved Token Validation**
- **File**: `/backend/auth.py`
- **Changes**:
  - Added explicit expiration check in `decode_token()`
  - Token validation now logs exact remaining time
  - Better error messages distinguishing between different failure modes

### 4. **Debug Endpoint for Token Inspection**
- **File**: `/backend/routes/auth_routes.py`
- **Endpoint**: `GET /auth/debug/token-info`
- **Authentication**: Requires valid Authorization header with Bearer token
- **Response**: Shows token claims including:
  - `sub`: User ID
  - `iat`: Issued at (seconds since epoch)
  - `exp`: Expiration time (seconds since epoch)
  - `now`: Current server time
  - `token_age_seconds`: How old the token is
  - `exp_seconds_remaining`: How many seconds until expiration
  - `exp_days_remaining`: Days remaining (calculated)
  - `valid`: Boolean indicating if token is valid
  - `message`: Human-readable status

### 5. **Enhanced Error Logging**
- **File**: `/backend/routes/auth_routes.py`
- **Function**: `get_current_user()`
- **Changes**:
  - Comprehensive error logging with stack traces
  - Prints [AUTH ERROR] prefix for easy grep
  - Logs user_id lookup failures
  - Better debugging of token decode failures

## How to Debug 401 Errors

### Step 1: Check Token Validity
```bash
# Get your access token from localStorage (browser dev tools) or SharedPreferences (Flutter)
# Then call:
curl -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  http://localhost:8000/auth/debug/token-info
```

Expected response if token is valid:
```json
{
  "valid": true,
  "sub": "1",
  "iat": 1700000000,
  "exp": 1714000000,
  "now": 1701000000,
  "token_age_seconds": 1000000,
  "exp_seconds_remaining": 13000000,
  "exp_days_remaining": 150.46,
  "message": "Token is valid"
}
```

### Step 2: Check Server Logs
When 401 errors occur, the backend logs will show:
```
[AUTH ERROR] Token decode failed: <reason>
[AUTH ERROR] Traceback: <full Python traceback>
```

### Step 3: Common 401 Causes & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `Token expired` | Token age > `JWT_EXPIRES_MINUTES` (129,600 min = 90 days) | User must log in again OR check server time sync |
| `Invalid token` | Malformed JWT or wrong secret key | Check JWT_SECRET in config matches all instances |
| `Token missing subject` | Token doesn't have "sub" claim | Regenerate token by logging in again |
| `User not found` | Database doesn't have user with id from token | Check database migrations ran successfully |
| No logs appear | Authorization header not being sent | Check frontend is calling `authHeaders(token)` |

### Step 4: Verify Frontend Token Transmission

**TypeScript (Admin Web)**:
```typescript
// Should attach header like this:
const headers = authHeaders(token);
// Headers should contain: { Authorization: "Bearer <token>" }

// Verify:
console.log(headers);
const response = await fetch(url, { headers });
```

**Flutter**:
```dart
// ApiClient should build header like this:
Map<String, String> _headers() {
  return {
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

// Token should be stored in SharedPreferences:
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('access_token');
```

## Token Architecture

### Token Creation
```
Backend: create_access_token(user_id)
├─ Timestamp: now = datetime.now(timezone.utc)
├─ Expiration: exp = now + timedelta(minutes=129600)
├─ Payload: { "sub": user_id, "iat": iat_unix, "exp": exp_unix }
└─ Encoded: JWT with HS256 signature
```

### Token Validation
```
Backend: decode_token(token)
├─ Decode & verify JWT signature
├─ Check token has "sub" claim
├─ Explicit check: now_unix > exp_unix → token expired
└─ Extract and return user_id
```

### Frontend Token Storage

**TypeScript**:
- Storage: `window.localStorage.get('admin_access_token')`
- Usage: Pass to `authHeaders(token)` for every request
- Persistence: Survives page refresh

**Flutter**:
- Storage: `SharedPreferences.getString('access_token')`
- Usage: Pass to ApiClient constructor
- Persistence: Survives app restart

## Configuration Verification

### JWT Configuration
```python
# In backend/config.py:
JWT_SECRET = os.getenv("JWT_SECRET", "your-secret-key")
JWT_ALGORITHM = "HS256"
JWT_EXPIRES_MINUTES = int(os.getenv("JWT_EXPIRES_MINUTES", "129600"))  # 90 days

# Verify: 129600 minutes = 2160 hours = 90 days ✓
```

### CORS Configuration
```python
# In backend/main.py:
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # or specific origins
    allow_credentials=True,  # required for cookies
    allow_methods=["*"],
    allow_headers=["*"],  # important: allows Authorization header
)
```

## Testing the Fix

### Admin Web Test
1. Log in to admin dashboard
2. Go to Activities page → should show email + location columns
3. Go to Dashboard → activities should show location in user info
4. Test token inspection:
   ```bash
   curl -H "Authorization: Bearer $(grep admin_access_token ~/.config/your-app | cut -d= -f2)" \
     http://localhost:8000/auth/debug/token-info
   ```

### Flutter App Test
1. Log in to mobile app
2. Perform a prediction (creates activity)
3. Activity should be logged with location
4. Close and reopen app → should still be logged in
5. Token should be valid for 90 days from login date

### Manual Token Test
```python
# In Python console:
from auth import create_access_token, decode_token, JWT_EXPIRES_MINUTES
from datetime import datetime, timezone, timedelta

# Create token
token = create_access_token("1")
print(f"Created token: {token}")

# Verify it works
user_id = decode_token(token)
print(f"Decoded user_id: {user_id}")

# Check expiration
import json
import base64
parts = token.split('.')
payload = json.loads(base64.urlsafe_b64decode(parts[1] + '=='))
exp = payload['exp']
iat = payload['iat']
now = int(datetime.now(timezone.utc).timestamp())
print(f"Expires in: {(exp - now) / 86400:.1f} days")
```

## Prevention Checklist

- [ ] JWT_EXPIRES_MINUTES correctly set to 129600 in backend/config.py
- [ ] JWT_SECRET is consistent across all backend instances
- [ ] CORS allows Authorization header (allow_headers=["*"])
- [ ] Refresh cookies are being set (if using refresh tokens)
- [ ] Admin pages pass token to every API request via authHeaders()
- [ ] Flutter app stores token in SharedPreferences after login
- [ ] Flutter app retrieves and uses token on app restart
- [ ] Server time is synchronized across all instances
- [ ] Database migrations have run (users table has all required columns)
- [ ] Activity logging receives location parameter on each call
- [ ] Error logs show [AUTH ERROR] prefix (helps with grep)

## Performance Notes

- Token validation is fast (JWT sig check only, no DB lookup until user_id extracted)
- Each request will update `last_activity_at` (minor DB write overhead)
- Debug endpoint has no performance impact when not called

## Production Recommendations

1. **Remove Debug Endpoint**: Delete `/auth/debug/token-info` before deploying
2. **Reduce Logging**: Remove print() statements from decode_token() in production
3. **Secrets Management**: Use environment variables for JWT_SECRET (never hardcode)
4. **Token Rotation**: Consider implementing refresh token rotation for extra security
5. **Rate Limiting**: Add rate limiting to auth endpoints to prevent brute force
6. **HTTPS Only**: Set COOKIE_SECURE=True in production (requires HTTPS)

## Additional Resources

- JWT Format: [jwt.io](https://jwt.io)
- Python-Jose Docs: [python-jose](https://python-jose.readthedocs.io)
- FastAPI Security: [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- React/Next.js localStorage: [MDN Web Storage](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage)
- Flutter SharedPreferences: [Flutter SharedPreferences](https://pub.dev/packages/shared_preferences)

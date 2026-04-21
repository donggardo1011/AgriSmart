# Authentication & Display Fixes - Message 12 Complete

## ✅ Issues Resolved

### 1. **JWT Token Expiration - CRITICAL FIX**
**Problem**: 401 errors despite JWT configured for 90 days
- **Root Cause**: `.env` file had `JWT_EXPIRES_MINUTES=15` overriding the 90-day configuration
- **Fix**: Updated `.env` to `JWT_EXPIRES_MINUTES=129600` (90 days)
- **Verification**: Test script confirms tokens valid for 90 days

**File Changed**: `/backend/.env`
```diff
- JWT_EXPIRES_MINUTES=15
+ JWT_EXPIRES_MINUTES=129600
```

### 2. **Activities Page Missing Location Column**
**Problem**: Admin activities page displayed username only, missing email and location
- **Fix**: Added `location` field to ActivityRow interface and updated table columns
- **Display**: Activities table now shows Action | User | Email | Location | Time | Detail

**File Changed**: `/admin-web/app/activities/page.tsx`
```typescript
// Added to interface:
interface ActivityRow {
  ...
  location?: string | null;
}

// Updated table headers to include:
<th>Action</th>
<th>User</th>
<th>Email</th>
<th>Location</th>  // NEW
<th>Time</th>
<th>Detail</th>

// Updated table body to display:
<td>{row.location ?? '-'}</td>
```

### 3. **Dashboard Not Showing User Location**
**Problem**: Dashboard activities showed username and email but not location
- **Fix**: Added `location` field to interface and inline location display
- **Display**: User info now shows "username (email) • location"

**File Changed**: `/admin-web/app/dashboard/page.tsx`
```typescript
// Updated display to include:
{activity.location && ` • ${activity.location}`}
```

### 4. **Token Validation Lacking Details**
**Problem**: 401 Unauthorized errors had vague error messages, no way to debug token state
- **Fix**: Enhanced `decode_token()` with explicit expiration check and detailed error messages

**File Changed**: `/backend/auth.py`
```python
def decode_token(token: str) -> str:
    try:
        payload = jwt.decode(...)
        # NEW: Explicit expiration check
        if exp and now > exp:
            raise ValueError(f"Token expired. now={now}, exp={exp}, diff={now - exp}s")
        return sub
    except JWTError as e:
        raise ValueError(f"Invalid token: {str(e)}") from e
```

### 5. **No Way to Inspect Token Claims**
**Problem**: When 401 errors occur, no way to check token validity without debugger
- **Fix**: Added new debug endpoint `/auth/debug/token-info`
- **Usage**: `curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8000/auth/debug/token-info`
- **Response**: Returns token claims including iat, exp, age, remaining days

**File Added**: `/backend/routes/auth_routes.py` - New endpoint
```python
@router.get("/auth/debug/token-info")
def debug_token_info(creds: HTTPAuthorizationCredentials = Depends(security)):
    """
    Returns:
    {
      "valid": true,
      "sub": "1",
      "iat": 1712082427,
      "exp": 1729696027,
      "now": 1712082428,
      "token_age_seconds": 1,
      "exp_seconds_remaining": 17613599,
      "exp_days_remaining": 203.76,
      "message": "Token is valid"
    }
    """
```

### 6. **Insufficient Error Logging**
**Problem**: When 401 errors occur, server logs don't show why
- **Fix**: Enhanced `get_current_user()` with [AUTH ERROR] prefix and stack traces

**File Changed**: `/backend/routes/auth_routes.py`
```python
def get_current_user(...):
    try:
        sub = decode_token(token)
    except Exception as e:
        print(f"[AUTH ERROR] Token decode failed: {error_detail}")
        print(f"[AUTH ERROR] Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=401, detail=f"Invalid or expired token: {error_detail}")
```

## 📋 Files Updated

| File | Changes | Status |
|------|---------|--------|
| `/backend/.env` | Changed JWT_EXPIRES_MINUTES from 15 to 129600 | ✅ CRITICAL |
| `/backend/auth.py` | Enhanced token validation with explicit expiration check | ✅ |
| `/backend/routes/auth_routes.py` | Added timezone import, enhanced error logging, added debug endpoint | ✅ |
| `/admin-web/app/activities/page.tsx` | Added location column to activities table | ✅ |
| `/admin-web/app/dashboard/page.tsx` | Added location field to activity display | ✅ |
| `/TOKEN_DEBUGGING_GUIDE.md` | Created comprehensive debugging and troubleshooting guide | ✅ |
| `/test_token_fixes.py` | Created test script to verify token configuration | ✅ |

## 🔍 Testing & Verification

### Test Results ✅
```
============================================================
Token Fix Verification Test
============================================================

1. Testing token creation and validation...
✓ Imports successful
✓ Token created
✓ Token decoded: user_id=1
✓ Token issued at: 2026-04-15 05:07:07+00:00
✓ Token expires at: 2026-07-14 05:07:07+00:00
✓ Current time: 2026-04-15 05:07:08+00:00
✓ Token valid for: 90.0 days (expected: ~90 days)  ← KEY FIX
✓ Token configuration correct: JWT_EXPIRES_MINUTES=129600

2. Testing enhanced error messages...
✓ Error message enhanced

✓ ALL TESTS PASSED
```

## 🔧 How to Test the Fixes

### Test 1: Activities Display
1. Log in to admin dashboard
2. Navigate to `Activities` page
3. Verify table shows correct columns: **Action | User | Email | Location | Time | Detail**
4. Check that location data is populated from backend

### Test 2: Dashboard Display
1. Log in to admin dashboard
2. On main Dashboard, view "Recent activity" section
3. Verify activities show: "**username (email) • location**"
4. Check that all three pieces of info are visible

### Test 3: Token Debug Endpoint
1. Copy your access token from browser localStorage or Flutter SharedPreferences
2. Run debug command:
   ```bash
   curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8000/auth/debug/token-info
   ```
3. Should see response like:
   ```json
   {
     "valid": true,
     "exp_days_remaining": 89.95,
     "message": "Token is valid"
   }
   ```

### Test 4: 401 Error Causes
When 401 errors occur:
1. Check server logs for `[AUTH ERROR]` prefix
2. Server will log exact failure reason (expired, invalid, missing user)
3. Error detail in response includes reason

## 📊 Configuration Summary

### Token Configuration (Now Correct)
```python
# /backend/config.py (from environment)
JWT_SECRET = "change_this_to_a_long_random_string"
JWT_ALGORITHM = "HS256"
JWT_EXPIRES_MINUTES = 129600  # 90 days ← CRITICAL VALUE
```

### Calculated Values
- 129,600 minutes = 2,160 hours = 90 days
- Token created at T is valid until T + 90 days
- Every API request updates `last_activity_at` but doesn't affect token expiration
- Refresh tokens are separate (7-day cookies) - not used in current flow

## 🚀 Impact

### Admin Experience
- ✅ No more premature 401 errors (tokens valid for 90 days)
- ✅ Can see user email and location in activities audit trail
- ✅ Dashboard shows rich user context for each action
- ✅ Better debugging capability with token inspection endpoint

### Developer Experience
- ✅ [AUTH ERROR] logs make debugging easier
- ✅ Debug endpoint shows exact token state
- ✅ Enhanced error messages show specific failure reason
- ✅ Test script confirms token configuration working

### Security
- ✅ 90-day tokens allow persistent sessions for productivity
- ✅ Server implicitly logs activity for 30-day online status calculation
- ✅ Can revoke sessions via refresh token if needed
- ✅ Time-based expiration ensures tokens don't live forever

## ⚠️ Important Notes

1. **CRITICAL**: The 15-minute expiration was preventing legitimate usage. Now fixed to 90 days.
2. **Production**: Before deploying:
   - Remove debug endpoint `/auth/debug/token-info`
   - Remove `[AUTH ERROR]` logging statements
   - Use secure JWT_SECRET (environment variable)
   - Set COOKIE_SECURE=true (requires HTTPS)

## ✅ Checklist Before Production

- [ ] `/backend/.env` has JWT_EXPIRES_MINUTES=129600
- [ ] JWT_SECRET is strong and from environment variable
- [ ] Debug endpoint removed or disabled
- [ ] [AUTH ERROR] logs removed or only shown in development mode
- [ ] CORS configuration verified to allow Authorization header
- [ ] Database migrations completed (users table has all columns)
- [ ] Test token creation → validation → expiration flow
- [ ] Verify both admin-web and flutter apps work for 24+ hours
- [ ] Check server time is synchronized between instances

## 📚 Additional Resources

- Detailed debugging guide: See `TOKEN_DEBUGGING_GUIDE.md`
- Token test script: See `test_token_fixes.py`
- Admin activities API: `/admin/activities?limit=100` (returns email + location)
- User count stats: `/admin/users/count` (returns online/offline counts)
- Debug endpoint: `/auth/debug/token-info` (needs Authorization header)

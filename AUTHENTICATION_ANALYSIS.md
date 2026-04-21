# Authentication Implementation Analysis - Capstone RLDD

## Executive Summary
The application has a **multi-layered authentication system** across three platforms (FastAPI Backend, Next.js Admin Web, Flutter Frontend). While the core mechanisms are in place, there are **several critical issues** and inconsistencies that need addressing.

---

## 1. BACKEND (FastAPI Python) - Authentication Implementation

### 1.1 Token Validation Flow

**Current Implementation:**
```python
# Location: backend/auth.py
def decode_token(token: str) -> str:
    """Validates JWT token and returns the subject (user_id)"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        sub = payload.get("sub")
        if not sub:
            raise ValueError("Token missing subject")
        
        # Explicit expiration check
        exp = payload.get("exp")
        now = int(datetime.now(timezone.utc).timestamp())
        if now > exp:
            raise ValueError(f"Token expired. now={now}, exp={exp}")
        
        return sub
    except JWTError as e:
        raise ValueError(f"Invalid token: {str(e)}") from e
```

**Token Specs:**
- **Algorithm**: HS256 (symmetric key)
- **Expiration**: `JWT_EXPIRES_MINUTES` (configurable in config.py)
- **Subject**: User ID (string)
- **Created**: In `/auth/login` and `/auth/refresh`

### 1.2 Authentication Dependency Injection (Route Protection)

**Main Dependency: `get_current_user()`**
```python
# Location: backend/routes/auth_routes.py (Line 65)
def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    token = creds.credentials
    try:
        sub = decode_token(token)
        user_id = int(sub)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid or expired token: {error_detail}")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    
    # Update last activity timestamp
    user.last_activity_at = datetime.utcnow()
    db.commit()
    
    return user
```

**Also Available: `get_current_user_optional()`**
- Returns `None` if no token provided (doesn't raise exception)
- Used in logout endpoint

### 1.3 Protected Routes

**Auth Routes (`/auth`):**
- ✅ `POST /auth/register` - **NOT PROTECTED** (recaptcha only)
- ✅ `POST /auth/login` - **NOT PROTECTED** (recaptcha only)
- ✅ `GET /auth/me` - **PROTECTED** (requires Bearer token)
- ✅ `POST /auth/forgot-password` - **NOT PROTECTED** (recaptcha only)
- ✅ `POST /auth/reset-password` - **NOT PROTECTED** (token-based reset)
- ✅ `POST /auth/verify-reset-otp` - **NOT PROTECTED** (OTP based)
- ✅ `POST /auth/google` - **NOT PROTECTED** (ID token verification)
- ✅ `POST /auth/refresh` - **NOT PROTECTED** (cookie-based)
- ✅ `POST /auth/logout` - **NOT FULLY PROTECTED** (uses `get_current_user_optional`)
- ✅ `POST /auth/change-password` - **PROTECTED** (requires Bearer token)
- ⚠️ `GET /auth/debug/token-info` - **PROTECTED** (debug endpoint)

**Predictions Routes (`/api/predictions`):**
- ✅ `POST /api/predictions` - **PROTECTED** (requires `current_user`)
- ✅ `GET /api/predictions` - **PROTECTED** (filters by `user_id`)
- ✅ `GET /api/predictions/{id}` - **PROTECTED** (requires `current_user`)
- ✅ `DELETE /api/predictions/{id}` - **PROTECTED** (requires `current_user`)

**Admin Routes (all require Admin role):**
- ✅ `get_admin_user()` dependency checks `current_user.role == "admin"`
- Used in: Backup, Train, Analytics, Admin Insights, Dataset Annotation routes

### 1.4 Role-Based Access Control (RBAC)

**Current Pattern: Custom Dependency Function**
```python
# Example from admin_routes.py
def get_admin_user(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user
```

**Inconsistencies Found:**
1. **Multiple implementations** - Each route file re-implements `require_admin()` or `get_admin_user()`
   - `admin_routes.py`: `get_admin_user()`
   - `admin_insights_routes.py`: `require_admin()`
   - `backup_routes.py`: `require_admin()`
   - `train_routes.py`: `require_admin()`
   - `analytics_routes.py`: `require_admin()`
   - `dataset_annotation_routes.py`: `require_admin()`

2. **No centralized RBAC** - Role checking is duplicated across multiple files

### 1.5 Refresh Token Management

**Implementation:**
- **Refresh tokens** stored in HttpOnly cookies at path `/auth`
- **Refresh token flow:**
  1. Login generates a refresh token (48-byte secure random)
  2. Token hash stored in `RefreshSession` table with expiration
  3. Raw token set in HttpOnly cookie
  4. Client can call `POST /auth/refresh` to get new access token

**Issues:**
- Refresh endpoint at `POST /auth/refresh` doesn't require authentication
- Cookie-based refresh might not work well with Flutter (which uses Bearer tokens)
- No way to refresh tokens in Flutter without explicit endpoint support

### 1.6 CORS Configuration

```python
# Location: backend/main.py (Line 256)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:3000",
        "http://10.0.2.2:8000",
        "*"  # ⚠️ CRITICAL: Allows ALL origins in development
    ],
    allow_credentials=True,  # Required for cookies
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**⚠️ SECURITY ISSUE:** `"*"` allows any origin to access the API in development

---

## 2. ADMIN WEB (Next.js) - Authentication Implementation

### 2.1 Token Storage & Retrieval

**Current Storage:**
```javascript
// Location: admin-web/app/(auth)/login/page.tsx
window.localStorage.setItem('admin_access_token', data.access_token);
```

**Issue:** 
- Tokens stored in **localStorage** (vulnerable to XSS)
- No HttpOnly cookie alternative for admin web
- Refresh cookies work but only for auto-refresh, not for manual token management

### 2.2 Login Flow

```typescript
// Location: admin-web/app/(auth)/login/page.tsx
async function handleSubmit(e: FormEvent) {
  const res = await fetch(`${getApiBaseUrl()}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      username,
      password,
      recaptcha_token: 'dev-token',
    }),
  });

  if (res.ok) {
    const data = await res.json();
    window.localStorage.setItem('admin_access_token', data.access_token);
    window.location.href = '/dashboard';  // Full page redirect
  }
}
```

### 2.3 Route Protection Mechanism

**Current Implementation in `(admin)/layout.tsx`:**

```typescript
export default function AdminLayout({ children }: { children: ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [me, setMe] = useState<MeResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (me) return;

    async function load() {
      try {
        const token = window.localStorage.getItem('admin_access_token');
        if (!token) {
          window.location.href = '/login';  // Redirect if no token
          return;
        }

        // Call /auth/me to validate token and get user data
        const data = await apiRequest<MeResponse>('/auth/me', {
          headers: authHeaders(token),
        });

        // Check admin role
        if (data.role !== 'admin') {
          setError('Access denied: admin role required.');
          return;
        }

        setMe(data);
      } catch (err) {
        // Token invalid or expired
        window.location.href = '/login';
      }
    }

    load();
  }, [me]);
```

**Critical Issues:**

1. **No automatic token refresh:**
   - If access token expires, user is redirected to login
   - Refresh token cookie exists but is NOT used by the Next.js frontend
   - **MISSING:** Auto-refresh logic using `/auth/refresh` endpoint

2. **Client-side only validation:**
   - Token validation happens in layout on every page load
   - No middleware-level protection
   - No server-side token validation

3. **Role check is client-side only:**
   - After calling `/auth/me`, checks `role !== 'admin'`
   - Could be manipulated if `/auth/me` endpoint is not properly secured (it is, but layering is poor)

4. **No protected routes at Next.js router level:**
   - All routes under `/admin` rely on layout-level checks
   - Could be bypassed if layout is removed or if routes accessed directly

### 2.4 API Request Handling

```typescript
// Location: admin-web/lib/api.ts
export function authHeaders(token: string | null | undefined): Record<string, string> {
  if (token) {
    return { Authorization: `Bearer ${token}` };
  }
  return {};
}

export async function apiRequest<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const headers: Record<string, string> = {};
  
  if (!(options.body instanceof FormData)) {
    headers['Content-Type'] = 'application/json';
  }

  const res = await fetch(`${base}${path}`, {
    ...options,
    headers: {
      ...headers,
      ...(options.headers as Record<string, string> | undefined),
    },
  });

  if (!res.ok) {
    throw new Error(`Request failed (${res.status}): ${text}`);
  }

  return (await res.json()) as T;
}
```

**Issue:** 
- No automatic 401/token-expired handling
- No retry logic with token refresh
- No centralized token expiration detection

### 2.5 Session State

**Storage Method:**
```typescript
(window as { _ADMIN_SESSION?: MeResponse })._ADMIN_SESSION = data;
```
- Stored in global window object
- Lost on page refresh (but token is retrieved from localStorage)
- Not synchronized across tabs

---

## 3. FLUTTER FRONTEND - Authentication Implementation

### 3.1 Token Storage

**Mechanism: SharedPreferences**
```dart
// Location: frontend/lib/core/storage.dart
class TokenStorage {
  static Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);  // 'access_token'
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }
}
```

**Config:**
```dart
// Location: frontend/lib/core/config.dart
const String apiBaseUrl = 'http://192.168.100.33:8000';
const String tokenKey = 'access_token';
```

**Issue:**
- **Hardcoded API URL** - Cannot change at runtime
- Token stored in SharedPreferences (device storage, not HttpOnly)

### 3.2 Login Flow

```dart
// Location: frontend/lib/screens/login_screen.dart
Future<void> _submit() async {
  try {
    final uri = Uri.parse('$apiBaseUrl/auth/login');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': _usernameController.text.trim(),
            'password': _passwordController.text,
            'recaptcha_token': 'dev-token',
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token']?.toString();
      if (token == null) throw Exception('Missing access token');
      
      await _persistRememberedLogin();
      if (mounted) {
        widget.onLoggedIn(token);
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
    }
  }
}
```

### 3.3 API Client Implementation

```dart
// Location: frontend/lib/services/api_client.dart
class ApiClient {
  final String baseUrl;
  final String? token;

  ApiClient({required this.baseUrl, this.token});

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',  // ✅ Bearer token
    };
  }

  Future<http.Response> get(String path) {
    return http
        .get(_uri(path), headers: _headers(json: false))
        .timeout(_timeout);
  }
}
```

**Good:** Properly uses Bearer token authorization

### 3.4 Session Initialization

```dart
// Location: frontend/lib/app/agrismartech_app.dart
Future<void> _loadToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(tokenKey);
  var isGuest = await OfflineActivityService.isGuestMode();
  
  // Token takes precedence over guest mode
  if (token != null && token.isNotEmpty) {
    isGuest = false;
    await OfflineActivityService.disableGuestMode();
  }
  
  setState(() {
    _accessToken = token;
    _isGuestMode = isGuest;
    _initialized = true;
  });
}
```

### 3.5 Protected Screens

**Example: Disease Detail Screen**
```dart
// Location: frontend/lib/screens/disease_detail_screen.dart
final token = prefs.getString('access_token');
// Uses token to fetch authenticated data
```

**Issue:**
- Token passed manually to every request
- No automatic token refresh mechanism
- No centralized error handling for expired tokens

---

## 4. CRITICAL ISSUES AND INCONSISTENCIES

### 4.1 Token Refresh Inconsistency

| Platform | Supports Auto-Refresh | Refresh Method | Issue |
|----------|----------------------|-----------------|-------|
| Backend | ✅ Yes | Cookie + Endpoint | N/A |
| Admin Web | ❌ No | Cookie exists but unused | **User redirected to login on token expiry** |
| Flutter | ❌ No | None | **No refresh mechanism at all** |

**Problem:** Users will be logged out when tokens expire, with no seamless refresh experience.

**Code Location - Missing Logic:**
- Admin Web: `admin-web/lib/api.ts` - No retry logic on 401
- Flutter: No centralized API middleware to detect 401 and refresh

### 4.2 Role-Based Access Control (RBAC) Issues

**Problem 1: Duplicated Role Checking**
```
admin_routes.py:           def get_admin_user()
admin_insights_routes.py:  def require_admin()
backup_routes.py:          def require_admin()
train_routes.py:           def require_admin()
analytics_routes.py:       def require_admin()
dataset_annotation_routes.py: def require_admin()
```

**Problem 2: Admin Web Role Check is Client-Side**
```typescript
// Location: admin-web/app/(admin)/layout.tsx
if (data.role !== 'admin') {
  setError('Access denied: admin role required.');
}
```
- This is after `/auth/me` call (which should validate server-side)
- But provides poor UX error message vs. being denied at backend

**Problem 3: No Centralized Role Hierarchy**
- Only "admin" and "user" roles
- No other role types defined
- No permission/scope system beyond admin/user

### 4.3 XSS Vulnerability in Admin Web

**Issue: Token Stored in localStorage**
```typescript
window.localStorage.setItem('admin_access_token', data.access_token);
```

**Risk:**
- Any XSS vulnerability in admin web can steal the token
- Should use HttpOnly cookie instead

**Solution Already Exists But Unused:**
- Backend provides refresh token in HttpOnly cookie
- Admin Web should use this for token renewal instead of storing in localStorage

### 4.4 CORS Configuration - Development vs. Production

**Current:**
```python
allow_origins=["*"]  # Allows ALL origins
```

**Issue:**
- Cross-origin requests from anywhere are allowed
- Should be restricted to specific origins in production

### 4.5 No Logout Revocation Validation

**Current Logout Implementation:**
```python
@router.post("/logout")
def logout(
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    raw = request.cookies.get("refresh_token")
    if raw:
        token_h = hash_token(raw)
        sess = db.query(RefreshSession).filter(RefreshSession.refresh_token_hash == token_h).first()
        if sess and sess.revoked_at is None:
            sess.revoked_at = datetime.utcnow()
            db.commit()
    
    clear_refresh_cookie(response)
    return {"message": "Logged out"}
```

**Issues:**
1. **Refresh token revocation is tracked, but access tokens are NOT**
   - User could use old access token after logout
   - Access tokens are valid until expiration regardless of logout

2. **Access token contains no session reference**
   - Token is just JWT with user ID and expiration
   - No way to invalidate all tokens for a user (e.g., security breach)

3. **No token blacklist/revocation list**
   - Cannot invalidate tokens before expiration

### 4.6 Flutter - No Automatic Token Validation

**Issue:**
- When Flutter app starts, it loads token from storage
- Never validates if token is still valid
- No refresh mechanism

**Code Location:** `frontend/lib/app/agrismartech_app.dart`
```dart
Future<void> _loadToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(tokenKey);
  // Just loads token, doesn't validate it!
}
```

### 4.7 Admin Web - No Middleware-Level Protection

**Current:**
- Protection happens at component level (layout.tsx)
- No Next.js middleware
- Could be bypassed by direct route access

**Missing:**
- Middleware to validate token on every request
- Server-side route protection

### 4.8 Missing Authentication Features

| Feature | Implemented | Platform |
|---------|-------------|----------|
| Token refresh (auto) | ❌ No | Admin Web, Flutter |
| Token refresh (manual) | ⚠️ Partial | Backend only |
| Token revocation/logout | ⚠️ Partial | Refresh token only |
| MFA/2FA | ❌ No | All |
| Session tracking | ❌ No | All |
| Activity logging on token use | ❌ No | All |
| Concurrent session limits | ❌ No | All |
| Device fingerprinting | ❌ No | All |
| Remember me | ✅ Yes | Login only |

### 4.9 Inconsistent Token Expiration Handling

**Android/Flutter:**
- No handling of expired tokens
- User stays logged in until they try to make a request
- Then gets an error

**Admin Web:**
- Token expires silently
- User redirected to login on any request
- No warning before logout

**Better Pattern Needed:**
- Proactive token refresh before expiration
- Warning to user before logout
- Seamless re-authentication

---

## 5. AUTHENTICATION FLOW DIAGRAMS

### Login Flow (All Platforms)
```
Client                          Backend
  |                              |
  |-- POST /auth/login --------> |
  |    (username, password)      |
  |                              | (validate credentials)
  |<---- access_token ---------- |
  |  + refresh_token (cookie)    |
  |                              |
  | Store access_token locally   |
```

### Current Access Flow
```
Client                          Backend
  |                              |
  | (Bearer: access_token) ------>|
  |    GET /api/predictions      |
  |                              | (validate token)
  |                              | (get current_user)
  |<----- response --------------|
```

### Missing: Token Refresh Flow
```
Client                          Backend
  |                              |
  | [access_token EXPIRED]       |
  | POST /auth/refresh --------->|
  | (refresh_token from cookie)  |
  |                              | (validate refresh token)
  |<---- new access_token ------|
```

---

## 6. SPECIFIC CODE SNIPPETS SHOWING ISSUES

### Issue 1: Duplicate Role Checking
**File: admin_routes.py, admin_insights_routes.py, backup_routes.py, etc.**
```python
# Duplicated in EVERY file that needs admin:
def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user
```
**Should be:** Central dependency in one file

### Issue 2: No Admin Web Token Refresh
**File: admin-web/app/(admin)/layout.tsx (Line 95)**
```typescript
// Current - only gets token once:
const token = window.localStorage.getItem('admin_access_token');
if (!token) {
  window.location.href = '/login';
  return;
}

// Missing: No logic to refresh token or handle 401 responses
```

### Issue 3: localStorage XSS Vulnerability
**File: admin-web/app/(auth)/login/page.tsx (Line 58)**
```typescript
// Vulnerable - exposes token to XSS:
window.localStorage.setItem('admin_access_token', data.access_token);

// Should be: HttpOnly cookie (already available from backend!)
```

### Issue 4: Flutter No Token Refresh
**File: frontend/lib/app/agrismartech_app.dart (Line 90)**
```dart
// Just loads token, doesn't validate:
final token = prefs.getString(tokenKey);

// Missing: 
// 1. Validation that token is still valid
// 2. Refresh mechanism
// 3. Centralized error handling
```

### Issue 5: No Centralized Admin Check
**File: Multiple route files**
```python
# This is repeated across:
# - admin_routes.py
# - admin_insights_routes.py  
# - backup_routes.py
# - train_routes.py
# - analytics_routes.py
# - dataset_annotation_routes.py

def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user
```

### Issue 6: Admin Web Role Check Is Client-Side
**File: admin-web/app/(admin)/layout.tsx (Line 115)**
```typescript
// Client-side check (not ideal):
if (data.role !== 'admin') {
  setError('Access denied: admin role required.');
  return;  // Doesn't redirect, just shows error
}

// The /auth/me endpoint on backend IS protected correctly,
// but this is redundant and gives poor UX
```

---

## 7. RECOMMENDATIONS

### High Priority
1. **Implement Token Auto-Refresh**
   - Admin Web: Add middleware to retry failed requests with refresh
   - Flutter: Implement centralized API interceptor
   - Backend: Ensure `/auth/refresh` works properly

2. **Centralize RBAC**
   - Move all `require_admin()` to single location
   - Create `@require_role()` decorator system

3. **Fix Admin Web XSS**
   - Use HttpOnly cookies for token storage
   - Implement refresh token rotation

4. **Add Token Revocation**
   - Implement token blacklist for immediate logout
   - Track access tokens, not just refresh tokens

### Medium Priority
5. **Implement Middleware/Guards**
   - Next.js: Add middleware for route protection
   - Flutter: Implement API interceptor for 401 handling

6. **Add Session Management**
   - Limit concurrent sessions per user
   - Track device/location of login

7. **Implement Logout Across Devices**
   - Revoke all tokens on security event
   - Add "logout all devices" feature

### Lower Priority
8. **Add MFA/2FA** for admin accounts
9. **Implement Permission Scopes** beyond admin/user
10. **Add Security Event Logging** for authentication

---

## 8. SUMMARY TABLE

| Aspect | Backend | Admin Web | Flutter | Status |
|--------|---------|-----------|---------|--------|
| Token Creation | ✅ | N/A | N/A | ✅ Working |
| Token Validation | ✅ | ⚠️ Client-side | ⚠️ None | ⚠️ Partial |
| Token Refresh | ✅ Endpoint | ❌ Not used | ❌ None | ❌ Broken |
| Route Protection | ✅ | ⚠️ Layout-level | ✅ Manual | ⚠️ Mixed |
| Role-Based Access | ✅ Duplicated | ⚠️ Client-side | N/A | ⚠️ Inconsistent |
| Logout | ⚠️ Partial | ⚠️ Token cleared only | ✅ Token cleared | ⚠️ No revocation |
| XSS Protection | ✅ | ❌ localStorage | ✅ | ❌ Issue |
| CORS | ⚠️ Allows * | N/A | N/A | ⚠️ Dev config |


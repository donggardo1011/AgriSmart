# Admin-Web Project Architecture Summary

## Overview
The admin-web project is a Next.js TypeScript application that provides admin dashboard and analytics for the Rice Disease Detection system. It uses Recharts for visualizations, Tailwind CSS for styling, and communicates with a FastAPI backend.

---

## 1. CURRENT DASHBOARD PAGE COMPONENTS

### Dashboard Location
- **File**: `admin-web/app/dashboard/page.tsx`
- **Route**: `/dashboard`
- **Layout**: Uses `AdminLayout` component from `(admin)/layout.tsx`

### Key Metrics Cards (4-column grid)
1. **Total Users Card**
   - Displays: Total count, Active users, Admin count
   - Source: `/admin/users/count` endpoint

2. **Dataset Images Card**
   - Displays: Total images, Split distribution (train/val/test)
   - Source: `/admin/datasets/stats` endpoint

3. **Total Scans Card**
   - Displays: Total prediction/scan count
   - Source: `/analytics/dashboard` endpoint
   - Color: Blue (#0f766e)

4. **System Status Card**
   - Displays: "Online" status badge
   - Static: "All systems operational"

### Dataset Distribution Section
- **Chart Type**: Pie chart with legend
- **Data**: Disease labels from training dataset
- **Data Source**: `DatasetStats.by_label` object
- **Colors**: Palette of 5 colors rotating through disease categories
- **Shows**: 
  - Inner donut chart visualization
  - Detailed legend showing disease names and counts

### Top Diseases Chart
- **Chart Type**: Horizontal bar chart
- **Time Interval Filter**: Daily | Weekly | Monthly
- **Data**: Popular diseases from current month
- **X-Axis**: Disease names (formatted)
- **Y-Axis**: Scan counts
- **Feature**: PDF export button (generates disease-report-{interval}-{date}.pdf)
- **Location Filter**: Dropdown to filter by user location

### Users by Location Chart
- **Chart Type**: Pie chart
- **Data**: User distribution across geographic locations
- **Interactive**: Location filter dropdown to filter diseases by selected location
- **Data Source**: `AnalyticsDashboard.locations_count` dictionary

### Latest Disease Scans Table
- **Pagination**: 5 scans per page
- **Columns**: Disease, Confidence, Timestamp, Username, Location
- **Time Format**: Philippine timezone (Asia/Manila)
- **Data Source**: `AnalyticsDashboard.latest_diseases` array
- **Shows**: Most recent 10 predictions by default

### Data Loading
```typescript
// Three parallel API calls
const [userCounts, datasetStats, analytics] = await Promise.all([
  apiRequest<UserCounts>('/admin/users/count', { headers: authHeaders(token) }),
  apiRequest<DatasetStats>('/admin/datasets/stats', { headers: authHeaders(token) }),
  apiRequest<AnalyticsDashboard>('/analytics/dashboard', { headers: authHeaders(token) }),
]);
```

---

## 2. STRUCTURE OF PAGES IN (ADMIN) FOLDER

### Admin Layout Location
- **File**: `admin-web/app/(admin)/layout.tsx`
- **Type**: Client component with authentication check
- **Purpose**: Provides sidebar navigation and authentication wrapping

### Navigation Structure
```
AdminLayout
├── Sidebar (responsive - hidden on mobile)
├── Main Content Area
└── Children Routes
```

### Navigation Items (Regular Users)
1. **Dashboard** → `/dashboard` (Dashboard icon)
2. **Datasets** → `/datasets` (Database icon)
3. **Models** → `/models` (Robot icon)
4. **Chatbot** → `/chatbot` (Comments icon)
5. **Backup** → `/backup` (Cloud Download icon)
6. **Settings** → `/settings` (Cog icon)

### Admin-Only Items
1. **Users** → `/users` (Users icon)
2. **Activities** → `/activities` (Clipboard icon)
3. **Analytics** → `/analytics` (Chart Line icon)

### Layout Features
- Token-based authentication check (`admin_access_token` from localStorage)
- Responsive design (desktop/mobile detection)
- User session caching in window object (`_ADMIN_SESSION`)
- Active route highlighting
- FontAwesome icons for all menu items

### Top-Level Routes (sibling to (admin))
- `dashboard/` - Dashboard page
- `analytics/` - Analytics page
- `activities/` - Activities log page
- `datasets/` - Dataset management
- `models/` - Model management
- `users/` - User management
- `train/` - Model training
- `chatbot/` - Chatbot management
- `settings/` - Settings page
- `backup/` - Backup management

---

## 3. DATABASE SCHEMA & API ENDPOINTS

### Database Setup
- **Type**: SQLite (users.db)
- **ORM**: SQLAlchemy
- **Base URL**: `./users.db` (local development)

### Core Database Models

#### Users Table
```python
class User(Base):
    __tablename__ = "users"
    
    id: int (PK)
    username: str (unique, indexed)
    email: str (unique, indexed)
    location: str | None  # Province/city/region
    role: str  # "user" | "admin"
    password: str | None  # Nullable for OAuth users
    google_sub: str | None  # Google OAuth ID
    is_active: bool (default=True)
    last_activity_at: datetime | None  # For online status
    created_at: datetime
    reset_token_hash: str | None
    reset_token_expires_at: datetime | None
```

#### Predictions Table (Scans/Disease Detection Results)
```python
class Prediction(Base):
    __tablename__ = "predictions"
    
    id: int (PK)
    user_id: int (FK → users.id)
    image_filename: str
    image_url: str
    label: str  # Disease key (e.g., "bacterial_blight")
    confidence: float
    advice: str
    detections: str | None  # JSON string of detection boxes
    created_at: datetime
```

#### Diseases Table (Disease Definitions)
```python
class Disease(Base):
    __tablename__ = "diseases"
    
    id: int (PK)
    key: str (unique, indexed)  # "bacterial_blight", "brown_spot", etc.
    display_name: str
    causal_agent: str | None
    severity: str  # "High" | "Moderate"
    urgency: str
    explanation: str
    symptoms_summary_en: str
    prevention_summary_en: str
    treatment_summary_en: str
    image_url: str | None
    symptoms: str  # JSON
    causes: str  # JSON
    prevention: str  # JSON
    treatment_plan: str  # JSON
    fertilizer_guidance: str  # JSON
    next_steps: str  # JSON
    when_to_contact: str  # JSON
    is_active: bool
```

#### Activity Logs Table
```python
class ActivityLog(Base):
    __tablename__ = "activity_logs"
    
    id: int (PK)
    user_id: int | None (FK → users.id)
    action: str
    detail: str | None  # JSON details
    location: str | None
    created_at: datetime
```

#### Dataset Items Table (Training Dataset Images)
```python
class DatasetItem(Base):
    __tablename__ = "dataset_items"
    
    id: int (PK)
    image_filename: str
    image_url: str
    label: str (indexed)  # Disease key
    split: str  # "train" | "val" | "test"
    uploaded_by_user_id: int | None (FK → users.id)
    created_at: datetime (indexed)
```

#### Refresh Sessions Table (Auth)
```python
class RefreshSession(Base):
    __tablename__ = "refresh_sessions"
    
    id: int (PK)
    user_id: int (FK → users.id)
    refresh_token_hash: str (unique, indexed)
    expires_at: datetime
    revoked_at: datetime | None
    created_at: datetime
```

---

## 4. API ENDPOINTS

### Authentication
- **POST** `/auth/login` - Login with username/password
- **POST** `/auth/google-login` - Login with Google OAuth token
- **POST** `/auth/register` - Register new user account
- **POST** `/auth/refresh` - Refresh access token
- **POST** `/auth/forgot-password` - Request password reset
- **POST** `/auth/reset-password` - Reset password with token

### Admin User Management (`/admin` prefix)
#### User Count Endpoint
```
GET /admin/users/count
Response: {
  "total": int,
  "active": int,
  "admins": int
}
```

#### List Users
```
GET /admin/users?q=search&limit=50&offset=0
Response: AdminUserOut[] {
  id, username, email, location, role, is_active,
  last_activity_at, status (online|offline), created_at
}
```

#### Change User Role
```
POST /admin/users/{user_id}/role
Params: role: "admin" | "user"
```

### Admin Activities Endpoint
```
GET /admin/activities?user_id=&action=&limit=100&offset=0
Response: ActivityLogOut[] {
  id, user_id, username, email, location, action, detail, created_at
}
```

### Admin Dataset Management (`/admin` prefix)
#### Dataset Statistics
```
GET /admin/datasets/stats
Response: {
  "total": int,
  "by_label": {
    "bacterial_blight": int,
    "brown_spot": int,
    "leaf_blast": int,
    "sheath_blight": int,
    "tungro": int
  },
  "by_split": {
    "train": int,
    "val": int,
    "test": int
  }
}
```

#### List Datasets
```
GET /admin/datasets?q=search&label=&split=&limit=50&offset=0
Response: DatasetItemOut[] {
  id, label, split, image_url, created_at
}
```

#### Upload Dataset Item
```
POST /admin/datasets/upload
Body: FormData with file + label + split
Response: DatasetItemOut
```

#### Delete Dataset Item
```
DELETE /admin/datasets/{item_id}
```

### Analytics Endpoints (`/analytics` prefix)
#### Dashboard Analytics
```
GET /analytics/dashboard
Response: AnalyticsDashboardOut {
  total_users: int,
  active_users: int,
  total_admins: int,
  total_scans: int,
  latest_diseases: [
    {
      disease: string,
      confidence: float,
      timestamp: ISO datetime,
      username: string,
      location: string
    }
  ],
  popular_diseases: [
    {
      disease_key: string,
      disease_name: string,
      scan_count: int,
      rank: int,
      location: string | null
    }
  ],
  locations_count: {
    "location_name": int,
    ...
  }
}
```

#### Monthly Disease Ranking
```
GET /analytics/diseases/monthly-ranking?year=2026&month=4&location=
Response: MonthlyDiseaseRankingOut[] {
  year, month,
  rankings: DiseaseRankingOut[]
}
```

---

## 5. DATA STRUCTURES & SCHEMAS

### TypeScript Interfaces (Frontend)

#### Dashboard Request Data
```typescript
interface UserCounts {
  total: number;
  active: number;
  admins: number;
}

interface DatasetStats {
  total: number;
  by_label: Record<string, number>;  // disease key → count
  by_split: Record<string, number>;  // "train"|"val"|"test" → count
}

interface AnalyticsDashboard {
  total_users: number;
  active_users: number;
  total_admins: number;
  total_scans: number;
  latest_diseases: LatestDisease[];
  popular_diseases: DiseaseRanking[];
  locations_count: Record<string, number>;  // location → user count
}

interface DiseaseRanking {
  disease_key: string;
  disease_name: string;
  scan_count: number;
  rank: number;
  location?: string;
}

interface LatestDisease {
  disease: string;
  confidence: number;
  timestamp: string;  // ISO datetime
  username: string;
  location?: string;
}

interface AdminUserOut {
  id: number;
  username: string;
  email: string;
  location?: string;
  role: string;
  is_active?: boolean;
  last_activity_at?: datetime;
  status: "online" | "offline";  // Computed from last_activity_at
  created_at?: datetime;
}

interface ActivityLogOut {
  id: number;
  user_id?: number;
  username?: string;
  email?: string;
  location?: string;
  action: string;
  detail?: string;  // JSON
  created_at: datetime;
}
```

### Online Status Computation
```typescript
// User is "online" if last_activity_at >= (now - 30 minutes)
function is_user_online(last_activity_at: datetime | null): bool {
  if (last_activity_at is null) return false;
  cutoff = utcnow() - 30 minutes
  return last_activity_at >= cutoff;
}
```

### Disease Categories & Colors
```typescript
const diseaseColors = {
  bacterial_blight: '#ef4444',    // Red
  brown_spot: '#f97316',          // Orange
  leaf_blast: '#eab308',          // Yellow
  sheath_blight: '#22c55e',       // Green
  tungro: '#3b82f6',              // Blue
};

// Display names
const formatLabel = {
  "bacterial_blight": "Bacterial Blight",
  "brown_spot": "Brown Spot",
  "leaf_blast": "Leaf Blast",
  "sheath_blight": "Sheath Blight",
  "tungro": "Tungro"
};
```

---

## 6. KEY API FUNCTIONS (Frontend)

### Base API Request
```typescript
// lib/api.ts
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8000';

export async function apiRequest<T>(
  path: string,
  options: RequestInit = {}
): Promise<T>

export function authHeaders(token: string | null): Record<string, string> {
  return token ? { Authorization: `Bearer ${token}` } : {};
}
```

### Usage Pattern
```typescript
const token = window.localStorage.getItem('admin_access_token');
const analytics = await apiRequest<AnalyticsDashboard>(
  '/analytics/dashboard',
  { headers: authHeaders(token) }
);
```

---

## 7. ANALYTICS PAGE STRUCTURE

### File
- `admin-web/app/analytics/page.tsx`

### Fetches Same Data
- Uses same `/analytics/dashboard` endpoint as dashboard page
- Displays extended analytics views

### Additional Visualization Components
- May include historical trends
- Detailed disease rankings
- Report generation interface

---

## 8. CURRENT DASHBOARD FEATURES

### State Management
- React hooks: `useState`, `useEffect`, `useRef`
- Loading states for each API call
- Error handling with retry functionality
- Pagination for latest scans (5 per page)

### Filters
- Time interval selector: Daily | Weekly | Monthly
- Location filter: Dropdown to select geography
- Pagination controls

### Export Features
- PDF export of disease reports using:
  - `jsPDF` library
  - `html2canvas` for canvas rendering
  - Filename format: `disease-report-{interval}-{date}.pdf`

### Styling
- Tailwind CSS utility classes
- Color palette with 5 distinct colors
- Responsive grid layouts (md:grid-cols-4, lg:grid-cols-2)
- Card-based component design
- Custom status badges (green "Online", etc.)

### Time Zone Handling
```typescript
// Philippine timezone (Asia/Manila = UTC+8)
function formatPHTime(dateString: string): string {
  // Converts UTC ISO string to PH local time
  // Format: MM/DD/YYYY HH:MM:SS AM/PM
}
```

---

## 9. AUTHENTICATION FLOW

1. User logs in to `/login` (auth route)
2. Backend returns JWT access token
3. Token stored in `localStorage.admin_access_token`
4. Sent in Authorization header for protected endpoints
5. Admin status checked via `role == "admin"` from user model

---

## 10. KEY COMPONENTS ARCHITECTURE

```
AdminLayout (auth wrapper + sidebar navigation)
├── /dashboard
│   ├── Key Metrics (4 cards)
│   ├── Dataset Distribution (pie chart)
│   ├── Top Diseases (bar chart + PDF export)
│   ├── Users by Location (pie chart)
│   └── Latest Scans (paginated table)
├── /analytics
│   └── Comprehensive analytics views
├── /activities
│   ├── Activity log table
│   ├── Filters (user, action)
│   └── PDF export
├── /users
│   └── User management interface
├── /datasets
│   ├── Dataset upload
│   ├── Dataset management
│   └── Statistics view
└── /models
    └── Model management interface
```

---

## Summary Statistics

| Component | Count |
|-----------|-------|
| Database Tables | 6 |
| API Endpoints | 12+ |
| Dashboard Cards | 4 |
| Charts/Visualizations | 3 |
| Core Disease Categories | 5 |
| Navigation Items | 9 |
| API Response Models | 8+ |

---

## Tech Stack

**Frontend (admin-web)**
- Framework: Next.js 14 (TypeScript)
- Styling: Tailwind CSS
- Charts: Recharts
- Icons: FontAwesome
- Export: jsPDF, html2canvas

**Backend**
- Framework: FastAPI (Python)
- Database: SQLite with SQLAlchemy
- Authentication: JWT with HttpOnly cookies
- Validation: Pydantic schemas

**Deployment**
- Frontend: Next.js Server Components
- Backend: Uvicorn ASGI server
- Static Files: Served from `/uploads` and `/dataset/` routes

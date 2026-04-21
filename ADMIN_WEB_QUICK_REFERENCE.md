# Admin-Web Quick Reference Guide

## Quick Dashboard Overview

### What It Shows
- **4 Key Metrics**: Total Users, Dataset Images, Total Scans, System Status
- **3 Charts**: Dataset distribution pie, Top diseases bar, Users by location pie
- **1 Table**: Latest 10 disease scans with pagination

### API Calls Used (Dashboard Page)
```
GET /admin/users/count
GET /admin/datasets/stats
GET /analytics/dashboard
```

### File Locations
- **Dashboard**: `admin-web/app/dashboard/page.tsx`
- **Analytics Page**: `admin-web/app/analytics/page.tsx`
- **Activities Page**: `admin-web/app/activities/page.tsx`
- **Admin Layout**: `admin-web/app/(admin)/layout.tsx`
- **API Client**: `admin-web/lib/api.ts`

---

## Core Database Tables (6 total)

| Table | Purpose | Key Fields |
|-------|---------|-----------|
| `users` | User accounts | id, username, email, location, role, is_active, last_activity_at |
| `predictions` | Disease detection results | id, user_id, label, confidence, image_url, created_at |
| `diseases` | Disease definitions | id, key, display_name, severity, symptoms, prevention, treatment |
| `activity_logs` | User actions log | id, user_id, action, detail, location, created_at |
| `dataset_items` | Training images | id, label, split, image_url, uploaded_by_user_id |
| `refresh_sessions` | Auth tokens | id, user_id, refresh_token_hash, expires_at |

---

## 5 Tracked Rice Diseases

| Disease | Key | Severity | Color |
|---------|-----|----------|-------|
| Bacterial Blight | `bacterial_blight` | High | Red (#ef4444) |
| Brown Spot | `brown_spot` | Moderate | Orange (#f97316) |
| Leaf Blast | `leaf_blast` | High | Yellow (#eab308) |
| Sheath Blight | `sheath_blight` | Moderate | Green (#22c55e) |
| Tungro | `tungro` | High | Blue (#3b82f6) |

---

## API Endpoints Reference

### Dashboard Data
```
GET /admin/users/count
Response: { "total": 45, "active": 38, "admins": 3 }

GET /admin/datasets/stats
Response: {
  "total": 2000,
  "by_label": { "bacterial_blight": 200, ... },
  "by_split": { "train": 1600, "val": 200, "test": 200 }
}

GET /analytics/dashboard
Response: {
  "total_users": 45,
  "active_users": 38,
  "total_admins": 3,
  "total_scans": 1245,
  "latest_diseases": [...10 most recent scans...],
  "popular_diseases": [...top 10 this month...],
  "locations_count": { "Nueva Ecija": 12, ... }
}
```

### User Management
```
GET /admin/users?q=search&limit=50&offset=0
Response: AdminUserOut[]

POST /admin/users/{user_id}/role
Body: { "role": "admin" | "user" }

GET /admin/activities?limit=100&offset=0
Response: ActivityLogOut[]
```

### Dataset Management
```
GET /admin/datasets?limit=50&offset=0
Response: DatasetItemOut[]

POST /admin/datasets/upload
Body: FormData(file, label, split)
Response: DatasetItemOut

DELETE /admin/datasets/{item_id}
```

### Analytics
```
GET /analytics/diseases/monthly-ranking?year=2026&month=4&location=
Response: MonthlyDiseaseRankingOut[]
```

---

## Dashboard State Variables

```typescript
// Data from APIs
userCounts: UserCounts | null
datasetStats: DatasetStats | null
analytics: AnalyticsDashboard | null

// UI State
diseaseInterval: 'daily' | 'weekly' | 'monthly'
selectedLocation: string | null
scansPage: number
scansPerPage: number (= 5)
loading: boolean
error: string | null
```

---

## Admin Navigation Menu

```
Dashboard          → /dashboard
├── Datasets       → /datasets
├── Models         → /models
├── Chatbot        → /chatbot
├── Backup         → /backup
└── Settings       → /settings

Admin Only:
├── Users          → /users
├── Activities     → /activities
└── Analytics      → /analytics
```

---

## Authentication

- **Token Storage**: `localStorage.admin_access_token`
- **Auth Header**: `Authorization: Bearer {token}`
- **Session Cache**: `window._ADMIN_SESSION` (optional, for perf)
- **Online Status**: User is online if `last_activity_at >= (now - 30 min)`

---

## Data Filters & Pagination

### Dashboard Filters
- **Time Interval**: Daily | Weekly | Monthly (for top diseases chart)
- **Location**: Dropdown to filter by user location
- **Pagination**: 5 scans per page (latest diseases table)

### Sorting
- Users: By creation date (desc)
- Activities: By creation date (desc)
- Datasets: By creation date (desc)
- Diseases: By scan count (desc)

---

## Export Features

### PDF Export
- **Disease Report**: Downloads disease rankings chart as PDF
  - Filename: `disease-report-{interval}-{date}.pdf`
  - Uses: `jsPDF` + `html2canvas`
  
- **Activities Report**: Downloads activity table as PDF
  - Filename: Auto-generated with timestamp
  - Format: Landscape A4 with pagination support

---

## Status Indicators

### User Status
- **Online**: Last activity within 30 minutes
- **Offline**: Last activity > 30 minutes ago
- **Computed**: `is_user_online(last_activity_at)` function

### System Status
- **Displays**: "Online" with green badge
- **Static**: Not real-time monitoring

---

## Time Zone Handling

- **Timezone**: Asia/Manila (UTC+8)
- **Format**: MM/DD/YYYY HH:MM:SS AM/PM
- **Storage**: UTC in database
- **Display**: Converted to PH timezone client-side

---

## Styling System

### Color Palette
```css
Primary: Emerald/Teal (#0f766e)
Secondary: Slate (#1f2937)
Accent: Light Blue (#3b82f6)
Success: Green (#22c55e)
Warning: Amber (#f59e0b)
Error: Red (#ef4444)
```

### Responsive Breakpoints
- `md:` - Medium screens (2 cols)
- `lg:` - Large screens (4 cols)
- `max-w-[1600px]` - Max width container

### Components
- `card` - Main content box (border, padding, shadows)
- `btn-primary` - Primary button
- `btn-secondary` - Secondary button (Refresh)

---

## Common Query Patterns

### Get Analytics for Month X
```
GET /analytics/diseases/monthly-ranking?year=2026&month=4
```

### Search Users
```
GET /admin/users?q=username_or_email&limit=50
```

### Filter Activities by User
```
GET /admin/activities?user_id=123&limit=100
```

### Get Datasets by Disease
```
GET /admin/datasets?label=brown_spot&limit=50
```

---

## Backend Architecture

- **Framework**: FastAPI (Python)
- **Database**: SQLite (`users.db`)
- **ORM**: SQLAlchemy
- **Authentication**: JWT tokens + HttpOnly refresh cookies
- **Validation**: Pydantic schemas

---

## Frontend Stack

- **Framework**: Next.js 14 (TypeScript)
- **Styling**: Tailwind CSS
- **Charts**: Recharts library
- **Icons**: FontAwesome
- **Export**: jsPDF + html2canvas

---

## Response Models (Pydantic Schemas)

### UserCounts
```python
{ "total": int, "active": int, "admins": int }
```

### DatasetStats
```python
{ 
  "total": int, 
  "by_label": dict[str, int],
  "by_split": dict[str, int]
}
```

### AnalyticsDashboard
```python
{
  "total_users": int,
  "active_users": int,
  "total_admins": int,
  "total_scans": int,
  "latest_diseases": list[LatestDisease],
  "popular_diseases": list[DiseaseRanking],
  "locations_count": dict[str, int]
}
```

### AdminUserOut
```python
{
  "id": int,
  "username": str,
  "email": str,
  "location": str | None,
  "role": str,
  "is_active": bool,
  "last_activity_at": datetime | None,
  "status": "online" | "offline",
  "created_at": datetime
}
```

### ActivityLogOut
```python
{
  "id": int,
  "user_id": int | None,
  "username": str | None,
  "email": str | None,
  "location": str | None,
  "action": str,
  "detail": str | None,  # JSON string
  "created_at": datetime
}
```

---

## Troubleshooting Checklist

- [ ] Token stored in localStorage?
- [ ] API base URL correct? (env: `NEXT_PUBLIC_API_BASE_URL`)
- [ ] User role is "admin"?
- [ ] Database migration complete? (columns: role, location, last_activity_at)
- [ ] Diseases seeded in database?
- [ ] CORS enabled on backend?
- [ ] Backend running on port 8000?

---

## Key Metrics Calculation

```
Total Users = COUNT(users)
Active Users = COUNT(users WHERE is_active = true)
Admin Count = COUNT(users WHERE role = 'admin')

Total Scans = COUNT(predictions)

Latest Diseases = 
  SELECT TOP 10 FROM predictions
  ORDER BY created_at DESC
  JOIN users ON predictions.user_id = users.id

Popular Diseases (This Month) = 
  SELECT disease, COUNT(*) AS scan_count
  FROM predictions
  WHERE YEAR(created_at) = YEAR(NOW())
    AND MONTH(created_at) = MONTH(NOW())
  GROUP BY disease
  ORDER BY scan_count DESC
  LIMIT 10

Locations Count = 
  SELECT location, COUNT(*) AS user_count
  FROM users
  WHERE location IS NOT NULL
  GROUP BY location
```

---

## Development Tips

1. **Local Testing**
   ```bash
   # Backend: python main.py (runs on :8000)
   # Frontend: npm run dev (runs on :3000)
   ```

2. **Check Logs**
   - Backend: FastAPI logs in terminal
   - Frontend: Browser console (F12)
   - Database: `sqlite3 users.db`

3. **Common Issues**
   - CORS errors: Check backend CORS settings
   - Auth failures: Verify token in localStorage
   - Empty charts: Check database has data
   - Timezone issues: Verify client timezone setting

4. **Performance**
   - Dashboard loads 3 API calls in parallel
   - Query optimization needed for `popular_diseases` calculation
   - Consider caching analytics data (e.g., Redis)

---

## Version Info

- **Last Updated**: April 2026
- **Next.js**: 14.x (TypeScript)
- **Python**: 3.9+
- **SQLAlchemy**: 2.x
- **FastAPI**: 0.100+
- **Recharts**: 2.x

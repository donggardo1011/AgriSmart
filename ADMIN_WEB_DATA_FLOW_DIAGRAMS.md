# Admin-Web Data Flow & Architecture Diagrams

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Admin Dashboard Page                          │
│                      (admin-web/app/dashboard/page.tsx)                 │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
        ┌───────────▼────────────┐     │      ┌────────────▼─────────────┐
        │ GET /admin/users/count │     │      │ GET /admin/datasets/stats │
        │ (User Counts)          │     │      │ (Dataset Stats)           │
        └───────────┬────────────┘     │      └────────────┬──────────────┘
                    │                  │                   │
        ┌─────────────────────────┐    │    ┌─────────────────────────┐
        │ UserCounts {            │    │    │ DatasetStats {          │
        │   total: 45             │    │    │   total: 2000           │
        │   active: 38            │    │    │   by_label: {           │
        │   admins: 3             │    │    │     bacterial_blight:200│
        │ }                       │    │    │     brown_spot: 350     │
        └─────────────────────────┘    │    │     leaf_blast: 500     │
                    │                  │    │     sheath_blight:600   │
                    │  ┌───────────────▼────▼──┐ tungro: 350}        │
                    │  │    Key Metrics Cards    │ by_split: {        │
                    │  │ (4-column grid)         │   train: 1600      │
                    │  │ ├─Total Users           │   val: 200         │
                    │  │ ├─Dataset Images        │   test: 200        │
                    │  │ ├─Total Scans           │ }                  │
                    │  │ └─System Status         │ }                  │
                    └──┤                         └────────────────────┘
                       │
        ┌──────────────▼───────────────────────────────────────┐
        │ GET /analytics/dashboard (Main Analytics)            │
        │                                                       │
        │ Response: AnalyticsDashboardOut {                    │
        │   total_users: 45                                    │
        │   active_users: 38                                   │
        │   total_admins: 3                                    │
        │   total_scans: 1245                                  │
        │   latest_diseases: [                                 │
        │     {                                                │
        │       disease: "leaf_blast",                         │
        │       confidence: 0.94,                              │
        │       timestamp: "2024-04-16T10:23:45Z",             │
        │       username: "farmer_juan",                       │
        │       location: "Nueva Ecija"                        │
        │     },                                               │
        │     ... (10 most recent)                             │
        │   ],                                                 │
        │   popular_diseases: [                                │
        │     {                                                │
        │       disease_key: "brown_spot",                     │
        │       disease_name: "Brown Spot",                    │
        │       scan_count: 342,                               │
        │       rank: 1,                                       │
        │       location: null                                 │
        │     },                                               │
        │     ... (top 10 for current month)                   │
        │   ],                                                 │
        │   locations_count: {                                 │
        │     "Nueva Ecija": 12,                               │
        │     "Laguna": 8,                                     │
        │     "Quezon": 15,                                    │
        │     ... (all user locations)                         │
        │   }                                                  │
        │ }                                                    │
        └──────┬──────────────────────────────────────────────┘
               │
        ┌──────┴──────────────────────────────────────────┐
        │                                                 │
        │         Render Dashboard Visualizations         │
        │                                                 │
        ├─────────────────────────────────────────────────┤
        │                                                 │
        │  [Chart] Dataset Distribution (Pie)              │
        │  ├─ Data: DatasetStats.by_label                │
        │  ├─ Shows disease counts in training data       │
        │  └─ 5-color palette                             │
        │                                                 │
        │  [Chart] Top Diseases (Bar)                      │
        │  ├─ Data: AnalyticsDashboard.popular_diseases  │
        │  ├─ Filter: Time interval + Location           │
        │  ├─ Export: PDF report generation              │
        │  └─ X-axis: Disease names, Y-axis: Scan count │
        │                                                 │
        │  [Chart] Users by Location (Pie)                │
        │  ├─ Data: AnalyticsDashboard.locations_count   │
        │  └─ Filter: Select location                    │
        │                                                 │
        │  [Table] Latest Disease Scans (Paginated)       │
        │  ├─ Data: AnalyticsDashboard.latest_diseases   │
        │  ├─ 5 rows per page                            │
        │  └─ Columns: Disease, Confidence, Time, User   │
        │                                                 │
        └─────────────────────────────────────────────────┘
```

---

## Database Relationship Diagram

```
┌──────────────────┐
│     Users        │
├──────────────────┤
│ id (PK)          │
│ username         │
│ email            │
│ location         │◄─────────┐
│ role             │          │
│ is_active        │          │
│ last_activity_at │          │
│ created_at       │          │
│ google_sub       │          │
│ password         │          │
└────────┬─────────┘          │
         │                    │
         │ (1:N)              │
         │                    │
    ┌────▼──────────────────┐ │
    │   Predictions         │ │
    │  (Disease Scans)      │ │
    ├───────────────────────┤ │
    │ id (PK)               │ │
    │ user_id (FK)──────────┘ │
    │ image_filename        │  │
    │ image_url             │  │
    │ label ────────────┐   │  │
    │ confidence       │   │  │
    │ advice           │   │  │
    │ detections       │   │  │
    │ created_at       │   │  │
    └──────────────────┘   │  │
                           │  │
    ┌──────────────────────┘  │
    │                         │
    │  ┌──────────────────┐   │
    │  │    Diseases      │   │
    │  ├──────────────────┤   │
    │  │ id (PK)          │   │
    │  │ key (unique)◄────┴───┘
    │  │ display_name     │
    │  │ causal_agent     │
    │  │ severity         │
    │  │ urgency          │
    │  │ explanation      │
    │  │ symptoms_summary │
    │  │ prevention_*     │
    │  │ treatment_*      │
    │  │ symptoms (JSON)  │
    │  │ causes (JSON)    │
    │  │ prevention (JSON)│
    │  │ treatment (JSON) │
    │  │ fertilizer (JSON)│
    │  │ next_steps (JSON)│
    │  │ when_to_contact  │
    │  │ image_url        │
    │  │ is_active        │
    │  └──────────────────┘
         │
         │ (referenced by)
         │
    ┌────▼──────────────────┐
    │  DatasetItems         │
    │  (Training Images)    │
    ├───────────────────────┤
    │ id (PK)               │
    │ image_filename        │
    │ image_url             │
    │ label ────────────────┼────► Foreign key to Diseases.key
    │ split                 │      ("train"|"val"|"test")
    │ uploaded_by_user_id   │
    │ created_at            │
    └───────────────────────┘
              │
              │ (1:N)
              │
    ┌─────────▼──────────────────┐
    │  DatasetAnnotations        │
    │  (YOLO Bounding Boxes)     │
    ├────────────────────────────┤
    │ id (PK)                    │
    │ dataset_item_id (FK)       │
    │ class_key                  │
    │ x_center, y_center         │
    │ width, height              │
    │ created_at                 │
    └────────────────────────────┘

    ┌──────────────────────┐
    │  ActivityLogs        │
    ├──────────────────────┤
    │ id (PK)              │
    │ user_id (FK) ─────┐  │
    │ action               │  │
    │ detail (JSON)        │  │
    │ location             │  │
    │ created_at           │  │
    └──────────────────────┘  │
                              │
              ┌───────────────┘
              │
    ┌─────────▼──────────────┐
    │  RefreshSessions       │
    │  (Auth Tokens)         │
    ├────────────────────────┤
    │ id (PK)                │
    │ user_id (FK)           │
    │ refresh_token_hash     │
    │ expires_at             │
    │ revoked_at             │
    │ created_at             │
    └────────────────────────┘
```

---

## Component Hierarchy

```
AdminLayout (Wrapper with Auth & Sidebar)
│
├── /dashboard
│   ├── useEffect → Load 3 API calls in parallel
│   │   ├── GET /admin/users/count
│   │   ├── GET /admin/datasets/stats
│   │   └── GET /analytics/dashboard
│   │
│   ├── useState for:
│   │   ├── userCounts: UserCounts | null
│   │   ├── datasetStats: DatasetStats | null
│   │   ├── analytics: AnalyticsDashboard | null
│   │   ├── diseaseInterval: TimeInterval
│   │   ├── selectedLocation: string | null
│   │   ├── scansPage: number
│   │   ├── loading: boolean
│   │   └── error: string | null
│   │
│   └── Render:
│       ├── Header (Refresh button)
│       ├── KeyMetrics (4 cards)
│       │   ├── Card: Total Users
│       │   ├── Card: Dataset Images (with split breakdown)
│       │   ├── Card: Total Scans
│       │   └── Card: System Status
│       ├── DatasetDistribution
│       │   ├── PieChart (from Recharts)
│       │   └── Legend items
│       ├── Charts Grid (2 columns)
│       │   ├── Column 1: Top Diseases
│       │   │   ├── Dropdown: Time interval selector
│       │   │   ├── BarChart visualization
│       │   │   └── Button: Download PDF
│       │   └── Column 2: Users by Location
│       │       ├── Dropdown: Location filter
│       │       └── PieChart visualization
│       └── Latest Scans
│           ├── Table headers
│           ├── Paginated rows (5 per page)
│           └── Pagination controls
│
├── /analytics
│   ├── Similar structure to dashboard
│   └── Extended analytics views
│
├── /activities
│   ├── GET /admin/activities?limit=100
│   ├── Render ActivityLogOut[] table
│   ├── Columns: ID, User, Email, Location, Action, Detail, Time
│   ├── Filter controls
│   └── PDF export
│
├── /users
│   ├── GET /admin/users?limit=50
│   ├── Display AdminUserOut[] with status
│   ├── Search functionality
│   └── Role management
│
├── /datasets
│   ├── GET /admin/datasets
│   ├── GET /admin/datasets/stats
│   ├── Upload interface
│   ├── Delete functionality
│   └── Statistics display
│
├── /models
│   └── Model management interface
│
├── /train
│   └── Training interface
│
├── /chatbot
│   └── Chatbot configuration
│
├── /settings
│   └── Settings interface
│
└── /backup
    └── Backup management
```

---

## API Endpoint Groups

```
AUTHENTICATION
├── POST /auth/login
├── POST /auth/google-login
├── POST /auth/register
├── POST /auth/refresh
├── POST /auth/forgot-password
└── POST /auth/reset-password

ADMIN - USERS (/admin prefix)
├── GET /admin/users/count → { total, active, admins }
├── GET /admin/users → AdminUserOut[]
├── POST /admin/users/{id}/role
└── GET /admin/activities → ActivityLogOut[]

ADMIN - DATASETS (/admin prefix)
├── GET /admin/datasets/stats → { total, by_label, by_split }
├── GET /admin/datasets → DatasetItemOut[]
├── POST /admin/datasets/upload → DatasetItemOut
└── DELETE /admin/datasets/{id}

ANALYTICS
├── GET /analytics/dashboard → AnalyticsDashboardOut
└── GET /analytics/diseases/monthly-ranking → MonthlyDiseaseRankingOut[]

PREDICTION
├── POST /prediction/predict → PredictionOut[]
└── GET /prediction/history → PredictionOut[]

DISEASE
├── GET /disease/list → Disease[]
└── GET /disease/{key} → Disease

MODEL
├── GET /model/active → ModelVersionOut
├── GET /model/versions → ModelVersionOut[]
├── POST /model/upload
└── POST /model/{id}/activate

TRAINING
├── POST /train/start → TrainJobOut
├── GET /train/status/{job_id} → TrainJobOut
└── GET /train/history → TrainJobOut[]
```

---

## Data Request Timeline (Dashboard Load)

```
Time → 

0ms:  User navigates to /dashboard
      ↓
      AdminLayout checks authentication
      ↓
      DashboardPage component mounts
      ↓
      useEffect hook fires

50ms: Three API requests made in parallel:
      ├─→ GET /admin/users/count
      ├─→ GET /admin/datasets/stats
      └─→ GET /analytics/dashboard
      
      State updated:
      setLoading(true)
      setError(null)

100ms: Backend queries database:
       ├─ User.count()
       ├─ User.filter(is_active=true).count()
       ├─ User.filter(role='admin').count()
       ├─ DatasetItem.all() [query, groupby, aggregate]
       ├─ Prediction.count()
       └─ [Complex joins for popular_diseases, latest_diseases, locations_count]

250ms: Responses received:
       UserCounts {total, active, admins}
       DatasetStats {total, by_label{5 keys}, by_split{3 keys}}
       AnalyticsDashboard {all fields populated}

260ms: State updates trigger re-render:
       setUserCounts(...)
       setDatasetStats(...)
       setAnalytics(...)
       setLoading(false)

280ms: Component renders with all data:
       ├─ Key Metrics Cards (instant from state)
       ├─ Pie Charts (Recharts renders from data)
       ├─ Bar Charts (Recharts renders from data)
       └─ Table (paginated view of latest_diseases)

300ms: User sees fully loaded dashboard

User Interaction → Can filter, paginate, export (all client-side operations)
```

---

## Authentication & Authorization Flow

```
┌─────────────────────────────────────┐
│  User Login (any auth method)        │
├─────────────────────────────────────┤
│ POST /auth/login or /auth/google     │
└────┬────────────────────────────────┘
     │
     ▼ (Backend validates)
┌─────────────────────────────────────┐
│  Query User table, verify password   │
│  or google_sub match                 │
└────┬────────────────────────────────┘
     │
     ├─ If valid:
     │  ├─ Generate JWT access token (expires 30 min)
     │  ├─ Generate refresh token (expires 7 days)
     │  ├─ Hash refresh token, store in DB
     │  └─ Return access_token in response
     │      Set HttpOnly cookie: refresh_token
     │
     └─ Return to frontend
        ↓
┌─────────────────────────────────────┐
│  Frontend stores access_token        │
│  in localStorage                     │
│  as 'admin_access_token'            │
└─────────────────────────────────────┘

Any Protected Request:
┌─────────────────────────────────────┐
│  Include Authorization header        │
│  Authorization: Bearer {token}       │
└────┬────────────────────────────────┘
     │
     ▼ (Backend middleware)
┌─────────────────────────────────────┐
│  Decode JWT, verify signature        │
│  Extract user_id                     │
│  Load User from DB                   │
└────┬────────────────────────────────┘
     │
     ├─ If user.role != "admin":
     │  └─ Return 403 Forbidden
     │
     └─ If valid:
        ├─ Call require_admin(user)
        └─ Execute endpoint handler
           (e.g., get_analytics_dashboard)
```

---

## Caching & Performance Considerations

```
Frontend Caching:
├─ localStorage
│  └─ 'admin_access_token' (string)
│
└─ window object (session-only)
   ├─ _ADMIN_SESSION (MeResponse)
   └─ Used to skip auth check on page load

Backend Caching:
├─ Database query results
│  ├─ /analytics/dashboard (computed on request)
│  ├─ /admin/users/count (quick counts)
│  └─ /admin/datasets/stats (aggregations)
│
└─ No explicit cache layer (can be added)

Optimization Opportunities:
├─ Implement Redis cache for analytics
├─ Add pagination to latest_diseases
├─ Index frequently filtered columns
│  (User.location, Prediction.label, created_at)
└─ Consider materialized views for monthly rankings
```

---

## Error Handling Pattern

```
Frontend Error Handling:
┌──────────────────────────┐
│ try {                    │
│   load()                 │
│   setLoading(true)       │
│   setError(null)         │
│                          │
│   const data = await     │
│     apiRequest(...)      │
│                          │
│   setState(data)         │
│ } catch (err) {          │
│   setError(err.message)  │
│   show error UI          │
│ } finally {              │
│   setLoading(false)      │
│ }                        │
└──────────────────────────┘

Backend Error Handling:
┌──────────────────────────────┐
│ @router.get("/endpoint")     │
│ def handler(...):            │
│   if not authenticated:      │
│     raise HTTPException(401) │
│                              │
│   if user.role != "admin":   │
│     raise HTTPException(403) │
│                              │
│   try:                       │
│     result = db.query(...)   │
│     return result            │
│   except Exception as e:     │
│     raise HTTPException(500) │
└──────────────────────────────┘
```

This comprehensive architecture enables real-time monitoring, quick data retrieval, and scalable admin operations.

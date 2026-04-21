# AgriSmart Admin Web (Next.js)

This folder contains the **web-based admin dashboard** for your Rice Leaf Disease Detection system. It is a separate app from the Flutter frontend and talks directly to your existing FastAPI backend.

## Folder structure

- `app/`
  - `layout.tsx` – root layout + global styles
  - `page.tsx` – default entry (redirects to `/datasets`)
  - `(auth)/login/page.tsx` – **admin login** screen
  - `(admin)/layout.tsx` – shared admin shell (top bar + nav + auth guard)
  - `datasets/page.tsx` – datasets overview (reads from `/admin/datasets` + `/admin/datasets/stats`)
  - `users/page.tsx` – user list + counts (`/admin/users`, `/admin/users/count`)
  - `activities/page.tsx` – recent activity logs (`/admin/activities`)
- `lib/api.ts` – small helper for calling your FastAPI API (handles base URL + auth headers)
- `app/globals.css` – simple, clean styling (cards, buttons, tables)
- `package.json`, `tsconfig.json`, `next.config.mjs` – standard Next.js 14 + TypeScript setup

## Backend assumptions

The admin app expects your FastAPI backend to expose:

- Auth:
  - `POST /auth/login` – returns `{ access_token }`
  - `GET  /auth/me` – returns `{ id, username, email, role }`
- Admin datasets:
  - `GET  /admin/datasets`
  - `GET  /admin/datasets/stats`
- Admin insights:
  - `GET  /admin/users/count`
  - `GET  /admin/users`
  - `GET  /admin/activities`

These routes already exist in your backend.

## How authentication works (simple and explicit)

- On **login**, the app calls `POST /auth/login` and stores the returned `access_token` in `localStorage` under the key `admin_access_token`.
- The `(admin)/layout.tsx` component:
  - reads `admin_access_token` from `localStorage`
  - calls `/auth/me` with `Authorization: Bearer <token>`
  - **only renders admin pages if `role === "admin"`**
  - otherwise redirects to `/login`.

This keeps the flow simple and clear for your capstone. In a production system, you could switch to httpOnly cookies instead of `localStorage`.

## Running the admin app

1. From the project root, install dependencies once:

   ```bash
   cd admin-web
   npm install
   ```

2. Make sure your FastAPI backend is running, e.g.:

   ```bash
   # from the backend folder
   uvicorn main:app --reload --port 8000
   ```

3. Start the Next.js dev server:

   ```bash
   cd admin-web
   npm run dev
   ```

4. Open the admin in your browser:

   ```
   http://localhost:3000/login
   ```

5. Log in using an account whose `role` is `admin` (via your existing backend / SQLite).

## Configuring the backend URL

By default, the admin app calls the backend at:

```ts
NEXT_PUBLIC_API_BASE_URL = 'http://localhost:8000'
```

To change this (e.g. when deploying), create `admin-web/.env.local`:

```env
NEXT_PUBLIC_API_BASE_URL=http://YOUR_BACKEND_HOST:8000
```

## Extending the admin

- To add new admin pages, create a folder under `app/` (e.g. `app/reports/page.tsx`) and wrap the content using the existing `(admin)/layout.tsx` so the auth guard and header stay consistent.
- To call new backend endpoints, add helper functions to `lib/api.ts` or use `apiRequest` directly from your page.

This structure keeps all admin-related code inside `admin-web/`, so it’s easy to find and maintain without touching your Flutter user app.


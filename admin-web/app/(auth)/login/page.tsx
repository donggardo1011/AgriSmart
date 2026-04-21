'use client';

import { FormEvent, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { saveToken } from '@/lib/auth';
import { getApiBaseUrl } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const remembered = window.localStorage.getItem('admin_remembered_username');
    const shouldRemember =
      window.localStorage.getItem('admin_remember_me') === 'true';

    setRememberMe(shouldRemember);
    if (shouldRemember && remembered) {
      setUsername(remembered);
    }
  }, []);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const res = await fetch(`${getApiBaseUrl()}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username,
          password,
          recaptcha_token: 'dev-token',
        }),
      });

      if (!res.ok) {
        let message = 'Login failed. Please try again.';
        try {
          const data = (await res.json()) as { detail?: string };
          if (
            data.detail?.toLowerCase().includes('invalid username or password')
          ) {
            message = 'Incorrect username or password.';
          }
        } catch {
          // Ignore JSON parsing errors
        }
        throw new Error(message);
      }

      const data = (await res.json()) as { access_token: string };
      window.localStorage.setItem('admin_remember_me', String(rememberMe));
      if (rememberMe) {
        window.localStorage.setItem('admin_remembered_username', username.trim());
      } else {
        window.localStorage.removeItem('admin_remembered_username');
      }
      
      // Use centralized token saving function
      saveToken(data.access_token);
      
      // Redirect to dashboard using router
      router.replace('/dashboard');
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Login failed';
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-100 px-4 py-10 sm:px-6 lg:px-8">
      <div className="w-full max-w-md rounded-[28px] border bg-white p-8 shadow-sm shadow-slate-200/70 sm:p-10">
        <div className="flex items-center gap-4">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-emerald-600 text-lg font-semibold text-white shadow-sm shadow-emerald-200">
            A
          </div>
          <div>
            <div className="text-base font-semibold text-slate-900">AgriSmart Admin</div>
          </div>
        </div>

        <div className="mt-8">
          <div className="section-kicker">Sign in</div>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-slate-900">Welcome back</h1>
          <p className="mt-2 text-sm leading-6 text-slate-500">Use your admin credentials to continue.</p>
        </div>

        {error && (
          <div className="mt-6 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="mt-8 space-y-5">
          <div>
            <label className="field-label">Username</label>
            <input
              type="text"
              className="input"
              placeholder="Enter your username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
            />
          </div>
          <div>
            <label className="field-label">Password</label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                className="input pr-12"
                placeholder="Enter your password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
              <button
                type="button"
                onClick={() => setShowPassword((current) => !current)}
                className="absolute inset-y-0 right-0 flex w-12 items-center justify-center text-slate-500 transition hover:text-slate-700"
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? (
                  <svg
                    viewBox="0 0 24 24"
                    className="h-5 w-5"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <path d="M3 3l18 18" />
                    <path d="M10.58 10.58A2 2 0 0 0 12 14a2 2 0 0 0 1.42-.58" />
                    <path d="M9.88 4.24A10.94 10.94 0 0 1 12 4c5 0 9.27 3.11 11 8-1 2.61-2.89 4.77-5.32 6.04" />
                    <path d="M6.61 6.61C4.62 7.91 3.08 9.79 2 12c1.73 4.89 6 8 10 8 1.61 0 3.16-.32 4.58-.9" />
                  </svg>
                ) : (
                  <svg
                    viewBox="0 0 24 24"
                    className="h-5 w-5"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <path d="M2 12s3.64-7 10-7 10 7 10 7-3.64 7-10 7-10-7-10-7Z" />
                    <circle cx="12" cy="12" r="3" />
                  </svg>
                )}
              </button>
            </div>
          </div>

          <label className="flex items-center gap-3 text-sm text-slate-600">
            <input
              type="checkbox"
              checked={rememberMe}
              onChange={(e) => setRememberMe(e.target.checked)}
              className="h-4 w-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500"
            />
            <span>Remember me</span>
          </label>

          <button type="submit" disabled={loading} className="btn-primary w-full justify-center py-3">
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
        </form>
      </div>
    </div>
  );
}

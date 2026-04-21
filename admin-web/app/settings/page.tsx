'use client';

import { FormEvent, useEffect, useState } from 'react';
import AdminLayout from '@/app/(admin)/layout';
import { apiRequest, authHeaders } from '@/lib/api';

interface UserProfile {
  id: number;
  username: string;
  email: string;
  location?: string;
  role: string;
  created_at: string;
}

interface PasswordChangeRequest {
  old_password: string;
  new_password: string;
  new_password_confirm: string;
}

export default function SettingsPage() {
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Password change state
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newPasswordConfirm, setNewPasswordConfirm] = useState('');
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [passwordSuccess, setPasswordSuccess] = useState<string | null>(null);

  useEffect(() => {
    void loadProfile();
  }, []);

  async function loadProfile() {
    setLoading(true);
    setError(null);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      const userProfile = await apiRequest<UserProfile>('/auth/me', {
        headers: authHeaders(token),
      });
      setProfile(userProfile);
    } catch (err: any) {
      setError(err.message ?? 'Failed to load profile');
    } finally {
      setLoading(false);
    }
  }

  async function handlePasswordChange(e: FormEvent) {
    e.preventDefault();
    setPasswordError(null);
    setPasswordSuccess(null);

    // Validation
    if (!oldPassword || !newPassword || !newPasswordConfirm) {
      setPasswordError('All fields are required');
      return;
    }

    if (newPassword !== newPasswordConfirm) {
      setPasswordError('New passwords do not match');
      return;
    }

    if (newPassword.length < 8) {
      setPasswordError('New password must be at least 8 characters');
      return;
    }

    if (oldPassword === newPassword) {
      setPasswordError('New password must be different from current password');
      return;
    }

    setPasswordLoading(true);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      await apiRequest('/auth/change-password', {
        method: 'POST',
        headers: authHeaders(token),
        body: JSON.stringify({
          old_password: oldPassword,
          new_password: newPassword,
        }),
      });

      setPasswordSuccess('Password changed successfully');
      setOldPassword('');
      setNewPassword('');
      setNewPasswordConfirm('');
    } catch (err: any) {
      setPasswordError(err.message ?? 'Failed to change password');
    } finally {
      setPasswordLoading(false);
    }
  }

  if (loading) {
    return (
      <AdminLayout>
        <div className="mx-auto max-w-[1100px] space-y-8">
          <div className="flex items-center justify-center h-40">
            <div className="text-slate-600">Loading profile...</div>
          </div>
        </div>
      </AdminLayout>
    );
  }

  return (
    <AdminLayout>
      <div className="mx-auto max-w-[1100px] space-y-8">
        <div>
          <h1 className="page-title">Settings</h1>
        </div>

        {error && <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}

        {/* Profile Section */}
        <div className="card">
          <div className="section-kicker">Account</div>
          <h2 className="mt-2 section-title">Profile Information</h2>

          {profile && (
            <div className="mt-6 space-y-6">
              <div>
                <label className="text-sm font-medium text-slate-700 block mb-2">Username</label>
                <div className="px-4 py-3 bg-slate-50 rounded-lg text-slate-900 font-medium">
                  {profile.username}
                </div>
              </div>

              <div>
                <label className="text-sm font-medium text-slate-700 block mb-2">Email Address</label>
                <div className="px-4 py-3 bg-slate-50 rounded-lg text-slate-900">
                  {profile.email}
                </div>
              </div>

              <div>
                <label className="text-sm font-medium text-slate-700 block mb-2">Location</label>
                <div className="px-4 py-3 bg-slate-50 rounded-lg text-slate-900">
                  {profile.location || 'Not specified'}
                </div>
              </div>

              <div>
                <label className="text-sm font-medium text-slate-700 block mb-2">Role</label>
                <div className="px-4 py-3 bg-slate-50 rounded-lg">
                  <span className={profile.role === 'admin' ? 'badge badge-green' : 'badge badge-slate'}>
                    {profile.role}
                  </span>
                </div>
              </div>

              <div>
                <label className="text-sm font-medium text-slate-700 block mb-2">Member Since</label>
                <div className="px-4 py-3 bg-slate-50 rounded-lg text-slate-900">
                  {new Date(profile.created_at).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                  })}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Password Change Section */}
        <div className="card">
          <div className="section-kicker">Security</div>
          <h2 className="mt-2 section-title">Change Password</h2>

          {passwordSuccess && (
            <div className="mt-4 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
              {passwordSuccess}
            </div>
          )}

          {passwordError && (
            <div className="mt-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {passwordError}
            </div>
          )}

          <form onSubmit={(e) => void handlePasswordChange(e)} className="mt-6 space-y-5">
            <div>
              <label htmlFor="old-password" className="text-sm font-medium text-slate-700 block mb-2">
                Current Password
              </label>
              <input
                id="old-password"
                type="password"
                value={oldPassword}
                onChange={(e) => setOldPassword(e.target.value)}
                placeholder="Enter your current password"
                className="input"
                disabled={passwordLoading}
              />
            </div>

            <div>
              <label htmlFor="new-password" className="text-sm font-medium text-slate-700 block mb-2">
                New Password
              </label>
              <input
                id="new-password"
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                placeholder="Enter a new password (min. 8 characters)"
                className="input"
                disabled={passwordLoading}
              />
            </div>

            <div>
              <label htmlFor="confirm-password" className="text-sm font-medium text-slate-700 block mb-2">
                Confirm New Password
              </label>
              <input
                id="confirm-password"
                type="password"
                value={newPasswordConfirm}
                onChange={(e) => setNewPasswordConfirm(e.target.value)}
                placeholder="Confirm your new password"
                className="input"
                disabled={passwordLoading}
              />
            </div>

            <button
              type="submit"
              disabled={passwordLoading}
              className="w-full px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition text-sm font-medium"
            >
              {passwordLoading ? 'Updating...' : 'Update Password'}
            </button>
          </form>
        </div>
      </div>
    </AdminLayout>
  );
}

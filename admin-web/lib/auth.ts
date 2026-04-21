// Centralized authentication utilities for consistent auth handling

export interface AuthState {
  isAuthenticated: boolean;
  token: string | null;
  loading: boolean;
}

/**
 * Get the stored authentication token from localStorage
 * @returns The access token or null if not found
 */
export function getStoredToken(): string | null {
  if (typeof window === 'undefined') {
    return null;
  }
  return window.localStorage.getItem('admin_access_token');
}

/**
 * Save the authentication token to localStorage
 * @param token The access token to save
 */
export function saveToken(token: string): void {
  if (typeof window !== 'undefined') {
    window.localStorage.setItem('admin_access_token', token);
  }
}

/**
 * Remove the authentication token from localStorage
 */
export function clearToken(): void {
  if (typeof window !== 'undefined') {
    window.localStorage.removeItem('admin_access_token');
  }
}

/**
 * Check if a token exists (initial check - doesn't validate)
 * @returns true if token exists in storage
 */
export function hasToken(): boolean {
  return getStoredToken() !== null;
}

/**
 * Verify token validity by making a request to the backend
 * @param token The token to verify
 * @returns true if token is valid, false otherwise
 */
export async function verifyToken(token: string): Promise<boolean> {
  try {
    const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8000';
    const response = await fetch(`${baseUrl}/auth/me`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    return response.ok;
  } catch {
    return false;
  }
}

/**
 * Logout the user by clearing token and redirecting to login
 */
export function logout(): void {
  clearToken();
  if (typeof window !== 'undefined') {
    window.location.href = '/login';
  }
}

/**
 * Redirect to dashboard if already authenticated
 */
export function redirectIfAuthenticated(): void {
  if (hasToken()) {
    if (typeof window !== 'undefined') {
      window.location.href = '/dashboard';
    }
  }
}

/**
 * Redirect to login if not authenticated
 */
export function redirectIfNotAuthenticated(): void {
  if (!hasToken()) {
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
  }
}

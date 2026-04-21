'use client';

import { useEffect, useState } from 'react';
import { getStoredToken, verifyToken, clearToken } from './auth';

export interface User {
  id: number;
  username: string;
  email: string;
  role: string;
}

export interface UseAuthReturn {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: User | null;
  token: string | null;
  logout: () => void;
}

/**
 * Custom hook to manage authentication state with token validation
 * Ensures token is valid before considering user as authenticated
 */
export function useAuth(): UseAuthReturn {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);

  useEffect(() => {
    async function checkAuth() {
      try {
        const storedToken = getStoredToken();
        
        // If no token, user is not authenticated
        if (!storedToken) {
          setIsAuthenticated(false);
          setToken(null);
          setUser(null);
          setIsLoading(false);
          return;
        }

        // Verify token is valid by calling /auth/me endpoint
        const isValid = await verifyToken(storedToken);
        
        if (!isValid) {
          // Token is invalid, clear it
          clearToken();
          setIsAuthenticated(false);
          setToken(null);
          setUser(null);
          setIsLoading(false);
          return;
        }

        // Token is valid, fetch user info
        try {
          const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8000';
          const response = await fetch(`${baseUrl}/auth/me`, {
            headers: {
              Authorization: `Bearer ${storedToken}`,
            },
          });

          if (response.ok) {
            const userData = (await response.json()) as User;
            setUser(userData);
            setToken(storedToken);
            setIsAuthenticated(true);
          } else {
            // Could not fetch user info, token is invalid
            clearToken();
            setIsAuthenticated(false);
            setToken(null);
            setUser(null);
          }
        } catch (error) {
          console.error('Failed to fetch user info:', error);
          setIsAuthenticated(false);
          setToken(null);
          setUser(null);
        }
      } finally {
        setIsLoading(false);
      }
    }

    checkAuth();
  }, []);

  const logout = () => {
    clearToken();
    setIsAuthenticated(false);
    setToken(null);
    setUser(null);
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
  };

  return {
    isAuthenticated,
    isLoading,
    user,
    token,
    logout,
  };
}

'use client';

import { useEffect, ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { hasToken } from '@/lib/auth';

/**
 * Layout wrapper for auth routes (login page)
 * Redirects authenticated users to dashboard
 */
export default function AuthLayout({ children }: { children: ReactNode }) {
  const router = useRouter();

  useEffect(() => {
    // Check if user is already authenticated
    if (hasToken()) {
      // Redirect to dashboard if authenticated
      router.replace('/dashboard');
    }
  }, [router]);

  return <>{children}</>;
}

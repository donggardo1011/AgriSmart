'use client';

import type { ReactNode } from 'react';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import {
  faTachometerAlt,
  faDatabase,
  faRobot,
  faComments,
  faCloudDownloadAlt,
  faCog,
  faUsers,
  faClipboardList,
} from '@fortawesome/free-solid-svg-icons';
import { useAuth } from '@/lib/useAuth';

const navItems = [
  { label: 'Dashboard', href: '/dashboard', icon: faTachometerAlt },
  { label: 'Datasets', href: '/datasets', icon: faDatabase },
  { label: 'Models', href: '/models', icon: faRobot },
  { label: 'Chatbot', href: '/chatbot', icon: faComments },
  { label: 'Backup', href: '/backup', icon: faCloudDownloadAlt },
  { label: 'Settings', href: '/settings', icon: faCog },
];

const adminItems = [
  { label: 'Users', href: '/users', icon: faUsers },
  { label: 'Activities', href: '/activities', icon: faClipboardList },
];

function SidebarLink({
  href,
  icon,
  label,
  active,
}: {
  href: string;
  icon: IconDefinition;
  label: string;
  active: boolean;
}) {
  return (
    <Link
      href={href}
      className={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition ${
        active
          ? 'bg-emerald-50 text-emerald-700'
          : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
      }`}
    >
      <span
        className={`flex h-8 w-8 items-center justify-center rounded-lg text-sm ${
          active ? 'bg-white text-emerald-700' : 'bg-slate-100 text-slate-500'
        }`}
      >
        <FontAwesomeIcon icon={icon} width={16} height={16} />
      </span>
      <span className={active ? 'font-medium' : 'font-normal'}>{label}</span>
    </Link>
  );
}

export default function AdminLayout({ children }: { children: ReactNode }) {
  const { isAuthenticated, isLoading, user, logout } = useAuth();
  const [isDesktop, setIsDesktop] = useState(true);
  const pathname = usePathname();
  const router = useRouter();

  // Check if user is authenticated and redirect if not
  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.replace('/login');
    }
  }, [isAuthenticated, isLoading, router]);

  // Check for desktop screen size
  useEffect(() => {
    function check() {
      setIsDesktop(window.innerWidth >= 1100);
    }
    check();
    window.addEventListener('resize', check);
    return () => window.removeEventListener('resize', check);
  }, []);

  // Show loading state while authenticating
  if (isLoading) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center bg-slate-100">
        <div className="flex flex-col items-center gap-4">
          <div className="h-12 w-12 rounded-full border-4 border-emerald-600 border-t-transparent animate-spin" />
          <span className="animate-pulse text-sm text-slate-500">Loading admin session...</span>
        </div>
      </div>
    );
  }

  // Show desktop-only message for mobile devices
  if (!isDesktop) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-100 p-6">
        <div className="card max-w-lg w-full text-center">
          <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-amber-100 text-lg font-semibold text-amber-700">
            UI
          </div>
          <h1 className="text-2xl font-semibold text-slate-900">Desktop only</h1>
          <p className="mt-2 text-sm leading-6 text-slate-500">
            The AgriSmart Admin dashboard is optimized for large screens. Please switch to a desktop or laptop device.
          </p>
        </div>
      </div>
    );
  }

  // If not authenticated at this point, don't render (redirect will handle it)
  if (!isAuthenticated || !user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-slate-100">
      <div className="flex min-h-screen">
        <aside className="sticky top-0 flex h-screen w-72 flex-col border-r bg-white/95 backdrop-blur">
          <div className="flex items-center gap-3 border-b px-6 py-6">
            <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-emerald-600 text-lg font-semibold text-white shadow-sm shadow-emerald-200">
              A
            </div>
            <div>
              <div className="text-sm font-semibold leading-tight text-slate-900">AgriSmart Admin</div>
            </div>
          </div>

          <div className="flex-1 space-y-8 overflow-y-auto p-4">
            <div className="flex items-center gap-3 rounded-2xl border bg-slate-50 px-3 py-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-white text-sm font-semibold text-slate-700 shadow-sm">
                {user.username[0].toUpperCase()}
              </div>
              <div className="overflow-hidden">
                <div className="truncate text-sm font-medium text-slate-900">{user.username}</div>
                <div className="truncate text-xs text-slate-500">{user.email}</div>
              </div>
            </div>

            <nav className="space-y-1">
              <div className="px-3 pb-2 text-[11px] font-medium uppercase tracking-[0.16em] text-slate-400">Main</div>
              {navItems.map((item) => (
                <SidebarLink key={item.href} {...item} active={pathname === item.href} />
              ))}
            </nav>

            <nav className="space-y-1">
              <div className="px-3 pb-2 text-[11px] font-medium uppercase tracking-[0.16em] text-slate-400">
                Administration
              </div>
              {adminItems.map((item) => (
                <SidebarLink key={item.href} {...item} active={pathname === item.href} />
              ))}
            </nav>
          </div>

          <div className="border-t p-4">
            <button onClick={logout} className="btn-secondary w-full justify-center">
              Logout
            </button>
          </div>
        </aside>

        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-10 flex h-20 items-center border-b bg-white/90 px-8 backdrop-blur">
            <div>
              <div className="text-base font-semibold text-slate-900">Admin Console</div>
              <div className="text-sm text-slate-500">System management and monitoring</div>
            </div>
          </header>

          <main className="flex-1 overflow-y-auto p-8">{children}</main>
        </div>
      </div>
    </div>
  );
}

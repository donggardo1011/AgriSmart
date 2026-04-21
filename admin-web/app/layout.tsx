import type { ReactNode } from 'react';
import './globals.css';

export const metadata = {
  title: 'AgriSmart Admin',
  description: 'Admin dashboard for Rice Leaf Disease Detection',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-slate-100 text-slate-900">
        {children}
      </body>
    </html>
  );
}


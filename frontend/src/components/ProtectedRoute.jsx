import React, { useEffect, useState } from 'react';
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAppStore } from '../store/useAppStore';
import { toast } from 'sonner';

export default function ProtectedRoute() {
  const { isAuthenticated, loginTimestamp, logout, initAuth, login } = useAppStore();
  const location = useLocation();
  const [isInitializing, setIsInitializing] = useState(true);

  // Initialize auth state on mount (checks localStorage)
  useEffect(() => {
    const searchParams = new URLSearchParams(location.search);
    const token = searchParams.get('token');
    
    if (token) {
      login({ name: 'Organization User' }, token);
      window.history.replaceState({}, document.title, location.pathname);
    }

    initAuth();
    setIsInitializing(false);
  }, [initAuth, location, login]);

  // Periodic timeout check
  useEffect(() => {
    if (!isAuthenticated || !loginTimestamp) return;

    const checkTimeout = () => {
      const thirtyMinutes = 30 * 60 * 1000;
      if (Date.now() - loginTimestamp >= thirtyMinutes) {
        toast.error("Session expired. Please log in again.");
        logout();
      }
    };

    // Check immediately and then every minute
    checkTimeout();
    const interval = setInterval(checkTimeout, 60000);

    return () => clearInterval(interval);
  }, [isAuthenticated, loginTimestamp, logout]);

  if (isInitializing) {
    return (
      <div className="flex-center" style={{ height: '100vh', background: 'var(--bg-dark)' }}>
        <div className="text-muted">Loading...</div>
      </div>
    );
  }

  if (!isAuthenticated) {
    // Redirect them to the /login page, but save the current location they were trying to go to
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <Outlet />;
}

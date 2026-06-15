import React, { useState, useEffect } from 'react';
import { Outlet, NavLink, useNavigate } from 'react-router-dom';
import Sidebar from '../components/Sidebar';
import WhatsAppWidget from '../components/WhatsAppWidget';
import { useAppStore } from '../store/useAppStore';
import { LogOut, Menu, X, LayoutDashboard, GitBranch, Users, FileText, Truck } from 'lucide-react';
import { API_BASE } from '../config';
import { apiFetch } from '../api';

export default function MainLayout() {
  const [lang, setLang] = useState('EN');
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [pendingCount, setPendingCount] = useState(0);
  const { logout } = useAppStore();
  const navigate = useNavigate();

  const menuItems = [
    { name: 'Dashboard', path: '/', icon: LayoutDashboard },
    { name: 'Workflow Engine', path: '/workflow', icon: GitBranch },
    { name: 'Agent Hub', path: '/agents', icon: Users },
    { name: 'Documents', path: '/documents', icon: FileText },
    { name: 'Logistics', path: '/logistics', icon: Truck }
  ];

  const handleLogout = () => {
    logout();
    navigate('/login', { replace: true });
  };

  useEffect(() => {
    const checkApprovals = async () => {
      try {
        const res = await apiFetch(`${API_BASE}/api/v1/approvals?status_filter=pending`);
        if (res.ok) {
          const data = await res.json();
          setPendingCount(data.total || data.approvals?.length || 0);
        }
      } catch (e) {
        console.error("MainLayout approvals fetch error:", e);
      }
    };
    checkApprovals();
    const interval = setInterval(checkApprovals, 5000); // Check every 5 seconds for rapid updates
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (document.cookie.includes('googtrans=/en/ar')) {
      setLang('AR');
      useAppStore.getState().setLanguage('AR');
    } else {
      setLang('EN');
      useAppStore.getState().setLanguage('EN');
    }
  }, []);

  const toggleLanguage = () => {
    const domain = window.location.hostname;
    const nextLang = lang === 'EN' ? 'AR' : 'EN';

    if (nextLang === 'AR') {
      document.cookie = `googtrans=/en/ar; path=/; domain=${domain}`;
      document.cookie = `googtrans=/en/ar; path=/;`;
      setLang('AR');
      useAppStore.getState().setLanguage('AR');
      document.documentElement.dir = 'rtl';
      document.documentElement.lang = 'ar';
    } else {
      // Clear cookie completely to force reset to original language
      document.cookie = `googtrans=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=${domain}`;
      document.cookie = `googtrans=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`;
      document.cookie = `googtrans=/en/en; path=/; domain=${domain}`;
      document.cookie = `googtrans=/en/en; path=/;`;
      setLang('EN');
      useAppStore.getState().setLanguage('EN');
      document.documentElement.dir = 'ltr';
      document.documentElement.lang = 'en';
    }

    // Attempt to trigger the Google Translate widget directly without reloading
    const select = document.querySelector('.goog-te-combo');
    const isReady = select && select.options && select.options.length > 0;
    if (isReady) {
      select.value = nextLang === 'AR' ? 'ar' : 'en';
      select.dispatchEvent(new Event('change'));
    } else {
      // Fallback: If widget isn't fully loaded/ready yet, reload the page to let Google Translate initialize with the new cookie
      window.location.reload();
    }
  };

  return (
    <div className="app-container">
      <Sidebar />
      <div className="content-wrapper" style={{ flex: 1, display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden', position: 'relative' }}>
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          backgroundImage: 'url(/header_logo.png)',
          backgroundSize: 'cover',
          backgroundPosition: 'center 15%',
          opacity: 0.1,
          zIndex: 0,
          pointerEvents: 'none'
        }} />
        
        <header className="main-header" style={{
          borderBottom: 'var(--glass-border)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          background: 'rgba(15, 15, 22, 0.4)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          gap: '1.5rem',
          zIndex: 10,
          flexShrink: 0
        }}>
          {/* Mobile Hamburger Button */}
          <button 
            className="mobile-only badge flex-center"
            onClick={() => setIsMobileMenuOpen(true)}
            style={{ padding: '0.5rem', cursor: 'pointer', background: 'transparent', border: '1px solid rgba(255,255,255,0.1)', color: 'white' }}
          >
            <Menu size={24} />
          </button>

          <NavLink to="/dashboard" className="mobile-header-logo" style={{ display: 'none', alignItems: 'center', gap: '0.75rem', textDecoration: 'none' }}>
            <img src="/logo.jpeg" alt="TradeOS Logo" style={{ width: '32px', height: '32px', borderRadius: '0.5rem', border: '1px solid rgba(0, 229, 255, 0.2)' }} />
            <span style={{ fontSize: '1.25rem', fontWeight: 'bold', color: 'white', letterSpacing: '0.05em' }}>TradeOS</span>
          </NavLink>
          
          <div className="mobile-only" style={{ width: '42px' }}>{/* Spacer for centering logo on mobile */}</div>

          <div className="desktop-only" style={{ display: 'flex', gap: '1.5rem', alignItems: 'center', flex: 1, justifyContent: 'flex-end' }}>
            <button 
              className="badge notranslate" 
              onClick={toggleLanguage}
              style={{ 
                padding: '0.5rem 1rem', 
                fontSize: '0.875rem', 
                cursor: 'pointer', 
                border: '1px solid rgba(255,255,255,0.1)',
                background: 'rgba(255,255,255,0.05)',
                color: 'var(--text-main)',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                transition: 'all 0.3s ease'
              }}
              title="Toggle Language (English / Arabic)"
            >
              <span style={{ opacity: lang === 'EN' ? 1 : 0.4, fontWeight: lang === 'EN' ? 'bold' : 'normal', display: 'flex', alignItems: 'center', gap: '6px' }}>
                <img src="https://flagcdn.com/w20/us.png" alt="US Flag" style={{ width: '16px', borderRadius: '2px' }} /> EN
              </span>
              <span style={{ opacity: 0.3 }}>|</span>
              <span style={{ opacity: lang === 'AR' ? 1 : 0.4, fontWeight: lang === 'AR' ? 'bold' : 'normal', display: 'flex', alignItems: 'center', gap: '6px' }}>
                <img src="https://flagcdn.com/w20/ae.png" alt="UAE Flag" style={{ width: '16px', borderRadius: '2px' }} /> AR
              </span>
            </button>

            <button
              onClick={handleLogout}
              style={{
                padding: '0.5rem 1rem', 
                fontSize: '0.875rem', 
                cursor: 'pointer', 
                border: '1px solid rgba(239, 68, 68, 0.2)',
                background: 'rgba(239, 68, 68, 0.1)',
                color: '#fca5a5',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                borderRadius: '2rem',
                transition: 'all 0.3s ease'
              }}
              title="Logout"
              onMouseOver={(e) => {
                e.currentTarget.style.background = 'rgba(239, 68, 68, 0.2)';
              }}
              onMouseOut={(e) => {
                e.currentTarget.style.background = 'rgba(239, 68, 68, 0.1)';
              }}
            >
              <LogOut size={16} />
              <span style={{ fontWeight: '500' }}>Logout</span>
            </button>
          </div>
        </header>
        <main className="main-content" style={{ flex: 1, overflowY: 'auto', zIndex: 1, position: 'relative' }}>
          <Outlet />
        </main>
        
        <WhatsAppWidget />

        {/* Mobile Drawer */}
        {isMobileMenuOpen && (
          <div style={{
            position: 'fixed', top: 0, bottom: 0, 
            left: lang === 'EN' ? 0 : 'auto', 
            right: lang === 'AR' ? 0 : 'auto',
            width: '80%', maxWidth: '320px', 
            background: 'var(--bg-sidebar)',
            zIndex: 9999,
            display: 'flex', flexDirection: 'column',
            boxShadow: '0 0 50px rgba(0,0,0,0.5)',
            borderRight: lang === 'EN' ? 'var(--glass-border)' : 'none',
            borderLeft: lang === 'AR' ? 'var(--glass-border)' : 'none',
            animation: `slideIn${lang === 'AR' ? 'Right' : 'Left'} 0.3s forwards`
          }}>
            <div style={{ padding: '1.5rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: 'var(--glass-border)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <img src="/logo.jpeg" alt="TradeOS" style={{ width: '40px', borderRadius: '0.5rem' }} />
                <span className="text-xl text-gradient notranslate" style={{ fontWeight: '600' }}>TradeOS</span>
              </div>
              <button onClick={() => setIsMobileMenuOpen(false)} style={{ background: 'transparent', border: 'none', color: 'white', cursor: 'pointer' }}>
                <X size={24} />
              </button>
            </div>

            <div style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '0.5rem', flex: 1, overflowY: 'auto' }}>
              {menuItems.map(item => {
                const hasBadge = (item.name === 'Agent Hub' || item.name === 'Workflow Engine') && pendingCount > 0;
                return (
                  <NavLink
                    key={item.name}
                    to={item.path}
                    onClick={() => setIsMobileMenuOpen(false)}
                    className={({ isActive }) => `sidebar-link ${isActive ? 'active' : ''}`}
                    style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: '1rem', 
                      padding: '1rem',
                      position: 'relative'
                    }}
                  >
                    <item.icon size={20} />
                    <span>{item.name}</span>
                    {hasBadge && (
                      <span style={{ 
                        background: 'linear-gradient(135deg, #ef4444, #dc2626)', 
                        color: 'white', 
                        fontSize: '0.7rem', 
                        fontWeight: 'bold', 
                        padding: '0 6px', 
                        borderRadius: '10px', 
                        marginLeft: 'auto',
                        boxShadow: '0 0 10px rgba(239, 68, 68, 0.5)',
                        border: '1px solid rgba(255, 255, 255, 0.15)',
                        display: 'inline-flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        minWidth: '18px',
                        height: '18px',
                        lineHeight: 1,
                        boxSizing: 'border-box'
                      }}>
                        {pendingCount}
                      </span>
                    )}
                  </NavLink>
                );
              })}
            </div>

            <div style={{ padding: '1.5rem', borderTop: 'var(--glass-border)', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <button 
                className="badge notranslate" 
                onClick={() => { toggleLanguage(); setIsMobileMenuOpen(false); }}
                style={{ width: '100%', padding: '0.75rem', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '1rem', background: 'rgba(255,255,255,0.05)', color: 'white', border: '1px solid rgba(255,255,255,0.1)' }}
              >
                <span style={{ opacity: lang === 'EN' ? 1 : 0.4, fontWeight: lang === 'EN' ? 'bold' : 'normal', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <img src="https://flagcdn.com/w20/us.png" alt="US" style={{ width: '16px' }} /> EN
                </span>
                <span style={{ opacity: 0.3 }}>|</span>
                <span style={{ opacity: lang === 'AR' ? 1 : 0.4, fontWeight: lang === 'AR' ? 'bold' : 'normal', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <img src="https://flagcdn.com/w20/ae.png" alt="UAE" style={{ width: '16px' }} /> AR
                </span>
              </button>
              
              <button
                onClick={handleLogout}
                style={{
                  width: '100%', padding: '0.75rem', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '0.5rem',
                  background: 'rgba(239, 68, 68, 0.1)', color: '#fca5a5', border: '1px solid rgba(239, 68, 68, 0.2)', borderRadius: '2rem'
                }}
              >
                <LogOut size={18} />
                <span style={{ fontWeight: 500 }}>Logout</span>
              </button>
            </div>
          </div>
        )}
        
        {/* Backdrop for Drawer */}
        {isMobileMenuOpen && (
          <div 
            onClick={() => setIsMobileMenuOpen(false)}
            style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 9998, backdropFilter: 'blur(4px)' }}
          />
        )}
      </div>
    </div>
  );
}

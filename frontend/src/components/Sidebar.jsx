import React, { useState, useEffect } from 'react';
import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard, GitBranch, Users,
  FileText, ShieldCheck, Truck,
  ChevronLeft, ChevronRight
} from 'lucide-react';
import { API_BASE } from '../config';
import { apiFetch } from '../api';

export default function Sidebar() {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [pendingCount, setPendingCount] = useState(0);

  const menuItems = [
    { name: 'Dashboard', path: '/dashboard', icon: LayoutDashboard },
    { name: 'Workflow Engine', path: '/workflow', icon: GitBranch },
    { name: 'Agent Hub', path: '/agents', icon: Users },
    { name: 'Documents', path: '/documents', icon: FileText },
    { name: 'Logistics', path: '/logistics', icon: Truck }
  ];

  useEffect(() => {
    const checkApprovals = async () => {
      try {
        const res = await apiFetch(`${API_BASE}/api/v1/approvals?status_filter=pending`);
        if (res.ok) {
          const data = await res.json();
          setPendingCount(data.total || data.approvals?.length || 0);
        }
      } catch (e) {
        console.error("Sidebar approvals fetch error:", e);
      }
    };
    checkApprovals();
    const interval = setInterval(checkApprovals, 5000); // Check every 5 seconds for rapid updates
    return () => clearInterval(interval);
  }, []);

  return (
    <aside className={`sidebar ${isCollapsed ? 'collapsed' : ''}`} style={{ width: isCollapsed ? '88px' : '280px', padding: isCollapsed ? '1.5rem 0.5rem' : '1.5rem', transition: 'all 0.3s ease', position: 'relative' }}>

      {/* Collapse Toggle Button */}
      <button
        className="sidebar-collapse-btn"
        onClick={() => setIsCollapsed(!isCollapsed)}
      >
        {isCollapsed ? <ChevronRight size={14} className="collapse-icon" /> : <ChevronLeft size={14} className="collapse-icon" />}
      </button>

      <NavLink to="/dashboard" className="mb-8" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', transition: 'all 0.3s ease', minHeight: isCollapsed ? '40px' : '180px', textDecoration: 'none' }}>
        <img
          src="/logo.jpeg"
          alt="TradeOS Logo"
          style={{
            width: isCollapsed ? '40px' : '120px',
            height: isCollapsed ? '40px' : '120px',
            borderRadius: isCollapsed ? '0.5rem' : '1rem',
            marginBottom: '0.75rem',
            border: '2px solid rgba(0, 229, 255, 0.2)',
            boxShadow: '0 0 15px rgba(0, 229, 255, 0.25)',
            transition: 'all 0.3s ease'
          }}
        />
        {!isCollapsed && (
          <div className="animate-fade-in">
            <h1 className="text-3xl text-gradient notranslate">TradeOS</h1>
            <p className="text-muted text-xs mt-2">Agentic AI Export Operating System</p>
          </div>
        )}
      </NavLink>

      <nav className="sidebar-nav" style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '0.25rem', overflowY: 'auto', overflowX: 'hidden', paddingInlineEnd: isCollapsed ? '0' : '0.5rem' }}>
        {menuItems.map((item) => {
          const Icon = item.icon;
          const hasBadge = (item.name === 'Agent Hub' || item.name === 'Workflow Engine') && pendingCount > 0;
          
          return (
            <NavLink
              key={item.name}
              to={item.path}
              onClick={(e) => {
                if (window.location.pathname === item.path) {
                  window.dispatchEvent(new CustomEvent('sidebar_click', { detail: item.path }));
                }
              }}
              className={({ isActive }) => `sidebar-link ${isActive ? 'active' : ''}`}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem',
                justifyContent: isCollapsed ? 'center' : 'flex-start',
                padding: isCollapsed ? '0' : '0.75rem 1rem',
                width: isCollapsed ? '44px' : 'auto',
                height: isCollapsed ? '44px' : 'auto',
                margin: isCollapsed ? '0 auto 0.5rem auto' : '0 0 0.5rem 0',
                borderRadius: '0.75rem',
                alignSelf: isCollapsed ? 'center' : 'stretch',
                position: 'relative'
              }}
              title={isCollapsed ? item.name : ''}
            >
              {isCollapsed ? (
                <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon size={18} />
                  {hasBadge && (
                    <span style={{
                      position: 'absolute',
                      top: '-4px',
                      right: '-4px',
                      width: '8px',
                      height: '8px',
                      background: 'linear-gradient(135deg, #ef4444, #dc2626)',
                      borderRadius: '50%',
                      boxShadow: '0 0 10px rgba(239, 68, 68, 0.8)',
                    }} />
                  )}
                </div>
              ) : (
                <>
                  <Icon size={18} />
                  <span style={{ whiteSpace: 'nowrap' }}>{item.name}</span>
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
                </>
              )}
            </NavLink>
          );
        })}
      </nav>

      {/* ISO Section */}
      <div
        className="mt-6 pt-4"
        style={{
          borderTop: '1px solid rgba(255,255,255,0.05)',
          display: 'flex',
          flexDirection: 'column',
          gap: '0.5rem',
          transition: 'all 0.3s ease'
        }}
      >
        {isCollapsed ? (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '0.75rem 0',
              color: 'var(--success)'
            }}
            title="Certifications: ISO 9001 & ISO 27001"
          >
            <ShieldCheck size={20} />
          </div>
        ) : (
          <>
            <div
              style={{
                background: 'linear-gradient(145deg, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0.01) 100%)',
                padding: '0.5rem 0.75rem',
                borderRadius: '0.75rem',
                border: '1px solid rgba(255,255,255,0.05)',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.2)'
              }}
            >
              <div
                className="notranslate"
                style={{
                  background: 'linear-gradient(135deg, var(--success), #3b82f6)',
                  borderRadius: '0.375rem',
                  width: '28px',
                  height: '28px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontWeight: 'bold',
                  fontSize: '0.6rem',
                  color: 'white',
                  boxShadow: '0 0 10px rgba(16, 185, 129, 0.3)',
                  flexShrink: 0
                }}
              >
                ISO
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                <span style={{ fontSize: '0.7rem', fontWeight: '600', color: 'var(--text-main)', letterSpacing: '0.02em', whiteSpace: 'nowrap' }}>ISO 9001:2015</span>
                <span style={{ fontSize: '0.6rem', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>Quality Management</span>
              </div>
            </div>

            <div
              style={{
                background: 'linear-gradient(145deg, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0.01) 100%)',
                padding: '0.5rem 0.75rem',
                borderRadius: '0.75rem',
                border: '1px solid rgba(255,255,255,0.05)',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.2)'
              }}
            >
              <div
                className="notranslate"
                style={{
                  background: 'linear-gradient(135deg, var(--accent-primary), var(--accent-secondary))',
                  borderRadius: '0.375rem',
                  width: '28px',
                  height: '28px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontWeight: 'bold',
                  fontSize: '0.6rem',
                  color: 'white',
                  boxShadow: '0 0 10px rgba(99, 102, 241, 0.3)',
                  flexShrink: 0
                }}
              >
                SEC
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                <span style={{ fontSize: '0.7rem', fontWeight: '600', color: 'var(--text-main)', letterSpacing: '0.02em', whiteSpace: 'nowrap' }}>ISO 27001:2022</span>
                <span style={{ fontSize: '0.6rem', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>Information Security</span>
              </div>
            </div>
          </>
        )}
      </div>
    </aside>
  );
}

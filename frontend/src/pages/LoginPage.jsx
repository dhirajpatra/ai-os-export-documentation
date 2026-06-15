import React, { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { toast } from 'sonner';
import { useAppStore } from '../store/useAppStore';
import { LogIn, Mail, Lock, Info, Building2 } from 'lucide-react';
import { API_BASE } from '../config';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [showDemoModal, setShowDemoModal] = useState(false);
  const [demoPhoneCode, setDemoPhoneCode] = useState('+91');
  const [demoPhone, setDemoPhone] = useState('');
  const [orgName, setOrgName] = useState('');
  const login = useAppStore(state => state.login);
  const navigate = useNavigate();
  const location = useLocation();

  const loginWithGoogle = () => {
    window.location.href = `${API_BASE}/api/v1/auth/google/login`;
  };

  const handlePhoneChange = (e) => {
    let val = e.target.value.replace(/\D/g, '');
    if (demoPhoneCode === '+91') {
      if (val.length > 10) val = val.slice(0, 10);
      if (val.length > 5) {
        val = `${val.slice(0, 5)} ${val.slice(5)}`;
      }
    } else if (demoPhoneCode === '+971') {
      if (val.length > 9) val = val.slice(0, 9);
      if (val.length > 2 && val.length <= 5) {
        val = `${val.slice(0, 2)} ${val.slice(2)}`;
      } else if (val.length > 5) {
        val = `${val.slice(0, 2)} ${val.slice(2, 5)} ${val.slice(5)}`;
      }
    }
    setDemoPhone(val);
  };

  const handlePhoneCodeChange = (e) => {
    setDemoPhoneCode(e.target.value);
    setDemoPhone('');
  };

  const handleDemoSubmit = async (e) => {
    e.preventDefault();
    const form = e.target;
    const formData = new FormData(form);

    setLoading(true);
    try {
      const response = await fetch('https://formspree.io/f/xjgzpkjb', {
        method: 'POST',
        headers: {
          'Accept': 'application/json'
        },
        body: formData
      });

      if (response.ok) {
        toast.success('Demo request submitted successfully! Our team will contact you shortly.');
        setShowDemoModal(false);
        form.reset();
      } else {
        throw new Error('Submission failed');
      }
    } catch (error) {
      console.error('Formspree Error:', error);
      toast.error('Failed to submit demo request. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async (e) => {
    e.preventDefault();
    if (!email || !password) {
      toast.error('Please enter both email and password');
      return;
    }

    setLoading(true);
    try {
      const response = await fetch(`${API_BASE}/api/v1/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password })
      });
      const data = await response.json().catch(() => ({}));

      if (!response.ok) {
        throw new Error(data.detail || 'Login failed');
      }

      // Store in AppStore
      localStorage.setItem('user_info', JSON.stringify(data.user));
      login(data.user, data.access_token);

      toast.success('Welcome back!');

      const from = location.state?.from?.pathname || '/dashboard';
      navigate(from, { replace: true });
    } catch (error) {
      console.error('Login error:', error);
      toast.error(error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-main-wrapper animate-fade-in" style={{ display: 'flex', flexDirection: 'column' }}>
      {/* Background decorations */}
      <div style={{ position: 'absolute', width: '100vw', height: '100vh', pointerEvents: 'none', zIndex: 0 }}>
        <div style={{ position: 'absolute', top: '-10%', left: '-10%', width: '50vw', height: '50vw', background: 'radial-gradient(circle, rgba(0, 229, 255, 0.05) 0%, transparent 70%)', borderRadius: '50%' }} />
        <div style={{ position: 'absolute', bottom: '-20%', right: '-10%', width: '60vw', height: '60vw', background: 'radial-gradient(circle, rgba(0, 176, 255, 0.05) 0%, transparent 70%)', borderRadius: '50%' }} />
      </div>

      <div style={{ position: 'relative', zIndex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', width: '100%', padding: '2rem', margin: 'auto' }}>

        {/* Centered Logo */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: '2rem' }}>
          <img src="/logo.jpeg" alt="TradeOS Logo" style={{ width: '48px', height: '48px', borderRadius: '0.75rem', border: '1px solid rgba(99, 102, 241, 0.3)', marginBottom: '0.75rem' }} />
          <span style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'white', letterSpacing: '0.05em' }}>TradeOS</span>
        </div>

        <div className="login-card" style={{ margin: '0 auto' }}>
          <div className="flex-center" style={{ flexDirection: 'column', marginBottom: '1.75rem' }}>
            <h1 className="text-3xl text-gradient text-center" style={{ fontWeight: 700 }}>Welcome Back</h1>
            <p className="text-muted mt-1.5 text-center text-sm">Sign in to access your dashboard</p>
          </div>

          <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '1.15rem' }}>
            <div>
              <label className="text-muted text-xs mb-1" style={{ display: 'block', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>Email</label>
              <div style={{ position: 'relative' }}>
                <Mail size={18} color="var(--text-muted)" style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)' }} />
                <input
                  type="email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  placeholder="name@example.com"
                  style={{ width: '100%', padding: '0.75rem 1rem 0.75rem 2.5rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'white', borderRadius: '0.5rem', outline: 'none', transition: 'border-color 0.3s', boxSizing: 'border-box' }}
                  onFocus={(e) => e.target.style.borderColor = 'var(--accent-primary)'}
                  onBlur={(e) => e.target.style.borderColor = 'var(--border-color)'}
                />
              </div>
            </div>

            <div>
              <label className="text-muted text-xs mb-1" style={{ display: 'block', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>Password</label>
              <div style={{ position: 'relative' }}>
                <Lock size={18} color="var(--text-muted)" style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)' }} />
                <input
                  type="password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="••••••••"
                  style={{ width: '100%', padding: '0.75rem 1rem 0.75rem 2.5rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'white', borderRadius: '0.5rem', outline: 'none', transition: 'border-color 0.3s', boxSizing: 'border-box' }}
                  onFocus={(e) => e.target.style.borderColor = 'var(--accent-primary)'}
                  onBlur={(e) => e.target.style.borderColor = 'var(--border-color)'}
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              style={{
                marginTop: '1rem', width: '100%', padding: '0.85rem', borderRadius: '0.5rem',
                background: 'linear-gradient(135deg, var(--accent-primary), var(--accent-secondary))',
                color: 'var(--bg-dark)', fontWeight: 'bold', border: 'none', cursor: loading ? 'not-allowed' : 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem',
                transition: 'transform 0.2s', opacity: loading ? 0.7 : 1
              }}
              onMouseOver={e => !loading && (e.currentTarget.style.transform = 'translateY(-2px)')}
              onMouseOut={e => !loading && (e.currentTarget.style.transform = 'translateY(0)')}
            >
              {loading ? 'Authenticating...' : (
                <>
                  Sign In
                  <LogIn size={18} />
                </>
              )}
            </button>
          </form>

          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', width: '100%', margin: '1.5rem 0' }}>
            <div style={{ flex: 1, height: '1px', background: 'rgba(255,255,255,0.1)' }} />
            <span className="text-muted text-xs" style={{ textTransform: 'uppercase', letterSpacing: '0.05em' }}>OR</span>
            <div style={{ flex: 1, height: '1px', background: 'rgba(255,255,255,0.1)' }} />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', width: '100%' }}>
            <div>
              <label className="text-muted text-xs mb-1" style={{ display: 'block', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>Organization Name (Optional for existing users)</label>
              <div style={{ position: 'relative' }}>
                <Building2 size={18} color="var(--text-muted)" style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)' }} />
                <input
                  type="text"
                  value={orgName}
                  onChange={e => setOrgName(e.target.value)}
                  placeholder="My Company"
                  style={{ width: '100%', padding: '0.75rem 1rem 0.75rem 2.5rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'white', borderRadius: '0.5rem', outline: 'none', transition: 'border-color 0.3s', boxSizing: 'border-box' }}
                  onFocus={(e) => e.target.style.borderColor = 'var(--accent-primary)'}
                  onBlur={(e) => e.target.style.borderColor = 'var(--border-color)'}
                />
              </div>
            </div>

            <button
              type="button"
              onClick={() => loginWithGoogle()}
              disabled={loading}
              style={{
                width: '100%', padding: '0.85rem', borderRadius: '0.5rem',
                background: 'white', color: '#333', fontWeight: 'bold', border: 'none', cursor: loading ? 'not-allowed' : 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem',
                transition: 'transform 0.2s', opacity: loading ? 0.7 : 1
              }}
              onMouseOver={e => !loading && (e.currentTarget.style.transform = 'translateY(-2px)')}
              onMouseOut={e => !loading && (e.currentTarget.style.transform = 'translateY(0)')}
            >
              <svg width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
                <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
                <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05" />
                <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
              </svg>
              Sign in with Google
            </button>
          </div>
        </div>

        {/* Request Demo Section */}
        <div className="login-contact-box" style={{
          marginTop: '1.5rem', width: '100%', maxWidth: '400px',
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '1rem'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', width: '100%' }}>
            <div style={{ flex: 1, height: '1px', background: 'rgba(255,255,255,0.05)' }} />
            <span className="text-muted text-xs" style={{ textTransform: 'uppercase', letterSpacing: '0.05em' }}>New to TradeOS?</span>
            <div style={{ flex: 1, height: '1px', background: 'rgba(255,255,255,0.05)' }} />
          </div>

          <button
            type="button"
            onClick={() => setShowDemoModal(true)}
            style={{
              width: '100%', padding: '0.85rem', borderRadius: '0.5rem',
              background: 'rgba(0, 229, 255, 0.05)', border: '1px solid rgba(0, 229, 255, 0.2)',
              color: 'var(--accent-primary)', fontWeight: '600', cursor: 'pointer',
              transition: 'all 0.2s', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '0.5rem'
            }}
            onMouseOver={e => { e.currentTarget.style.background = 'rgba(0, 229, 255, 0.15)'; e.currentTarget.style.transform = 'translateY(-2px)' }}
            onMouseOut={e => { e.currentTarget.style.background = 'rgba(0, 229, 255, 0.05)'; e.currentTarget.style.transform = 'translateY(0)' }}
          >
            <Info size={16} />
            Request a Demo
          </button>
        </div>

      </div>

      {/* Demo Request Modal */}
      {showDemoModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.8)', backdropFilter: 'blur(10px)',
          display: 'flex', justifyContent: 'center', alignItems: 'center',
          zIndex: 100, padding: '1rem'
        }}>
          <div className="card animate-fade-in" style={{ width: '100%', maxWidth: '550px', maxHeight: '90vh', overflowY: 'auto', position: 'relative', border: '1px solid rgba(0, 229, 255, 0.2)' }}>
            <button
              onClick={() => setShowDemoModal(false)}
              style={{ position: 'absolute', top: '1rem', right: '1rem', background: 'transparent', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', fontSize: '1.5rem', transition: 'color 0.2s', zIndex: 10 }}
              onMouseOver={e => e.currentTarget.style.color = 'white'}
              onMouseOut={e => e.currentTarget.style.color = 'var(--text-muted)'}
            >
              &times;
            </button>
            <h2 className="text-2xl text-gradient mb-2" style={{ fontWeight: 700 }}>Talk with our product experts</h2>
            <p className="text-muted text-sm mb-6">Curious how TradeOS can help your organization? Get in touch with our team to learn more.</p>

            <form onSubmit={handleDemoSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.15rem' }}>
              <div style={{ display: 'flex', gap: '1rem' }}>
                <div style={{ flex: 1 }}>
                  <label className="text-muted text-xs mb-1" style={{ display: 'block', fontWeight: 600 }}>First name *</label>
                  <input name="firstName" required type="text" style={{ width: '100%', padding: '0.75rem 1rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'white', borderRadius: '0.5rem', outline: 'none' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'} />
                </div>
                <div style={{ flex: 1 }}>
                  <label className="text-muted text-xs mb-1" style={{ display: 'block', fontWeight: 600 }}>Last name *</label>
                  <input name="lastName" required type="text" style={{ width: '100%', padding: '0.75rem 1rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'white', borderRadius: '0.5rem', outline: 'none' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'} />
                </div>
              </div>

              <div style={{ display: 'flex', gap: '1rem' }}>
                <div style={{ flex: 1 }}>
                  <label className="text-muted text-xs mb-1" style={{ display: 'block', fontWeight: 600 }}>Work email *</label>
                  <input name="email" required type="email" style={{ width: '100%', padding: '0.75rem 1rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'white', borderRadius: '0.5rem', outline: 'none' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'} />
                </div>
                <div style={{ flex: 1 }}>
                  <label className="text-muted text-xs mb-1" style={{ display: 'block', fontWeight: 600 }}>Country/Region *</label>
                  <select name="country" required style={{ width: '100%', padding: '0.75rem 1rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'var(--text-main)', borderRadius: '0.5rem', outline: 'none', appearance: 'none' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'}>
                    <option value="" style={{ background: '#0f0f16', color: '#fff' }}>Please Select</option>
                    <option value="IN" style={{ background: '#0f0f16', color: '#fff' }}>India</option>
                    <option value="AE" style={{ background: '#0f0f16', color: '#fff' }}>United Arab Emirates</option>
                    <option value="Other" style={{ background: '#0f0f16', color: '#fff' }}>Other</option>
                  </select>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '1rem' }}>
                <div style={{ flex: 1 }}>
                  <label className="text-muted text-xs mb-1" style={{ display: 'block', fontWeight: 600 }}>What's your role? *</label>
                  <select name="role" required style={{ width: '100%', padding: '0.75rem 1rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'var(--text-main)', borderRadius: '0.5rem', outline: 'none', appearance: 'none' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'}>
                    <option value="" style={{ background: '#0f0f16', color: '#fff' }}>Please Select</option>
                    <option value="Freight Forwarder" style={{ background: '#0f0f16', color: '#fff' }}>Freight Forwarder</option>
                    <option value="Carrier" style={{ background: '#0f0f16', color: '#fff' }}>Carrier</option>
                    <option value="Shipper / Exporter" style={{ background: '#0f0f16', color: '#fff' }}>Shipper / Exporter</option>
                    <option value="Other" style={{ background: '#0f0f16', color: '#fff' }}>Other</option>
                  </select>
                </div>
                <div style={{ flex: 1 }}>
                  <label className="text-muted text-xs mb-1" style={{ display: 'block', fontWeight: 600 }}>Company name *</label>
                  <input name="company" required type="text" style={{ width: '100%', padding: '0.75rem 1rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'white', borderRadius: '0.5rem', outline: 'none' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'} />
                </div>
              </div>

              <div>
                <label className="text-muted text-xs mb-1" style={{ display: 'block', fontWeight: 600 }}>Company type *</label>
                <select name="companyType" required style={{ width: '100%', padding: '0.75rem 1rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'var(--text-main)', borderRadius: '0.5rem', outline: 'none', appearance: 'none' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'}>
                  <option value="" style={{ background: '#0f0f16', color: '#fff' }}>Please Select</option>
                  <option value="Logistics Provider" style={{ background: '#0f0f16', color: '#fff' }}>Logistics Provider</option>
                  <option value="Airline / Ocean Carrier" style={{ background: '#0f0f16', color: '#fff' }}>Airline / Ocean Carrier</option>
                  <option value="Manufacturer" style={{ background: '#0f0f16', color: '#fff' }}>Manufacturer</option>
                  <option value="Enterprise" style={{ background: '#0f0f16', color: '#fff' }}>Enterprise</option>
                </select>
              </div>

              <div>
                <label className="text-muted text-xs mb-1" style={{ display: 'block', fontWeight: 600 }}>Phone number *</label>
                <div style={{ display: 'flex', gap: '0.5rem' }}>
                  <select name="phoneCode" value={demoPhoneCode} onChange={handlePhoneCodeChange} required style={{ width: '130px', padding: '0.75rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'var(--text-main)', borderRadius: '0.5rem', outline: 'none', appearance: 'none' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'}>
                    <option value="" style={{ background: '#0f0f16', color: '#fff' }}>Code</option>
                    <option value="+91" style={{ background: '#0f0f16', color: '#fff' }}>India (+91)</option>
                    <option value="+971" style={{ background: '#0f0f16', color: '#fff' }}>UAE (+971)</option>
                  </select>
                  <input name="phone" value={demoPhone} onChange={handlePhoneChange} placeholder={demoPhoneCode === '+91' ? '98765 43210' : '50 123 4567'} required type="tel" style={{ flex: 1, padding: '0.75rem 1rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'white', borderRadius: '0.5rem', outline: 'none' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'} />
                </div>
              </div>

              <div>
                <label className="text-muted text-xs mb-1" style={{ display: 'block', fontWeight: 600 }}>What are you interested in learning about? *</label>
                <select name="interest" required style={{ width: '100%', padding: '0.75rem 1rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'var(--text-main)', borderRadius: '0.5rem', outline: 'none', appearance: 'none' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'}>
                  <option value="" style={{ background: '#0f0f16', color: '#fff' }}>Please Select</option>
                  <option value="AI Agent Orchestration" style={{ background: '#0f0f16', color: '#fff' }}>AI Agent Orchestration</option>
                  <option value="Automated PO Extraction" style={{ background: '#0f0f16', color: '#fff' }}>Automated PO Extraction</option>
                  <option value="Customs Compliance" style={{ background: '#0f0f16', color: '#fff' }}>Customs & HS Code Compliance</option>
                  <option value="General Platform Demo" style={{ background: '#0f0f16', color: '#fff' }}>General Platform Demo</option>
                </select>
              </div>

              <div>
                <label className="text-muted text-xs mb-1" style={{ display: 'block', fontWeight: 600 }}>What else would you like to discuss? *</label>
                <textarea name="comments" required rows="3" style={{ width: '100%', padding: '0.75rem 1rem', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)', color: 'white', borderRadius: '0.5rem', outline: 'none', resize: 'vertical' }} onFocus={e => e.target.style.borderColor = 'var(--accent-primary)'} onBlur={e => e.target.style.borderColor = 'var(--border-color)'}></textarea>
              </div>

              <button
                type="submit"
                disabled={loading}
                style={{
                  marginTop: '0.5rem', width: '100%', padding: '0.85rem', borderRadius: '0.5rem',
                  background: 'linear-gradient(135deg, var(--accent-primary), var(--accent-secondary))', color: 'var(--bg-dark)',
                  fontWeight: 'bold', border: 'none', cursor: loading ? 'not-allowed' : 'pointer', transition: 'transform 0.2s',
                  opacity: loading ? 0.7 : 1
                }}
                onMouseOver={e => !loading && (e.currentTarget.style.transform = 'translateY(-2px)')}
                onMouseOut={e => !loading && (e.currentTarget.style.transform = 'translateY(0)')}
              >
                {loading ? 'Submitting...' : 'Request a Demo'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

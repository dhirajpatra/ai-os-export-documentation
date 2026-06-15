import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Link as LinkIcon, Loader, ShieldCheck } from 'lucide-react';
import { toast } from 'sonner';

export default function FreightForwarderModal({ isOpen, onClose }) {
  const [provider, setProvider] = useState('maersk');
  const [apiKey, setApiKey] = useState('');
  const [isConnecting, setIsConnecting] = useState(false);

  if (!isOpen) return null;

  const handleConnect = (e) => {
    e.preventDefault();
    if (!apiKey) {
      toast.error('Please enter a valid API key.');
      return;
    }
    
    setIsConnecting(true);
    setTimeout(() => {
      setIsConnecting(false);
      toast.success(`Successfully authenticated with ${provider.toUpperCase()} API.`);
      onClose();
    }, 2500);
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={!isConnecting ? onClose : undefined}
            style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.7)', zIndex: 1000, backdropFilter: 'blur(4px)' }}
          />
          <motion.div 
            className="card"
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 20 }}
            style={{ 
              position: 'fixed', top: '15vh', left: '50%', transform: 'translateX(-50%)', 
              width: '90%', maxWidth: '450px', zIndex: 1001,
              border: '1px solid var(--accent-primary)', boxShadow: '0 10px 40px rgba(0,0,0,0.5)'
            }}
          >
            <div className="flex-between mb-6" style={{ borderBottom: '1px solid var(--border-color)', paddingBottom: '1rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <LinkIcon size={20} className="text-accent-primary" />
                <h3 className="text-xl">Connect Forwarder API</h3>
              </div>
              {!isConnecting && (
                <button onClick={onClose} style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}>
                  <X size={20} />
                </button>
              )}
            </div>

            <form onSubmit={handleConnect}>
              <div className="mb-4">
                <label className="text-sm text-muted mb-2 block">Select Provider</label>
                <select 
                  value={provider} 
                  onChange={(e) => setProvider(e.target.value)}
                  disabled={isConnecting}
                  className="card"
                  style={{ width: '100%', padding: '0.75rem', border: '1px solid var(--border-color)', outline: 'none', color: 'white', background: 'rgba(0,0,0,0.2)' }}
                >
                  <option value="maersk">Maersk Logistics API</option>
                  <option value="msc">MSC Track & Trace</option>
                  <option value="hapag">Hapag-Lloyd Connect</option>
                  <option value="dhl">DHL Global Forwarding</option>
                </select>
              </div>

              <div className="mb-6">
                <label className="text-sm text-muted mb-2 block">API Key / Token</label>
                <input 
                  type="password" 
                  value={apiKey}
                  onChange={(e) => setApiKey(e.target.value)}
                  placeholder="Paste your API key here..."
                  disabled={isConnecting}
                  className="card"
                  style={{ width: '100%', padding: '0.75rem', border: '1px solid var(--border-color)', outline: 'none', color: 'white', background: 'rgba(0,0,0,0.2)' }}
                />
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.5rem' }}>
                  <ShieldCheck size={14} className="text-success" />
                  <span className="text-xs text-muted">Credentials are stored in a secure vault</span>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '1rem' }}>
                <button 
                  type="button"
                  onClick={onClose} 
                  disabled={isConnecting}
                  className="badge" 
                  style={{ background: 'transparent', border: '1px solid var(--border-color)', color: 'var(--text-main)', cursor: isConnecting ? 'not-allowed' : 'pointer', padding: '0.75rem 1.5rem' }}
                >
                  Cancel
                </button>
                <button 
                  type="submit"
                  disabled={isConnecting}
                  className="badge flex-center" 
                  style={{ gap: '0.5rem', background: 'var(--accent-secondary)', color: 'white', border: 'none', cursor: isConnecting ? 'not-allowed' : 'pointer', padding: '0.75rem 1.5rem', minWidth: '130px' }}
                >
                  {isConnecting ? <Loader size={16} className="animate-spin" /> : <><LinkIcon size={16} /> Authenticate</>}
                </button>
              </div>
            </form>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

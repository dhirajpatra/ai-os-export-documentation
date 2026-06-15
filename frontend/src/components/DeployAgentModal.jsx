import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Server, BrainCircuit, Loader } from 'lucide-react';
import { toast } from 'sonner';

export default function DeployAgentModal({ isOpen, onClose, onDeploy }) {
  const [selectedAgent, setSelectedAgent] = useState('compliance');
  const [isDeploying, setIsDeploying] = useState(false);

  if (!isOpen) return null;

  const handleDeploy = () => {
    setIsDeploying(true);
    setTimeout(() => {
      setIsDeploying(false);
      toast.success(`Successfully deployed ${selectedAgent} agent to production cluster.`);
      onClose();
      if(onDeploy) onDeploy(selectedAgent);
    }, 2000);
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={!isDeploying ? onClose : undefined}
            style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.7)', zIndex: 1000, backdropFilter: 'blur(4px)' }}
          />
          <motion.div 
            className="card"
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 20 }}
            style={{ 
              position: 'fixed', top: '15vh', left: '50%', transform: 'translateX(-50%)', 
              width: '90%', maxWidth: '500px', zIndex: 1001,
              border: '1px solid var(--accent-primary)', boxShadow: '0 10px 40px rgba(0,0,0,0.5)'
            }}
          >
            <div className="flex-between mb-6" style={{ borderBottom: '1px solid var(--border-color)', paddingBottom: '1rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <Server size={20} className="text-accent-primary" />
                <h3 className="text-xl">Deploy AI Agent</h3>
              </div>
              {!isDeploying && (
                <button onClick={onClose} style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}>
                  <X size={20} />
                </button>
              )}
            </div>

            <div className="mb-6">
              <p className="text-muted mb-4 text-sm">Select a specialized agent model to deploy into your orchestration layer.</p>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '1rem', border: `1px solid ${selectedAgent === 'compliance' ? 'var(--accent-primary)' : 'var(--border-color)'}`, borderRadius: '0.5rem', cursor: 'pointer', background: selectedAgent === 'compliance' ? 'rgba(99, 102, 241, 0.1)' : 'transparent' }}>
                  <input type="radio" name="agent_type" value="compliance" checked={selectedAgent === 'compliance'} onChange={() => setSelectedAgent('compliance')} style={{ cursor: 'pointer' }} disabled={isDeploying}/>
                  <div>
                    <strong style={{ display: 'block' }}>Compliance & Sanctions Agent</strong>
                    <span className="text-muted text-sm">Validates DGFT restricted lists and global sanctions.</span>
                  </div>
                </label>

                <label style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '1rem', border: `1px solid ${selectedAgent === 'finance' ? 'var(--accent-primary)' : 'var(--border-color)'}`, borderRadius: '0.5rem', cursor: 'pointer', background: selectedAgent === 'finance' ? 'rgba(99, 102, 241, 0.1)' : 'transparent' }}>
                  <input type="radio" name="agent_type" value="finance" checked={selectedAgent === 'finance'} onChange={() => setSelectedAgent('finance')} style={{ cursor: 'pointer' }} disabled={isDeploying}/>
                  <div>
                    <strong style={{ display: 'block' }}>Letter of Credit (LC) Agent</strong>
                    <span className="text-muted text-sm">Extracts banking terms and matches conditions autonomously.</span>
                  </div>
                </label>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '1rem' }}>
              <button 
                onClick={onClose} 
                disabled={isDeploying}
                className="badge" 
                style={{ background: 'transparent', border: '1px solid var(--border-color)', color: 'var(--text-main)', cursor: isDeploying ? 'not-allowed' : 'pointer', padding: '0.75rem 1.5rem' }}
              >
                Cancel
              </button>
              <button 
                onClick={handleDeploy} 
                disabled={isDeploying}
                className="badge flex-center" 
                style={{ gap: '0.5rem', background: 'var(--accent-primary)', color: 'white', border: 'none', cursor: isDeploying ? 'not-allowed' : 'pointer', padding: '0.75rem 1.5rem', minWidth: '120px' }}
              >
                {isDeploying ? <Loader size={16} className="animate-spin" /> : <><BrainCircuit size={16} /> Deploy</>}
              </button>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

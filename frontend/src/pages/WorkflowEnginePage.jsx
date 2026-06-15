import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Check, Loader, Search, ArrowLeft, AlertCircle } from 'lucide-react';
import { API_BASE } from '../config';
import { apiFetch } from '../api';

export default function WorkflowEnginePage() {
  const [workflows, setWorkflows] = useState([]);
  const [activeApprovals, setActiveApprovals] = useState([]);
  const [selectedWorkflowId, setSelectedWorkflowId] = useState(null);
  const [workflowDetails, setWorkflowDetails] = useState(null);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  const fetchWorkflowsList = async () => {
    try {
      const [wfRes, appRes] = await Promise.all([
        apiFetch(`${API_BASE}/api/v1/workflows`),
        apiFetch(`${API_BASE}/api/v1/approvals?status_filter=pending`)
      ]);
      
      if (wfRes.ok) {
        const data = await wfRes.json();
        setWorkflows(data.workflows || []);
      }
      if (appRes.ok) {
        const data = await appRes.json();
        setActiveApprovals(data.approvals || []);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const fetchWorkflowDetails = async (id) => {
    setLoading(true);
    try {
      const res = await apiFetch(`${API_BASE}/api/v1/workflows/${id}`);
      if (res.ok) {
        const data = await res.json();
        setWorkflowDetails(data);
      } else {
        setWorkflowDetails(null);
      }
    } catch (e) {
      console.error(e);
      setWorkflowDetails(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!selectedWorkflowId && !searchQuery) {
      fetchWorkflowsList();
      const interval = setInterval(fetchWorkflowsList, 5000);
      return () => clearInterval(interval);
    }
  }, [selectedWorkflowId, searchQuery]);

  useEffect(() => {
    if (selectedWorkflowId) {
      fetchWorkflowDetails(selectedWorkflowId);
      const interval = setInterval(() => fetchWorkflowDetails(selectedWorkflowId), 5000);
      return () => clearInterval(interval);
    }
  }, [selectedWorkflowId]);

  useEffect(() => {
    const handleSidebarClick = (e) => {
      if (e.detail === '/workflow') {
        setSelectedWorkflowId(null);
        setSearchQuery('');
        setWorkflowDetails(null);
      }
    };
    window.addEventListener('sidebar_click', handleSidebarClick);
    return () => window.removeEventListener('sidebar_click', handleSidebarClick);
  }, []);

  const handleSearch = (e) => {
    e.preventDefault();
    const query = searchQuery.trim();
    if (query) {
      let q = query.toLowerCase();
      if (q.startsWith('wa-')) q = q.substring(3);
      
      const found = workflows.find(w => w.id.toLowerCase().startsWith(q) || (w.name && w.name.toLowerCase().includes(q)));
      if (found) {
        setSelectedWorkflowId(found.id);
      } else {
        setSelectedWorkflowId(query);
      }
    }
  };

  if (loading && !workflows.length && !workflowDetails) {
    return (
      <div className="p-8 animate-pulse">
        <h2 className="text-4xl text-gradient mb-8">Workflow Engine</h2>
        <div className="card text-muted">Connecting to orchestration layer...</div>
      </div>
    );
  }

  // Details View
  if (selectedWorkflowId || workflowDetails) {
    let steps = workflowDetails?.steps || [];
    
    let isOrphaned = false;
    let isStalled = false;
    let displayStatus = workflowDetails?.current_step?.replace(/_/g, ' ') || 'Processing';
    let statusColor = 'text-success';

    if (workflowDetails) {
      const wfId = workflowDetails.id || selectedWorkflowId || '';
      const shortRef = "WA-" + wfId.substring(0, 8).toUpperCase();
      const hasActiveApproval = activeApprovals.some(appr => appr.title && appr.title.includes(shortRef));
      isOrphaned = workflowDetails.status === 'awaiting_human' && !hasActiveApproval;
      const startedAt = new Date(workflowDetails.started_at || Date.now());
      isStalled = workflowDetails.status === 'running' && (new Date() - startedAt) > 5 * 60 * 1000;

      if (isOrphaned) {
        displayStatus = 'Expired / Dropped';
        statusColor = 'text-error';
      } else if (isStalled) {
        displayStatus = 'Timeout / Stalled';
        statusColor = 'text-error';
      } else if (workflowDetails.status === 'completed') {
        displayStatus = 'Completed';
        statusColor = 'text-success';
      } else if (workflowDetails.status === 'awaiting_human') {
        statusColor = 'text-warning';
      }
    }
    
    // We rely entirely on the backend to provide the workflow steps.
    // If backend returns no steps, we handle it gracefully here.
    if (!steps || steps.length === 0) {
      if (workflowDetails) {
        let stepStatus = 'pending';
        if (isOrphaned || isStalled) stepStatus = 'failed';
        else if (workflowDetails.status === 'completed') stepStatus = 'completed';
        else stepStatus = 'active';

        steps = [{
          name: workflowDetails.current_step ? workflowDetails.current_step.replace(/_/g, ' ').toUpperCase() : 'INITIALIZING',
          status: stepStatus,
          time: stepStatus === 'completed' ? 'Done' : (stepStatus === 'active' ? 'In Progress...' : (stepStatus === 'failed' ? 'Failed' : 'Waiting'))
        }];
      }
    }

    return (
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5 }}>
        <div className="mb-8 flex-between">
          <div>
            <h2 className="text-4xl text-gradient">Workflow Engine</h2>
            <p className="text-muted mt-2">Live orchestration details</p>
          </div>
          <button 
            onClick={() => { setSelectedWorkflowId(null); setWorkflowDetails(null); setSearchQuery(''); }}
            className="badge flex-center"
            style={{ gap: '0.5rem', cursor: 'pointer', background: 'transparent', border: '1px solid var(--border-color)', color: 'var(--text-muted)' }}
          >
            <ArrowLeft size={16} /> Back to List
          </button>
        </div>

        {!workflowDetails && !loading ? (
           <div className="card text-muted">Workflow not found.</div>
        ) : (
          <div className="card mb-8">
            <div className="flex-between mb-6">
              <h3 className="text-xl">Active Workflow: {workflowDetails?.shipmentId || selectedWorkflowId}</h3>
              <span className={`badge ${statusColor}`} style={{ color: (isOrphaned || isStalled) ? 'var(--error)' : (workflowDetails?.status === 'awaiting_human' ? 'orange' : '') }}>
                {displayStatus}
              </span>
            </div>

            <div style={{ position: 'relative' }}>
              <div style={{
                position: 'absolute', top: '12px', bottom: '12px', left: '11px',
                width: '2px', background: 'var(--border-color)', zIndex: 0
              }}></div>

              {steps.map((step, index) => {
                const isCompleted = step.status === 'completed';
                const isActive = step.status === 'active';
                const isPending = step.status === 'pending';
                const isFailed = step.status === 'failed';
                
                return (
                  <div key={index} style={{ position: 'relative', zIndex: 1, marginBottom: '2rem', display: 'flex', gap: '1.5rem', alignItems: 'center' }}>
                    <motion.div 
                      initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ delay: index * 0.1 }}
                      className="flex-center"
                      style={{
                        width: '24px', height: '24px', borderRadius: '50%',
                        background: isActive ? 'var(--accent-primary)' : isCompleted ? 'var(--success)' : isFailed ? 'var(--error)' : 'var(--bg-card)',
                        border: `2px solid ${isActive || isCompleted || isFailed ? 'transparent' : 'var(--border-color)'}`,
                        boxShadow: isActive ? '0 0 10px var(--accent-primary)' : isFailed ? '0 0 10px var(--error)' : 'none',
                        flexShrink: 0
                      }}
                    >
                      {isCompleted && <Check size={14} color="white" />}
                      {isActive && <Loader size={14} color="white" className="animate-spin" />}
                      {isFailed && <AlertCircle size={14} color="white" />}
                    </motion.div>
                    
                    <motion.div 
                      initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: index * 0.1 + 0.1 }}
                      className={isActive ? 'active' : ''} 
                      style={{ 
                        flex: 1, 
                        padding: '1rem', 
                        background: 'rgba(255,255,255,0.02)',
                        borderRadius: '0.75rem',
                        border: isActive ? '1px solid var(--accent-primary)' : isFailed ? '1px solid var(--error)' : '1px solid rgba(255,255,255,0.05)', 
                        opacity: isPending ? 0.5 : 1 
                      }}
                    >
                      <div className="flex-between">
                        <h4 className={isActive ? 'text-accent-gradient text-xl' : (isFailed ? 'text-error text-xl' : 'text-xl')}>{step.name}</h4>
                        <span className={isFailed ? 'text-error text-sm' : "text-muted text-sm"}>{step.timestamp || step.time}</span>
                      </div>
                      {isActive && (
                        <div className="mt-4" style={{ padding: '1rem', background: 'rgba(0,0,0,0.2)', borderRadius: '0.5rem' }}>
                          <p className="text-sm text-muted mb-2">&gt; Agent: Workflow_Orchestrator</p>
                          <p className="text-sm mb-2 text-success">&gt; Waiting for next event...</p>
                          <div className="progress-bg mt-2">
                            <motion.div className="progress-fill" initial={{ width: 0 }} animate={{ width: '65%' }} transition={{ duration: 2, repeat: Infinity }}></motion.div>
                          </div>
                        </div>
                      )}
                    </motion.div>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </motion.div>
    );
  }

  // List View
  return (
    <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5 }}>
      <div className="flex-between mb-8">
        <div>
          <h2 className="text-4xl text-gradient">Workflow Engine</h2>
          <p className="text-muted mt-2">Live orchestration of active shipments</p>
        </div>
        <form onSubmit={handleSearch} style={{ position: 'relative', display: 'flex', gap: '0.5rem', flexWrap: 'nowrap', flex: 1, justifyContent: 'flex-end', maxWidth: '100%' }}>
          <div style={{ position: 'relative', flex: 1, minWidth: '100px' }}>
            <Search size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
            <input 
              type="text" 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search by Approval ID or Ref..." 
              className="card"
              style={{ padding: '0.75rem 1rem 0.75rem 2.5rem', border: '1px solid var(--border-color)', outline: 'none', color: 'white', width: '100%', boxSizing: 'border-box' }}
            />
          </div>
          <button type="submit" className="badge flex-center" style={{ background: 'var(--accent-primary)', color: 'white', border: 'none', cursor: 'pointer', flexShrink: 0, whiteSpace: 'nowrap', padding: '0.75rem 1rem' }}>
            Lookup
          </button>
        </form>
      </div>

      <div className="card table-responsive">
        <div className="table-row-group">
          <div className="flex-between text-muted text-sm mb-4" style={{ padding: '0 1rem', borderBottom: '1px solid var(--border-color)', paddingBottom: '1rem' }}>
            <div style={{ flex: 2 }}>Workflow Name</div>
            <div style={{ flex: 1 }}>Status</div>
            <div style={{ flex: 1 }}>Current Step</div>
            <div style={{ flex: 1 }}>Started At</div>
          </div>

          <div className="space-y-2">
            {workflows.length === 0 && !loading ? (
              <p className="text-muted" style={{ padding: '1rem' }}>No active workflows to display. Initiate a shipment first.</p>
            ) : (
              workflows.map((wf, i) => {
                const shortRef = "WA-" + wf.id.substring(0, 8).toUpperCase();
                const hasActiveApproval = activeApprovals.some(appr => appr.title && appr.title.includes(shortRef));
                
                const isOrphaned = wf.status === 'awaiting_human' && !hasActiveApproval;
                
                const startedAt = new Date(wf.started_at);
                const isStale = (new Date() - startedAt) > 5 * 60 * 1000; // 5 mins
                const isStalled = wf.status === 'running' && isStale;

                let displayStatus = wf.status ? wf.status.replace(/_/g, ' ') : '--';
                let statusColor = 'text-accent-primary';

                if (isOrphaned) {
                  displayStatus = 'expired / dropped';
                  statusColor = 'text-error';
                } else if (isStalled) {
                  displayStatus = 'timeout / stalled';
                  statusColor = 'text-error';
                } else if (wf.status === 'completed') {
                  statusColor = 'text-success';
                } else if (wf.status === 'awaiting_human') {
                  statusColor = 'text-warning';
                }
                
                return (
                <motion.div 
                  key={wf.id} 
                  className="flex-between" 
                  initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}
                  style={{ padding: '1rem', borderRadius: '0.5rem', background: 'rgba(255,255,255,0.02)', cursor: 'pointer', border: '1px solid transparent' }}
                  onClick={() => setSelectedWorkflowId(wf.id)}
                  onMouseEnter={(e) => e.currentTarget.style.border = '1px solid var(--accent-primary)'}
                  onMouseLeave={(e) => e.currentTarget.style.border = '1px solid transparent'}
                >
                  <div style={{ flex: 2, display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                    <span className="text-accent-secondary">{wf.name || 'Unnamed Workflow'}</span>
                  </div>
                  <div style={{ flex: 1 }}>
                    <span className={`badge ${statusColor}`} style={{ color: (isOrphaned || isStalled) ? 'var(--error)' : (wf.status === 'awaiting_human' ? 'orange' : '') }}>
                      {displayStatus}
                    </span>
                  </div>
                  <div style={{ flex: 1 }} className="text-muted text-sm">{wf.current_step ? wf.current_step.replace(/_/g, ' ') : '--'}</div>
                  <div style={{ flex: 1 }} className="text-muted text-sm">{wf.started_at ? startedAt.toLocaleString() : '--'}</div>
                </motion.div>
              )})
            )}
          </div>
        </div>
      </div>
    </motion.div>
  );
}

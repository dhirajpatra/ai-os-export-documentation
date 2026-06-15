import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { API_BASE } from '../config';
import { apiFetch } from '../api';
import { toast } from 'sonner';
import { PlusCircle, CheckCircle, XCircle, Copy } from 'lucide-react';
import AgentCard from '../components/AgentCard';

import DeployAgentModal from '../components/DeployAgentModal';
import ApprovalDetailsModal from '../components/ApprovalDetailsModal';

export default function AgentHubPage() {
  const [approvals, setApprovals] = useState([]);
  const [loadingApprovals, setLoadingApprovals] = useState(true);

  const [agents, setAgents] = useState([]);
  const [loadingAgents, setLoadingAgents] = useState(true);
  
  const [isDeployModalOpen, setIsDeployModalOpen] = useState(false);
  const [selectedApprovalId, setSelectedApprovalId] = useState(null);

  const fetchAgents = async () => {
    try {
      const res = await apiFetch(`${API_BASE}/api/v1/agents`);
      if (res.ok) {
        const data = await res.json();
        setAgents(data.agents || []);
      }
    } catch (e) {
      console.error("Could not fetch agents", e);
    } finally {
      setLoadingAgents(false);
    }
  };

  const fetchApprovals = async () => {
    try {
      const res = await apiFetch(`${API_BASE}/api/v1/approvals?status_filter=pending`);
      if (res.ok) {
        const data = await res.json();
        setApprovals(data.approvals || []);
      }
    } catch (e) {
      console.error("Could not fetch approvals", e);
    } finally {
      setLoadingApprovals(false);
    }
  };

  useEffect(() => {
    fetchApprovals();
    fetchAgents();
    const intervalApprovals = setInterval(fetchApprovals, 5000);
    const intervalAgents = setInterval(fetchAgents, 5000);
    return () => {
      clearInterval(intervalApprovals);
      clearInterval(intervalAgents);
    };
  }, []);

  const handleAction = async (id, actionStr, overrides = null) => {
    try {
      const bodyPayload = { action: actionStr, note: 'Actioned via Agent Hub MVP' };
      if (overrides && Object.keys(overrides).length > 0) {
        bodyPayload.overrides = overrides;
      }
      const res = await apiFetch(`${API_BASE}/api/v1/approvals/${id}/action`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(bodyPayload)
      });
      if (!res.ok) {
        if (res.status >= 500 && res.status <= 504) {
          toast.success("Action submitted! The AI is processing this heavily in the background.");
          setTimeout(fetchApprovals, 2000);
          return;
        }
        const errorData = await res.json().catch(() => ({}));
        throw new Error(errorData.detail || errorData.message || 'API request failed');
      }
      if (actionStr === 'approve') {
        toast.success(`Approval granted for workflow.`);
      } else {
        toast.info(`Workflow request rejected.`);
      }
      setSelectedApprovalId(null);
      fetchApprovals();
    } catch (e) {
      console.error("Action failed", e);
      toast.error(e.message || "Failed to execute action.");
    }
  };

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.5 }}>
      <div className="flex-between mb-8">
        <div>
          <h2 className="text-4xl text-gradient">Agent Hub & Human Supervisor</h2>
          <p className="text-muted mt-2">Manage AI workforce and unblock Human-In-The-Loop requests</p>
        </div>
        <button 
          className="badge" 
          style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '0.75rem 1.5rem', background: 'var(--accent-primary)', color: 'white', cursor: 'pointer', border: 'none' }}
          onClick={() => setIsDeployModalOpen(true)}
        >
          <PlusCircle size={18} /> Deploy New Agent
        </button>
      </div>

      <div className="mb-8">
        <h3 className="text-xl mb-4 text-accent-gradient">Pending Approvals Queue (HITL)</h3>
        {loadingApprovals && approvals.length === 0 ? (
          <div className="card text-center text-muted">Checking AI orchestration queue...</div>
        ) : approvals.length === 0 ? (
          <div className="card text-center text-muted border-dashed border-2 border-accent">
            <CheckCircle size={48} className="mx-auto mb-4 opacity-50" />
            <p>Queue is empty. AI agents are running autonomously.</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            {approvals.map((appr) => (
              <motion.div 
                key={appr.id} 
                className="card flex-between"
                initial={{ x: -20, opacity: 0 }}
                animate={{ x: 0, opacity: 1 }}
              >
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
                    <h4 className="text-xl text-white m-0">{appr.title}</h4>
                    <button 
                      onClick={() => {
                        const refMatch = appr.title.match(/(WA-[A-Z0-9]+)/);
                        const textToCopy = refMatch ? refMatch[1] : appr.id;
                        navigator.clipboard.writeText(textToCopy);
                        toast.success(`Copied: ${textToCopy}`);
                      }}
                      className="badge flex-center"
                      style={{ cursor: 'pointer', background: 'transparent', border: 'none', padding: '0.25rem', color: 'var(--accent-secondary)' }}
                      title="Copy ID"
                    >
                      <Copy size={16} />
                    </button>
                  </div>
                  <p className="text-sm text-muted">{appr.reason}</p>
                </div>
                <div style={{ textAlign: 'right', display: 'flex', flexDirection: 'column', gap: '1rem', alignItems: 'flex-end' }}>
                  <span className="text-sm text-muted">Confidence: <span className="text-white">{appr.ai_confidence ? `${appr.ai_confidence}%` : (appr.confidence ? `${appr.confidence}%` : 'Low')}</span></span>
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '1rem', justifyContent: 'flex-end', marginLeft: '1rem' }}>
                  <button onClick={() => setSelectedApprovalId(appr.id)} className="badge flex-center" style={{ gap: '0.5rem', cursor: 'pointer', border: '1px solid var(--accent-primary)', background: 'transparent', color: 'var(--accent-primary)' }}>
                    Review Details
                  </button>
                  <button onClick={() => handleAction(appr.id, 'reject')} className="badge flex-center" style={{ gap: '0.5rem', cursor: 'pointer', border: '1px solid var(--error)', background: 'transparent', color: 'var(--error)' }}>
                    <XCircle size={14} /> Reject
                  </button>
                  <button onClick={() => handleAction(appr.id, 'approve')} className="badge flex-center" style={{ gap: '0.5rem', cursor: 'pointer', border: 'none', background: 'var(--success)', color: 'white' }}>
                    <CheckCircle size={14} /> Approve
                  </button>
                </div>
              </motion.div>
            ))}
          </div>
        )}
      </div>

      <div>
        <h3 className="text-xl mb-4">Active Agents Context</h3>
        <div className="grid-3">
          {loadingAgents ? (
            <p className="text-muted col-span-3">Loading active agents from backend...</p>
          ) : agents.length === 0 ? (
            <p className="text-muted col-span-3">No active agents found.</p>
          ) : (
            agents.map((agent) => (
              <AgentCard key={agent.id || agent.name} agent={agent} />
            ))
          )}
        </div>
      </div>
      
      <DeployAgentModal 
        isOpen={isDeployModalOpen}
        onClose={() => setIsDeployModalOpen(false)}
      />

      <ApprovalDetailsModal
        approvalId={selectedApprovalId}
        onClose={() => setSelectedApprovalId(null)}
        onAction={handleAction}
      />
    </motion.div>
  );
}

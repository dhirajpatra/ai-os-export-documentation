import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { Package, FileText, ShieldCheck, Zap, ChevronRight, ChevronLeft, CheckCircle, Loader2, Circle, UploadCloud, AlertCircle } from 'lucide-react';
import { API_BASE } from '../config';
import { apiFetch } from '../api';
import MetricCard from '../components/MetricCard';
import AgentCard from '../components/AgentCard';
import WorkflowNode from '../components/WorkflowNode';
import ThroughputChart from '../components/ThroughputChart';
import { useAppStore } from '../store/useAppStore';

export default function DashboardPage() {
  const navigate = useNavigate();
  
  // Capture and Save the SSO Token on Dashboard Mount
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const ssoToken = urlParams.get('token');
    if (ssoToken) {
      localStorage.setItem('access_token', ssoToken);
      const cleanUrl = window.location.pathname;
      window.history.replaceState({}, document.title, cleanUrl);
    }
  }, []);

  const [poText, setPoText] = useState('');
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [result, setResult] = useState(null);
  const [liveSteps, setLiveSteps] = useState([]);
  const fileInputRef = useRef(null);

  const [templates, setTemplates] = useState([
    { name: 'Al Rashid Trading Co.', shipments: 47, confidence: '94%', last: '2 days ago' },
    { name: 'Khalid Exports LLC', shipments: 12, confidence: '87%', last: '1 week ago' },
    { name: 'New Star General Trading', shipments: 3, confidence: '71%', last: 'Learning...' }
  ]);

  const language = useAppStore(state => state.language);
  const isRTL = language?.toLowerCase() === 'ar';

  const [agents, setAgents] = useState([]);
  const [shipments, setShipments] = useState([]);
  const [documents, setDocuments] = useState([]);

  // Calculate dynamic metrics from live agents
  const complianceSuccess = agents.length > 0
    ? (agents.find(a => a.id === 'hs_validation_agent')?.avg_confidence || 98.7).toFixed(1)
    : 98.7;

  const aiThroughput = agents.length > 0
    ? (agents.reduce((acc, curr) => acc + (curr.success_rate || curr.avg_confidence || 0), 0) / agents.length).toFixed(1)
    : 91.0;

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [agentsRes, shipRes, docRes] = await Promise.all([
          apiFetch(`${API_BASE}/api/v1/agents`),
          apiFetch(`${API_BASE}/api/v1/shipments`),
          apiFetch(`${API_BASE}/api/v1/documents`)
        ]);

        if (agentsRes.ok) {
          const aData = await agentsRes.json();
          setAgents(aData.agents || []);
        }
        if (shipRes.ok) {
          const sData = await shipRes.json();
          setShipments(sData.shipments || sData || []);
        }
        if (docRes.ok) {
          const dData = await docRes.json();
          setDocuments(dData.documents || []);
        }
      } catch (e) {
        console.error("Dashboard fetch error:", e);
      }
    };

    const fetchTemplates = async () => {
      try {
        const res = await apiFetch(`${API_BASE}/api/v1/templates`);
        if (res.ok) {
          const data = await res.json();
          if (data.templates) setTemplates(data.templates);
        }
      } catch (e) {
        console.log("Templates API not ready, using mock data.");
      }
    };

    fetchData();
    fetchTemplates();
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, []);

  const workflowScrollRef = useRef(null);

  useEffect(() => {
    const el = workflowScrollRef.current;
    if (!el) return;

    let targetScrollLeft = el.scrollLeft;
    let currentScrollLeft = el.scrollLeft;
    let animationFrameId = null;

    const smoothScroll = () => {
      // Linear interpolation: move 15% closer to target in each display frame
      const diff = targetScrollLeft - currentScrollLeft;
      if (Math.abs(diff) > 0.5) {
        currentScrollLeft += diff * 0.15;
        el.scrollLeft = currentScrollLeft;
        animationFrameId = requestAnimationFrame(smoothScroll);
      } else {
        el.scrollLeft = targetScrollLeft;
        currentScrollLeft = targetScrollLeft;
        animationFrameId = null;
      }
    };

    const handleWheel = (e) => {
      if (e.deltaY !== 0) {
        e.preventDefault();
        
        // Dynamically compute the layout direction of the element (snaps on language toggle)
        const isRTL = window.getComputedStyle(el).direction === 'rtl';
        const maxScroll = el.scrollWidth - el.clientWidth;
        
        // If animation is not currently active, synchronize our virtual coordinates with actual DOM position
        // This handles cases where scroll changes due to language flipping or manual drag-scrolls.
        if (!animationFrameId) {
          currentScrollLeft = el.scrollLeft;
          targetScrollLeft = el.scrollLeft;
        }

        // In modern browsers, RTL scrollLeft begins at 0 and goes to negative values (-maxScroll)
        const minS = isRTL ? -maxScroll : 0;
        const maxS = isRTL ? 0 : maxScroll;
        const factor = isRTL ? -1 : 1;
        
        targetScrollLeft = Math.max(minS, Math.min(maxS, targetScrollLeft + e.deltaY * 1.2 * factor));
        
        if (!animationFrameId) {
          animationFrameId = requestAnimationFrame(smoothScroll);
        }
      }
    };

    el.addEventListener('wheel', handleWheel, { passive: false });
    return () => {
      el.removeEventListener('wheel', handleWheel);
      if (animationFrameId) cancelAnimationFrame(animationFrameId);
    };
  }, [language]);

  const archivedShipments = JSON.parse(localStorage.getItem('archived_shipments') || '[]');
  const activeShipmentsCount = shipments.filter(s => !archivedShipments.includes(s.id)).length;

  const metrics = [
    { title: 'Active Shipments', value: activeShipmentsCount, icon: Package, link: '/logistics' },
    { title: 'Documents Generated', value: documents.length.toLocaleString(), icon: FileText, link: '/documents' },
    { title: 'Compliance Success', value: `${complianceSuccess}%`, icon: ShieldCheck, link: '/workflow' },
    { title: 'AI Throughput', value: `${aiThroughput}%`, icon: Zap, link: '/agents' }
  ];

  const workflowSteps = [
    'PO Intake', 'AI Extraction', 'Invoice Generation',
    'Compliance Validation', 'Finance Review', 'Human Approval',
    'Dispatch', 'Shipment Tracking', 'Customer Updates'
  ];

  const handleTriggerDemo = async (e) => {
    e.preventDefault();
    if (!poText) return;

    if (window.workflowPollInterval) clearInterval(window.workflowPollInterval);
    if (window.workflowEventSource) {
      window.workflowEventSource.close();
    }

    setLoading(true);
    setResult(null);
    
    const stepsList = [
      { id: 'extract_po', name: 'Extract order from message', desc: 'Parse commodity, qty, destination, payment terms, incoterm', status: 'pending' },
      { id: 'validate_hs', name: 'HS Validation', desc: 'Check import regulations, HS codes, CITES, and phytosanitary rules', status: 'pending' },
      { id: 'generate_documents', name: 'Document Generation', desc: 'Generate Commercial Invoice and Packing List', status: 'pending' },
      { id: 'hitl_decision', name: 'HITL Review', desc: 'Supervisor confidence audit and policy evaluation', status: 'pending' },
      { id: 'send_notifications', name: 'Customer Dispatch', desc: 'Dispatch invoice & updates to buyer via WhatsApp', status: 'pending' },
      { id: 'create_shipment', name: 'Logistics Booking', desc: 'Create shipment record and container tracking', status: 'pending' }
    ];
    setLiveSteps(stepsList);

    try {
      toast.info("Initiating autonomous workflow...");
      const formData = new FormData();
      formData.append('po_text', poText);

      const response = await apiFetch(`${API_BASE}/api/v1/workflow/po-to-dispatch`, {
        method: 'POST',
        body: formData,
      });

      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(data.detail || data.message || 'Workflow execution failed');
      }

      const serverStatuses = data.step_statuses || {};

      // Simulate a beautiful progressive pipeline simulation in the UI
      for (let i = 0; i < stepsList.length; i++) {
        const step = stepsList[i];

        // Set current step to running/active
        setLiveSteps(prev => {
          const updated = [...prev];
          updated[i].status = 'active';
          return updated;
        });

        // Small delay to make the agent orchestration visual and engaging
        await new Promise(resolve => setTimeout(resolve, 800));

        const actualStatus = serverStatuses[step.id];
        
        // Determine final display status
        let displayStatus = 'completed';
        if (actualStatus === 'failed') {
          displayStatus = 'failed';
        } else if (actualStatus === 'skipped') {
          displayStatus = 'skipped';
        } else if (step.id === 'hitl_decision' && data.status === 'awaiting_human') {
          displayStatus = 'active'; // keep active as it requires human action
        }

        setLiveSteps(prev => {
          const updated = [...prev];
          updated[i].status = displayStatus;
          
          // Inject actual data returned by the backend into descriptions
          if (step.id === 'extract_po' && data.extracted_po) {
            updated[i].desc = `Extracted: ${data.extracted_po.buyer_name || 'Agro Buyer'} ● ${data.extracted_po.currency || 'USD'} ${data.extracted_po.total_value || ''}`;
          }
          if (step.id === 'validate_hs' && data.hs_validations) {
            const valCount = data.hs_validations.validations?.length || 0;
            updated[i].desc = `Validated ${valCount} items. Clearance: ${data.hs_validations.overall_clearance ? 'PASSED' : 'FLAGGED'}`;
          }
          if (step.id === 'generate_documents' && data.documents) {
            const docsCreated = Object.keys(data.documents).map(d => d.replace(/_/g, ' ')).join(', ');
            updated[i].desc = `Created drafts: ${docsCreated}`;
          }
          if (step.id === 'hitl_decision') {
            updated[i].desc = data.status === 'awaiting_human' ? 'Paused: Awaiting Operator Review' : 'Auto-approved (Confidence high)';
          }
          return updated;
        });

        // Halt progressive run if this step failed or workflow is awaiting human approval
        if (actualStatus === 'failed' || (step.id === 'hitl_decision' && data.status === 'awaiting_human')) {
          break;
        }
      }

      setResult(data);
    } catch (error) {
      console.error("Failed to trigger demo", error);
      toast.error(error.message || "Failed to connect to backend.");
      setResult({ error: error.message || "Failed to connect to backend." });
      setLiveSteps([{ id: 'error', name: 'Workflow Failed', status: 'failed', desc: error.message }]);
    } finally {
      setLoading(false);
    }
  };

  const handleFileUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    
    setUploading(true);
    try {
      toast.info("Uploading PDF for extraction...");
      const formData = new FormData();
      formData.append('file', file);
      
      const res = await apiFetch(`${API_BASE}/api/v1/documents/extract`, {
        method: 'POST',
        body: formData
      });
      
      if (!res.ok) throw new Error("Extraction failed");
      
      const data = await res.json();
      setPoText(data.raw_text || data.text || data.extracted_text || data.content || "Extracted text empty.");
      toast.success("PO extracted successfully");
    } catch (error) {
      console.error(error);
      toast.error("Failed to extract PO from PDF");
    } finally {
      setUploading(false);
      e.target.value = ''; 
    }
  };

  // Removing static demoSteps array

  return (
    <div>
      <div className="flex-between mb-4 animate-fade-in">
        <div>
          <h2 className="text-3xl text-gradient">Operational Dashboard</h2>
          <p className="text-muted mt-1 text-sm">AI-native export workflow orchestration platform</p>
        </div>
      </div>

      <div className="grid-4 mb-8">
        {metrics.map((m, i) => <MetricCard key={m.title} title={m.title} value={m.value} index={i} icon={m.icon} link={m.link} />)}
      </div>

      <div className="mb-8">
        <ThroughputChart />
      </div>

      {/* KILLER DEMO TRIGGER SECTION */}
      <section className="mb-8 animate-fade-in" style={{ animationDelay: '0.2s' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '2rem' }}>
          
          <div className="card" style={{ background: 'rgba(99, 102, 241, 0.05)', border: '1px solid var(--accent-primary)', height: '100%', display: 'flex', flexDirection: 'column' }}>
            <h3 className="text-2xl mb-4 text-accent-gradient">Demo: Trigger AI Workflow</h3>
            
            <div className="mb-4">
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {templates.map((t, i) => (
                  <div key={i} style={{ 
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '0.5rem',
                    padding: '0.5rem 0.75rem', background: 'rgba(255,255,255,0.02)',
                    border: '1px solid rgba(255,255,255,0.05)', borderRadius: '0.25rem',
                    fontSize: '0.8rem'
                  }}>
                    <span style={{ fontWeight: 600, color: 'var(--text-main)', minWidth: '150px' }}>{t.name}</span>
                    <span className="desktop-only" style={{ color: 'var(--text-muted)', fontSize: '0.5rem' }}>●</span>
                    <span style={{ color: 'var(--text-muted)' }}>{t.shipments} shipments</span>
                    <span className="desktop-only" style={{ color: 'var(--text-muted)', fontSize: '0.5rem' }}>●</span>
                    <span style={{ color: t.confidence.includes('Learning') ? 'var(--accent-secondary)' : 'var(--success)' }}>
                      {t.confidence} {t.confidence.includes('%') ? 'confidence' : ''}
                    </span>
                    <span className="desktop-only" style={{ color: 'var(--text-muted)', fontSize: '0.5rem' }}>●</span>
                    <span style={{ color: 'var(--text-muted)' }}>{t.last.includes('Last:') ? t.last : `Last: ${t.last}`}</span>
                  </div>
                ))}
              </div>
            </div>

            <p className="text-muted text-sm mb-4">Submit raw Purchase Order text to initiate the autonomous <code>po-to-dispatch</code> pipeline.</p>

            <form onSubmit={handleTriggerDemo} style={{ display: 'flex', flexDirection: 'column', gap: '1rem', flex: 1 }}>
              <textarea
                value={poText}
                onChange={(e) => setPoText(e.target.value)}
                placeholder="Paste raw Purchase Order text here, or upload a PO PDF using the button below to extract and run the workflow..."
                style={{
                  width: '100%', height: '100px', padding: '1rem',
                  background: 'rgba(0,0,0,0.3)', border: '1px solid var(--border-color)',
                  color: 'white', borderRadius: '0.5rem', outline: 'none', resize: 'none',
                  boxSizing: 'border-box', flex: 1
                }}
              />
              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 'auto', gap: '1rem', flexWrap: 'wrap' }}>
                <input 
                  type="file" 
                  accept="application/pdf" 
                  ref={fileInputRef} 
                  style={{ display: 'none' }} 
                  onChange={handleFileUpload} 
                />
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  disabled={uploading || loading}
                  className="badge flex-center"
                  style={{
                    padding: '0.75rem 1.5rem', background: 'transparent',
                    color: 'var(--accent-secondary)', cursor: (uploading || loading) ? 'not-allowed' : 'pointer', 
                    border: '1px solid var(--accent-secondary)', fontSize: '1rem', gap: '0.5rem'
                  }}
                >
                  <UploadCloud size={18} /> {uploading ? 'Extracting...' : 'Upload PO'}
                </button>
                <button
                  type="submit"
                  disabled={loading || uploading}
                  className="badge"
                  style={{
                    padding: '0.75rem 2rem', background: 'var(--accent-primary)',
                    color: 'var(--bg-dark)', fontWeight: 'bold', cursor: (loading || uploading) ? 'not-allowed' : 'pointer', border: 'none', fontSize: '1rem'
                  }}
                >
                  {loading ? 'Processing...' : (result ? 'Run Again' : 'Run Workflow')}
                </button>
              </div>
            </form>

            {result && !loading && (
              <div className="mt-4 animate-fade-in" style={{ background: 'rgba(0,0,0,0.5)', padding: '1rem', borderRadius: '0.5rem' }}>
                <h4 className="text-sm mb-2 text-success">API Response:</h4>
                <pre style={{
                  fontSize: '0.8rem',
                  color: 'var(--text-muted)',
                  overflowX: 'auto',
                  overflowY: 'auto',
                  maxHeight: '200px',
                  padding: '0.5rem',
                  background: 'rgba(0,0,0,0.2)',
                  borderRadius: '0.25rem'
                }}>
                  {JSON.stringify(result, null, 2)}
                </pre>
              </div>
            )}
          </div>

          <div className="card" style={{ background: 'rgba(15, 15, 22, 0.6)', border: '1px solid rgba(255,255,255,0.05)', height: '100%' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
              {(liveSteps.length > 0 ? liveSteps : [{ id: 'idle', name: 'Awaiting submission...', status: 'pending' }]).map((s, i) => {
                 const isPast = s.status === 'completed';
                 const isCurr = s.status === 'active' || s.status === 'running';
                 const isFuture = s.status === 'pending';
                 const isFailed = s.status === 'failed';
                 const isIdle = !loading && liveSteps.length === 0;
                 const isHitlActive = s.id === 'hitl_decision' && isCurr;

                 let borderColor = 'rgba(255,255,255,0.05)';
                 let bg = 'rgba(255,255,255,0.02)';
                 let icon = <Circle size={20} color="var(--text-muted)" style={{ opacity: 0.3 }} />;
                 let badge = null;

                 if (isPast) {
                   borderColor = 'rgba(34, 197, 94, 0.3)';
                   bg = 'rgba(34, 197, 94, 0.05)';
                   icon = <CheckCircle size={20} color="#4ade80" />;
                   badge = <span style={{ background: 'rgba(34, 197, 94, 0.2)', color: '#4ade80', padding: '2px 8px', borderRadius: '12px', fontSize: '0.7rem', border: '1px solid rgba(34, 197, 94, 0.4)' }}>completed</span>;
                 } else if (isCurr) {
                   borderColor = isHitlActive ? 'var(--accent-secondary)' : 'rgba(0, 229, 255, 0.5)';
                   bg = isHitlActive ? 'rgba(0, 229, 255, 0.08)' : 'rgba(0, 229, 255, 0.05)';
                   icon = <Loader2 size={20} color="var(--accent-primary)" style={{ animation: 'spin 1s linear infinite' }} />;
                   badge = (
                     <span 
                       style={{ 
                         background: 'rgba(0, 229, 255, 0.2)', 
                         color: 'var(--accent-primary)', 
                         padding: '2px 8px', 
                         borderRadius: '12px', 
                         fontSize: '0.7rem', 
                         border: '1px solid rgba(0, 229, 255, 0.4)',
                         cursor: isHitlActive ? 'pointer' : 'default',
                         textDecoration: isHitlActive ? 'underline' : 'none'
                       }}
                       onClick={(e) => {
                         if (isHitlActive) {
                           e.stopPropagation();
                           navigate('/agents');
                         }
                       }}
                     >
                       {isHitlActive ? 'Review Required (Click Here →)' : 'running'}
                     </span>
                   );
                 } else if (isFailed) {
                   borderColor = 'rgba(239, 68, 68, 0.5)';
                   bg = 'rgba(239, 68, 68, 0.05)';
                   icon = <AlertCircle size={20} color="var(--error)" />;
                   badge = <span style={{ background: 'rgba(239, 68, 68, 0.2)', color: 'var(--error)', padding: '2px 8px', borderRadius: '12px', fontSize: '0.7rem', border: '1px solid rgba(239, 68, 68, 0.4)' }}>failed</span>;
                 }

                 return (
                   <div 
                     key={s.id || i} 
                     onClick={() => {
                       if (isHitlActive) {
                         navigate('/agents');
                       }
                     }}
                     style={{
                       display: 'flex', gap: '1rem', padding: '1rem', borderRadius: '0.5rem',
                       border: `1px solid ${borderColor}`, background: bg,
                       transition: 'all 0.3s ease', opacity: (isFuture || isIdle) ? 0.5 : 1,
                       cursor: isHitlActive ? 'pointer' : 'default',
                       boxShadow: isHitlActive ? '0 0 15px rgba(0, 229, 255, 0.15)' : 'none'
                     }}
                     onMouseOver={(e) => {
                       if (isHitlActive) {
                         e.currentTarget.style.border = '1px solid var(--accent-primary)';
                         e.currentTarget.style.boxShadow = '0 0 20px rgba(0, 229, 255, 0.3)';
                       }
                     }}
                     onMouseOut={(e) => {
                       if (isHitlActive) {
                         e.currentTarget.style.border = `1px solid ${borderColor}`;
                         e.currentTarget.style.boxShadow = '0 0 15px rgba(0, 229, 255, 0.15)';
                       }
                     }}
                   >
                      <div style={{ marginTop: '2px' }}>{icon}</div>
                      <div style={{ flex: 1 }}>
                        <div className="flex-between mb-1">
                           <div style={{ fontWeight: 500, fontSize: '0.9rem', color: (isCurr || isPast) ? 'var(--text-main)' : 'var(--text-muted)' }}>{s.name || s.title}</div>
                           {badge}
                        </div>
                        {(s.desc || s.description) && (
                          <div className="text-muted" style={{ fontSize: '0.8rem', lineHeight: 1.4 }}>{s.desc || s.description}</div>
                        )}
                      </div>
                   </div>
                 );
              })}
            </div>
          </div>

        </div>
      </section>

      <section className="mb-8 animate-fade-in" style={{ animationDelay: '0.4s' }}>
        <h3 className="text-2xl mb-6">AI Workflow Engine</h3>
        <div 
          ref={workflowScrollRef}
          className="workflow-pipeline" 
          style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', overflowX: 'auto', paddingBottom: '1.5rem', paddingTop: '0.5rem' }}
        >
          {workflowSteps.map((step, i) => (
            <React.Fragment key={step}>
              <div style={{ minWidth: '220px', flexShrink: 0 }}>
                <WorkflowNode step={step} index={i} />
              </div>
              {i < workflowSteps.length - 1 && (
                <div className="flex-center" style={{ 
                  padding: '0 0.5rem', color: 'var(--accent-primary)', 
                  opacity: 0.5, flexShrink: 0
                }}>
                  {isRTL ? <ChevronLeft size={24} /> : <ChevronRight size={24} />}
                </div>
              )}
            </React.Fragment>
          ))}
        </div>
      </section>

      <section className="animate-fade-in" style={{ animationDelay: '0.6s' }}>
        <h3 className="text-2xl mb-6">Agent Hub</h3>
        <div className="grid-4">
          {agents.length === 0 ? (
            <p className="text-muted col-span-4">Loading agents...</p>
          ) : (
            agents.map((agent, i) => <AgentCard key={agent.id || agent.name} agent={agent} index={i} />)
          )}
        </div>
      </section>
    </div>
  );
}

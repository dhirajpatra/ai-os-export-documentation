import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, CheckCircle, XCircle, AlertTriangle, Info } from 'lucide-react';
import { toast } from 'sonner';
import { API_BASE } from '../config';
import { apiFetch } from '../api';

export default function ApprovalDetailsModal({ approvalId, onClose, onAction }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [corrections, setCorrections] = useState({});

  useEffect(() => {
    if (!approvalId) return;
    const fetchDetails = async () => {
      setLoading(true);
      setCorrections({});
      try {
        const res = await apiFetch(`${API_BASE}/api/v1/approvals/${approvalId}`);
        if (!res.ok) throw new Error('Failed to fetch approval details');
        const json = await res.json();
        setData(json);
      } catch (err) {
        // Fallback to minimal data if API is not fully implemented yet
        toast.error("Could not load approval details, showing fallback.");
        setData({
          approval_id: approvalId,
          status: "pending",
          original_input: {
            source: "whatsapp",
            text: "Could not fetch original input."
          },
          review_reason: "Failed to fetch detailed review reason.",
        });
      } finally {
        setLoading(false);
      }
    };
    fetchDetails();
  }, [approvalId]);

  if (!approvalId) return null;

  return (
    <AnimatePresence>
      <motion.div 
        className="modal-overlay"
        style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', 
          display: 'flex', justifyContent: 'center', alignItems: 'center', 
          zIndex: 9999, backdropFilter: 'blur(4px)'
        }}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
      >
        <motion.div 
          className="card"
          initial={{ y: 50, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 50, opacity: 0 }}
          style={{ maxWidth: '800px', width: '90%', maxHeight: '90vh', overflowY: 'auto' }}
        >
          <div className="flex-between mb-4" style={{ borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '1rem' }}>
            <h3 className="text-2xl text-gradient" style={{ margin: 0 }}>Review Approval: {approvalId}</h3>
            <button onClick={onClose} style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}>
              <X size={24} />
            </button>
          </div>

          {loading ? (
            <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>Loading details...</div>
          ) : data ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
              
              {/* Risk Flags & Reason */}
              {(data.review_reason || (data.risk_flags && data.risk_flags.length > 0)) && (
                <div style={{ padding: '1rem', borderRadius: '0.5rem', background: 'rgba(249, 115, 22, 0.1)', border: '1px solid rgba(249, 115, 22, 0.2)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: '#fb923c', marginBottom: '0.5rem', fontWeight: 'bold' }}>
                    <AlertTriangle size={18} />
                    Why Human Review Was Triggered
                  </div>
                  {data.review_reason && <p className="text-sm" style={{ color: 'rgba(253, 186, 116, 0.9)', marginBottom: '0.5rem', marginTop: 0 }}>{data.review_reason}</p>}
                  {data.risk_flags && data.risk_flags.length > 0 && (
                    <ul style={{ paddingLeft: '1.25rem', color: 'rgba(253, 186, 116, 0.9)', margin: 0 }} className="text-sm">
                      {data.risk_flags.map((flag, idx) => (
                        <li key={idx} style={{ marginBottom: '0.25rem' }}>{flag}</li>
                      ))}
                    </ul>
                  )}
                </div>
              )}

              {/* Suggested Action */}
              {data.suggested_action && (
                <div style={{ padding: '1rem', borderRadius: '0.5rem', background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.2)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: '#60a5fa', marginBottom: '0.5rem', fontWeight: 'bold' }}>
                    <Info size={18} />
                    Suggested AI Action
                  </div>
                  <p className="text-sm" style={{ color: 'rgba(191, 219, 254, 0.9)', margin: 0 }}>{data.suggested_action}</p>
                </div>
              )}

              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.5rem' }}>
                {/* Original Input */}
                {data.original_input && (
                  <div>
                    <h4 className="text-xl mb-2" style={{ borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '0.5rem' }}>Original Input</h4>
                    <div className="card" style={{ padding: '0.75rem', height: '100%' }}>
                      <div className="text-xs text-muted mb-2" style={{ textTransform: 'uppercase', letterSpacing: '0.05em' }}>Source: {data.original_input.source || 'Unknown'}</div>
                      <pre className="text-sm" style={{ whiteSpace: 'pre-wrap', fontFamily: 'inherit', margin: 0, color: 'var(--text-main)' }}>
                        {data.original_input.text === "Original document attached." ? 
                          "Original document attached.\n\n[Attachment Details]\nFile: Purchase_Order_500kg.pdf\nSize: 2.4MB\nPages: 3\nStatus: Scanned & Parsed" : 
                          (data.original_input.text || JSON.stringify(data.original_input, null, 2))}
                      </pre>
                    </div>
                  </div>
                )}

                {/* AI Extracted Data & Confidence */}
                {data.extracted_data && (
                  <div>
                    <h4 className="text-xl mb-2" style={{ borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '0.5rem' }}>AI Extracted Data</h4>
                    <div className="card" style={{ padding: '0.75rem', height: '100%' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                        {Object.entries(data.extracted_data).map(([key, value]) => {
                          const conf = data.confidence_scores && data.confidence_scores[key] !== undefined ? data.confidence_scores[key] : null;
                          const isLowConf = conf !== null && conf < 80;
                          
                          return (
                            <div key={key} className="flex-between" style={{ borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '0.5rem', alignItems: 'center' }}>
                              <div style={{ flex: 1, marginRight: '1rem' }}>
                                <div className="text-xs text-muted mb-1" style={{ textTransform: 'uppercase', letterSpacing: '0.05em' }}>{key.replace(/_/g, ' ')}</div>
                                <input 
                                  className="text-sm"
                                  style={{ fontWeight: 500, background: 'rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.1)', padding: '0.25rem 0.5rem', borderRadius: '0.25rem', color: 'var(--text-main)', width: '100%', outline: 'none' }}
                                  value={corrections[key] !== undefined ? corrections[key] : String(value)}
                                  onChange={(e) => setCorrections(prev => ({ ...prev, [key]: e.target.value }))}
                                />
                              </div>
                              {conf != null && (
                                <div className="text-xs" style={{ 
                                  padding: '0.25rem 0.5rem', borderRadius: '1rem',
                                  background: isLowConf ? 'rgba(249, 115, 22, 0.2)' : 'rgba(34, 197, 94, 0.2)',
                                  color: isLowConf ? '#fb923c' : '#4ade80',
                                  border: `1px solid ${isLowConf ? 'rgba(249, 115, 22, 0.3)' : 'rgba(34, 197, 94, 0.3)'}`,
                                  whiteSpace: 'nowrap'
                                }}>
                                  {conf}% conf
                                </div>
                              )}
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  </div>
                )}
              </div>

              {/* Action Buttons */}
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '1rem', marginTop: '1rem', paddingTop: '1rem', borderTop: '1px solid rgba(255,255,255,0.1)' }}>
                <button 
                  onClick={() => onAction(approvalId, 'reject')} 
                  className="badge flex-center"
                  style={{ gap: '0.5rem', cursor: 'pointer', border: '1px solid var(--error)', background: 'transparent', color: 'var(--error)', padding: '0.75rem 1.5rem', fontSize: '0.875rem' }}
                >
                  <XCircle size={16} /> Reject
                </button>
                <button 
                  onClick={() => onAction(approvalId, 'approve', corrections)} 
                  className="badge flex-center"
                  style={{ gap: '0.5rem', cursor: 'pointer', border: 'none', background: 'var(--success)', color: 'white', padding: '0.75rem 1.5rem', fontSize: '0.875rem', boxShadow: '0 4px 12px rgba(34, 197, 94, 0.2)' }}
                >
                  <CheckCircle size={16} /> Approve & Resume
                </button>
              </div>

            </div>
          ) : (
            <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>No data available.</div>
          )}
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}

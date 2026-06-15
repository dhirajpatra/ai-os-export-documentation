import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { toast } from 'sonner';
import { API_BASE } from '../config';
import { apiFetch } from '../api';
import { UploadCloud, Search, Eye, Download, FileText } from 'lucide-react';
import DocumentModal from '../components/DocumentModal';

export default function DocumentsPage() {
  const [documents, setDocuments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedDocument, setSelectedDocument] = useState(null);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const fetchDocuments = async () => {
    try {
      const res = await apiFetch(`${API_BASE}/api/v1/documents`);
      if (res.ok) {
        const data = await res.json();
        setDocuments(data.documents || []);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDocuments();
    const interval = setInterval(fetchDocuments, 5000);
    return () => clearInterval(interval);
  }, []);

  const handleGenerate = async () => {
    toast.info("Selecting active shipment...");
    try {
      const shipRes = await apiFetch(`${API_BASE}/api/v1/shipments`);
      if (!shipRes.ok) throw new Error("Failed to lookup active shipments.");
      const shipData = await shipRes.json();
      const shipmentsList = shipData.shipments || [];
      if (shipmentsList.length === 0) throw new Error("No active shipments found to generate documents for.");
      
      const targetShipment = shipmentsList[Math.floor(Math.random() * shipmentsList.length)];
      
      toast.info(`Requesting document generation for ${targetShipment.order_number || targetShipment.id}...`);

      const res = await apiFetch(`${API_BASE}/api/v1/documents`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ shipmentId: targetShipment.order_number || targetShipment.id, documentType: 'Commercial Invoice' })
      });
      if (!res.ok) {
        const errorData = await res.json().catch(() => ({}));
        throw new Error(errorData.detail || errorData.message || 'API request failed');
      }
      toast.success("Document generation initiated!");
      fetchDocuments();
    } catch (e) {
      toast.error(e.message || "Failed to trigger generation.");
    }
  };

  const handleDownload = (doc) => {
    try {
      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(JSON.parse(doc.extracted_data), null, 2));
      const downloadAnchorNode = document.createElement('a');
      downloadAnchorNode.setAttribute("href", dataStr);
      downloadAnchorNode.setAttribute("download", `${doc.reference_number || 'document'}.json`);
      document.body.appendChild(downloadAnchorNode); 
      downloadAnchorNode.click();
      downloadAnchorNode.remove();
      toast.success(`Downloaded ${doc.reference_number || 'document'}.json`);
    } catch (e) {
      toast.error("Failed to generate downloadable file.");
    }
  };

  const openDocument = (doc) => {
    setSelectedDocument(doc);
    setIsModalOpen(true);
  };

  return (
    <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5 }}>
      <div className="flex-between mb-8">
        <div>
          <h2 className="text-4xl text-gradient">Documents</h2>
          <p className="text-muted mt-2">AI-generated trade documentation repository</p>
        </div>
        <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', flexWrap: 'nowrap', flex: 1, justifyContent: 'flex-end', maxWidth: '100%' }}>
          <div style={{ position: 'relative', flex: 1, minWidth: '100px' }}>
            <Search size={18} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
            <input 
              type="text" 
              placeholder="Search documents..." 
              className="card"
              style={{ padding: '0.75rem 1rem 0.75rem 2.5rem', border: '1px solid var(--border-color)', outline: 'none', color: 'white', width: '100%', boxSizing: 'border-box' }}
            />
          </div>
          <button onClick={handleGenerate} className="badge flex-center" style={{ gap: '0.5rem', padding: '0.75rem 1rem', background: 'var(--accent-primary)', color: 'white', cursor: 'pointer', border: 'none', flexShrink: 0, whiteSpace: 'nowrap' }}>
            <UploadCloud size={18} /> Generate
          </button>
        </div>
      </div>

      <div className="card table-responsive">
        <div className="table-row-group">
          <div className="flex-between text-muted text-sm mb-4" style={{ padding: '0 1rem', borderBottom: '1px solid var(--border-color)', paddingBottom: '1rem' }}>
            <div style={{ flex: 2 }}>Name</div>
            <div style={{ flex: 1 }}>Type</div>
            <div style={{ flex: 1 }}>Status</div>
            <div style={{ flex: 1 }}>Date</div>
            <div style={{ flex: 1, textAlign: 'right' }}>Actions</div>
          </div>

          <div className="space-y-2">
            {loading ? (
              <p className="text-muted" style={{ padding: '1rem' }}>Loading documents...</p>
            ) : documents.length === 0 ? (
              <p className="text-muted" style={{ padding: '1rem' }}>No documents generated yet.</p>
            ) : (
              documents.map((doc, i) => (
                <motion.div 
                  key={doc.id || doc.filename || i} 
                className="flex-between" 
                initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}
                style={{ padding: '1rem', borderRadius: '0.5rem', background: 'rgba(255,255,255,0.02)' }}
              >
                <div style={{ flex: 2, display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                  <FileText size={18} style={{ color: 'var(--accent-secondary)' }} />
                  <span>{doc.reference_number || doc.id}</span>
                </div>
                <div style={{ flex: 1 }} className="text-muted text-sm">{doc.doc_type ? doc.doc_type.replace(/_/g, ' ') : '--'}</div>
                <div style={{ flex: 1 }}>
                  <span className={`badge ${doc.status === 'approved' || doc.status === 'sent' ? 'text-success' : doc.status === 'draft' ? 'text-muted' : 'text-accent-primary'}`}>
                    {doc.status}
                  </span>
                </div>
                <div style={{ flex: 1 }} className="text-muted text-sm">{doc.created_at ? new Date(doc.created_at).toLocaleDateString() : '--'}</div>
                <div style={{ flex: 1, textAlign: 'right', display: 'flex', gap: '0.5rem', justifyContent: 'flex-end' }}>
                  <button onClick={() => openDocument(doc)} className="badge flex-center" style={{ gap: '0.25rem', cursor: 'pointer', border: '1px solid var(--accent-primary)', background: 'transparent', color: 'white' }}><Eye size={14}/> View</button>
                  <button onClick={() => handleDownload(doc)} className="badge flex-center" style={{ gap: '0.25rem', cursor: 'pointer', border: '1px solid var(--accent-secondary)', background: 'transparent', color: 'white' }}><Download size={14}/></button>
                </div>
              </motion.div>
              ))
            )}
          </div>
        </div>
      </div>
      
      <DocumentModal 
        isOpen={isModalOpen} 
        onClose={() => setIsModalOpen(false)} 
        document={selectedDocument} 
        onDownload={handleDownload} 
      />
    </motion.div>
  );
}

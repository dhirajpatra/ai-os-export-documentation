import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { API_BASE } from '../config';
import { apiFetch } from '../api';
import { toast } from 'sonner';
import { Link, ArchiveX } from 'lucide-react';
import FreightForwarderModal from '../components/FreightForwarderModal';

export default function LogisticsPage() {
  const [shipmentsData, setShipmentsData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isApiModalOpen, setIsApiModalOpen] = useState(false);
  const [archivedShipments, setArchivedShipments] = useState(() => {
    return JSON.parse(localStorage.getItem('archived_shipments') || '[]');
  });

  const handleArchive = (id) => {
    const updated = [...archivedShipments, id];
    setArchivedShipments(updated);
    localStorage.setItem('archived_shipments', JSON.stringify(updated));
    toast.success(`Shipment ${id} archived from view.`);
  };

  const fetchLogistics = async () => {
    try {
      const shipRes = await apiFetch(`${API_BASE}/api/v1/shipments`);
      if (!shipRes.ok) return;
      const data = await shipRes.json();
      const shipmentsList = data.shipments || [];
      
      const enrichedShipments = await Promise.all(shipmentsList.map(async (ship) => {
        try {
          const logRes = await apiFetch(`${API_BASE}/api/v1/logistics/${ship.id}`);
          if (logRes.ok) {
            const logistics = await logRes.json();
            const totalStages = logistics.stages ? logistics.stages.length : 1;
            const completedStages = logistics.stages ? logistics.stages.filter(s => s.status === 'completed' || s.status === 'passed').length : 0;
            const progress = totalStages > 0 ? `${Math.round((completedStages / totalStages) * 100)}%` : '0%';
            
            return {
              ...ship,
              currentStage: logistics.currentStage || ship.status || 'booking_pending',
              progress,
              origin: ship.port_of_loading || 'Automated Origin',
              destination: ship.port_of_discharge || 'Pending...',
              vessel: ship.vessel_name || 'Pending Vessel Assignment',
              eta: ship.eta || '--'
            };
          }
        } catch(e) {}
        return { 
          ...ship, 
          progress: '0%', 
          origin: ship.port_of_loading || 'Automated Origin', 
          destination: ship.port_of_discharge || 'Pending...',
          vessel: ship.vessel_name || 'Pending Vessel Assignment', 
          eta: ship.eta || '--',
          currentStage: ship.status || 'booking_pending'
        };
      }));
      setShipmentsData(enrichedShipments);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogistics();
    const interval = setInterval(fetchLogistics, 10000);
    return () => clearInterval(interval);
  }, []);

  const visibleShipments = shipmentsData.filter(s => !archivedShipments.includes(s.id));

  return (
    <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5 }}>
      <div className="mb-8 flex-between">
        <div>
          <h2 className="text-4xl text-gradient">Logistics Tracking</h2>
          <p className="text-muted mt-2">Real-time freight and container visibility</p>
        </div>
        <button 
          className="badge flex-center" 
          style={{ gap: '0.5rem', padding: '0.75rem 1.5rem', background: 'var(--accent-secondary)', color: 'white', cursor: 'pointer', border: 'none' }}
          onClick={() => setIsApiModalOpen(true)}
        >
          <Link size={16} /> Connect Freight Forwarder API
        </button>
      </div>

      <div className="card mb-8">
        <h3 className="text-2xl mb-4 text-accent-gradient">Active Shipments</h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          {loading ? (
            <p className="text-muted text-center py-8">Syncing with global logistics providers...</p>
          ) : visibleShipments.length === 0 ? (
            <p className="text-muted text-center py-8">No shipments in transit.</p>
          ) : (
            visibleShipments.map((ship) => (
              <motion.div 
                key={ship.id} 
                className="card"
                initial={{ opacity: 0, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
                style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid var(--border-color)' }}
              >
                <div className="flex-between mb-4">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                    <h4 className="text-xl text-accent-gradient">{ship.order_number || ship.id}</h4>
                    <span className="badge">{ship.currentStage}</span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                    <span className="text-sm text-muted">Vessel: {ship.vessel}</span>
                    <button 
                      onClick={() => handleArchive(ship.id)}
                      className="badge flex-center"
                      style={{ gap: '0.25rem', cursor: 'pointer', background: 'transparent', border: '1px solid var(--border-color)', color: 'var(--text-muted)' }}
                      title="Hide from view"
                    >
                      <ArchiveX size={14} /> Dismiss
                    </button>
                  </div>
                </div>

                <div className="flex-between text-sm mb-2">
                  <span className="text-muted">{ship.origin}</span>
                  <span className="text-muted">ETA: {ship.eta}</span>
                  <span className="text-muted">{ship.destination}</span>
                </div>

                <div className="progress-bg mb-4">
                  <div className="progress-fill" style={{ width: ship.progress }}></div>
                </div>

                <div className="flex-between">
                  <span className="text-xs text-muted">Live Tracking Enabled via API</span>
                  <span className="text-xs text-accent-secondary font-bold">{ship.progress}</span>
                </div>
              </motion.div>
            ))
          )}
        </div>
      </div>
      
      <FreightForwarderModal 
        isOpen={isApiModalOpen}
        onClose={() => setIsApiModalOpen(false)}
      />
    </motion.div>
  );
}

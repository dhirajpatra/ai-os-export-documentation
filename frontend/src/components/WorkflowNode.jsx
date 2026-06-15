import React from 'react';
import { motion } from 'framer-motion';
import { Settings, FileInput, BrainCircuit, FileSignature, ShieldCheck, DollarSign, UserCheck, Truck, Map, Bell } from 'lucide-react';

export default function WorkflowNode({ step, index }) {
  const getIcon = () => {
    switch(step) {
      case 'PO Intake': return <FileInput size={20} />;
      case 'AI Extraction': return <BrainCircuit size={20} />;
      case 'Invoice Generation': return <FileSignature size={20} />;
      case 'Compliance Validation': return <ShieldCheck size={20} />;
      case 'Finance Review': return <DollarSign size={20} />;
      case 'Human Approval': return <UserCheck size={20} />;
      case 'Dispatch': return <Truck size={20} />;
      case 'Shipment Tracking': return <Map size={20} />;
      case 'Customer Updates': return <Bell size={20} />;
      default: return <Settings size={20} />;
    }
  };

  return (
    <motion.div 
      className="card flex-center" 
      initial={{ opacity: 0, scale: 0.9 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.3, delay: index * 0.03 }}
      whileHover={{ 
        y: -5, 
        borderColor: 'var(--accent-primary)',
        transition: { duration: 0.1, ease: 'easeOut' }
      }}
      style={{ flexDirection: 'column', textAlign: 'center', transition: 'none' }}
    >
      <div 
        style={{
          width: '40px', height: '40px', borderRadius: '50%', 
          background: 'linear-gradient(135deg, var(--accent-primary), var(--accent-secondary))',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'white', marginBottom: '1rem', boxShadow: '0 4px 15px rgba(99, 102, 241, 0.4)'
        }}
      >
        {getIcon()}
      </div>
      <h4 className="text-sm">{step}</h4>
      <p className="text-muted text-xs mt-2">Autonomous execution</p>
    </motion.div>
  );
}

import React from 'react';
import { motion } from 'framer-motion';
import { Bot, Brain, Shield, FileText } from 'lucide-react';

export default function AgentCard({ agent, index }) {
  const getIcon = () => {
    const name = (agent.name || '').toLowerCase();
    if (name.includes('extraction')) return <Brain size={20} className="text-accent-secondary" />;
    if (name.includes('classification') || name.includes('validation')) return <Shield size={20} className="text-accent-primary" />;
    if (name.includes('document')) return <FileText size={20} className="text-success" />;
    return <Bot size={20} className="text-muted" />;
  };

  return (
    <motion.div 
      className="card"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: index * 0.1 }}
      whileHover={{ scale: 1.02, boxShadow: "0 10px 40px -10px rgba(0,0,0,0.5)" }}
    >
      <div className="flex-between mb-4" style={{ flexWrap: 'nowrap', alignItems: 'flex-start' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          {getIcon()}
          <h4 className="text-xl" style={{ fontSize: '1.1rem', lineHeight: '1.3' }}>{agent.name}</h4>
        </div>
        <span className={agent.status?.toLowerCase() === 'active' ? 'text-success text-sm flex-shrink-0' : 'text-muted text-sm flex-shrink-0'} style={{ whiteSpace: 'nowrap', marginTop: '0.2rem' }}>
          {agent.status || 'Unknown'}
        </span>
      </div>

      <div className="mb-4">
        <div className="flex-between text-sm mb-1">
          <span className="text-muted">Throughput</span>
          <span>{agent.throughput || `${Math.round(agent.success_rate || 0)}%`}</span>
        </div>
        <div className="progress-bg">
          <motion.div 
            className="progress-fill" 
            initial={{ width: 0 }}
            animate={{ width: agent.throughput || `${Math.round(agent.success_rate || 0)}%` }}
            transition={{ duration: 1.5, delay: index * 0.1 + 0.3, ease: "easeOut" }}
          ></motion.div>
        </div>
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
        {(agent.skills || []).map(skill => (
          <span key={skill} className="badge">{skill}</span>
        ))}
      </div>
    </motion.div>
  );
}

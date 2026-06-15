import React from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';

export default function MetricCard({ title, value, index, icon: Icon, link }) {
  const navigate = useNavigate();

  return (
    <motion.div 
      className="card"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: index * 0.1 }}
      whileHover={{ scale: 1.02 }}
      onClick={() => link && navigate(link)}
      style={{ cursor: link ? 'pointer' : 'default' }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '0.5rem' }}>
        <p className="text-muted text-sm" style={{ flex: 1, wordBreak: 'break-word', lineHeight: '1.4' }}>{title}</p>
        {Icon && <div style={{ flexShrink: 0 }}><Icon size={20} className="text-muted" /></div>}
      </div>
      <h3 className="text-3xl mt-4 text-accent-gradient">{value}</h3>
    </motion.div>
  );
}

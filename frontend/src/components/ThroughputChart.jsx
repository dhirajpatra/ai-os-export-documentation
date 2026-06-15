import React from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { motion } from 'framer-motion';
import { useAppStore } from '../store/useAppStore';

const data = [
  { name: 'Mon', throughput: 82 },
  { name: 'Tue', throughput: 85 },
  { name: 'Wed', throughput: 88 },
  { name: 'Thu', throughput: 84 },
  { name: 'Fri', throughput: 91 },
  { name: 'Sat', throughput: 96 },
  { name: 'Sun', throughput: 94 },
];

export default function ThroughputChart() {
  const language = useAppStore(state => state.language);
  const isRTL = language?.toLowerCase() === 'ar';

  const translateDay = (day) => {
    if (!isRTL) return day;
    const days = {
      'Mon': 'الاثنين',
      'Tue': 'الثلاثاء',
      'Wed': 'الأربعاء',
      'Thu': 'الخميس',
      'Fri': 'الجمعة',
      'Sat': 'السبت',
      'Sun': 'الأحد'
    };
    return days[day] || day;
  };

  const chartData = data.map(d => ({
    ...d,
    translatedName: translateDay(d.name)
  }));

  return (
    <motion.div 
      className="card"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: 0.2 }}
    >
      <h3 className="text-xl mb-4">{isRTL ? 'إنتاجية الذكاء الاصطناعي الأسبوعية (%)' : 'Weekly AI Throughput (%)'}</h3>
      <div style={{ width: '100%', height: 300 }} dir="ltr">
        <ResponsiveContainer>
          <AreaChart data={chartData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id="colorThroughput" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="var(--accent-primary)" stopOpacity={0.8}/>
                <stop offset="95%" stopColor="var(--accent-primary)" stopOpacity={0}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
            <XAxis dataKey="translatedName" stroke="var(--text-muted)" reversed={isRTL} />
            <YAxis stroke="var(--text-muted)" domain={[60, 100]} orientation={isRTL ? 'right' : 'left'} />
            <Tooltip 
              contentStyle={{ backgroundColor: 'var(--bg-card)', borderColor: 'var(--border-color)', borderRadius: '0.5rem', textAlign: isRTL ? 'right' : 'left' }}
              itemStyle={{ color: 'var(--text-main)' }}
            />
            <Area 
              type="monotone" 
              name={isRTL ? 'الإنتاجية' : 'Throughput'} 
              dataKey="throughput" 
              stroke="var(--accent-primary)" 
              fillOpacity={1} 
              fill="url(#colorThroughput)" 
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </motion.div>
  );
}

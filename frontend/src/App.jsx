import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { Toaster } from 'sonner';
import MainLayout from './layouts/MainLayout';
import DashboardPage from './pages/DashboardPage';
import WorkflowEnginePage from './pages/WorkflowEnginePage';
import AgentHubPage from './pages/AgentHubPage';
import DocumentsPage from './pages/DocumentsPage';
import LogisticsPage from './pages/LogisticsPage';
import LoginPage from './pages/LoginPage';
import LandingPage from './pages/LandingPage';
import CostBreakdownPage from './pages/CostBreakdownPage';
import ProcessBreakdownPage from './pages/ProcessBreakdownPage';
import ProtectedRoute from './components/ProtectedRoute';

export default function App() {
  return (
    <>
      <Toaster theme="dark" position="top-center" richColors />
      <Router>
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/cost-breakdown" element={<CostBreakdownPage />} />
        <Route path="/how-it-works" element={<ProcessBreakdownPage />} />
        <Route path="/login" element={<LoginPage />} />
        
        {/* Protected Dashboard Routes */}
        <Route element={<ProtectedRoute />}>
          <Route element={<MainLayout />}>
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/workflow" element={<WorkflowEnginePage />} />
            <Route path="/agents" element={<AgentHubPage />} />
            <Route path="/documents" element={<DocumentsPage />} />
            <Route path="/logistics" element={<LogisticsPage />} />
            {/* Catch-all route for 404 */}
            <Route path="*" element={<div className="card"><h2 className="text-2xl text-gradient">Page Not Found</h2><p className="text-muted mt-2">The requested module does not exist. Please use the sidebar to navigate.</p></div>} />
          </Route>
        </Route>
      </Routes>
    </Router>
    </>
  );
}

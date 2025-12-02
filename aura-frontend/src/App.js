import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { ThemeProvider } from '@mui/material/styles';
import { CssBaseline } from '@mui/material';
import { SnackbarProvider } from 'notistack';
import fioriTheme from './theme/fioriTheme';
import Layout from './components/layout/Layout';
import Dashboard from './pages/Dashboard/Dashboard';
import TicketList from './pages/ServiceDesk/TicketList';
import TicketDetail from './pages/ServiceDesk/TicketDetail';
import CreateTicket from './pages/ServiceDesk/CreateTicket';
import KnowledgeBase from './pages/KnowledgeBase/KnowledgeBase';
import KBSuggestions from './pages/KnowledgeBase/KBSuggestions';
import Chatbot from './pages/Chatbot/Chatbot';
import AgentPerformance from './pages/Infrastructure/AgentPerformance';
import WorkloadManagement from './pages/Infrastructure/WorkloadManagement';
import TeamAnalytics from './pages/Infrastructure/TeamAnalytics';
import SecurityDashboard from './pages/Security/SecurityDashboard';
import ReportIncident from './pages/Security/ReportIncident';
import ActiveThreats from './pages/Security/ActiveThreats';
import './App.css';

function App() {
  return (
    <ThemeProvider theme={fioriTheme}>
      <CssBaseline />
      <SnackbarProvider 
        maxSnack={3}
        anchorOrigin={{
          vertical: 'top',
          horizontal: 'right',
        }}
        autoHideDuration={4000}
      >
        <Router>
          <Layout>
            <Routes>
              {/* Dashboard */}
              <Route path="/" element={<Dashboard />} />
              <Route path="/dashboard" element={<Dashboard />} />
              
              {/* Service Desk Routes */}
              <Route path="/tickets" element={<TicketList />} />
              <Route path="/tickets/create" element={<CreateTicket />} />
              <Route path="/tickets/:ticketId" element={<TicketDetail />} />
              
              {/* Knowledge Base Routes */}
              <Route path="/knowledge-base" element={<KnowledgeBase />} />
              <Route path="/knowledge-base/suggestions" element={<KBSuggestions />} />
              <Route path="/knowledge-base/article/:articleId" element={<KnowledgeBase />} />
              
              {/* Chatbot Route */}
              <Route path="/chatbot" element={<Chatbot />} />
              
              {/* Module 2: Infrastructure & Talent Management Routes */}
              <Route path="/infrastructure/performance" element={<AgentPerformance />} />
              <Route path="/infrastructure/workload" element={<WorkloadManagement />} />
              <Route path="/infrastructure/analytics" element={<TeamAnalytics />} />
              
              {/* Module 3: Security & Threat Intelligence Routes */}
              <Route path="/security/dashboard" element={<SecurityDashboard />} />
              <Route path="/security/report" element={<ReportIncident />} />
              <Route path="/security/threats" element={<ActiveThreats />} />
              
              {/* Legacy/Fallback Routes */}
              <Route path="/analytics" element={<Dashboard />} />
              <Route path="/infrastructure" element={<AgentPerformance />} />
              <Route path="/security" element={<SecurityDashboard />} />
              
              {/* Fallback */}
              <Route path="*" element={<Dashboard />} />
            </Routes>
          </Layout>
        </Router>
      </SnackbarProvider>
    </ThemeProvider>
  );
}

export default App;

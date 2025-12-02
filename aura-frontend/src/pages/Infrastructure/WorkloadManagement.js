import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Grid,
  Avatar,
  Chip,
  LinearProgress,
  Button,
  IconButton,
  Tooltip,
  useTheme,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
} from '@mui/material';
import {
  CalendarToday as CalendarIcon,
  Person as PersonIcon,
  SwapHoriz as SwapIcon,
  Refresh as RefreshIcon,
  TrendingUp as TrendingUpIcon,
  Warning as WarningIcon,
} from '@mui/icons-material';

const WorkloadManagement = () => {
  const theme = useTheme();
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [workloadData, setWorkloadData] = useState(null);
  const [reassignDialogOpen, setReassignDialogOpen] = useState(false);
  const [selectedTicket, setSelectedTicket] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchWorkloadData();
  }, [selectedDate]);

  const fetchWorkloadData = async () => {
    setLoading(true);
    
    // Mock data - will be replaced with actual API call
    setTimeout(() => {
      const mockData = {
        date: selectedDate.toISOString().split('T')[0],
        day_of_week: selectedDate.toLocaleDateString('en-US', { weekday: 'long' }),
        agents: [
          {
            agent_id: 'agent_001',
            name: 'John Doe',
            avatar_color: '#1976d2',
            tickets_count: 5,
            estimated_hours: 18,
            workload_percent: 62.5,
            status: 'available',
            status_color: '#4caf50'
          },
          {
            agent_id: 'agent_002',
            name: 'Jane Smith',
            avatar_color: '#388e3c',
            tickets_count: 7,
            estimated_hours: 28,
            workload_percent: 87.5,
            status: 'busy',
            status_color: '#ff9800'
          },
          {
            agent_id: 'agent_003',
            name: 'Mike Johnson',
            avatar_color: '#f57c00',
            tickets_count: 9,
            estimated_hours: 35,
            workload_percent: 109,
            status: 'overloaded',
            status_color: '#f44336'
          },
          {
            agent_id: 'agent_004',
            name: 'Sarah Williams',
            avatar_color: '#7b1fa2',
            tickets_count: 4,
            estimated_hours: 15,
            workload_percent: 46.9,
            status: 'available',
            status_color: '#4caf50'
          },
          {
            agent_id: 'agent_005',
            name: 'David Brown',
            avatar_color: '#d32f2f',
            tickets_count: 6,
            estimated_hours: 24,
            workload_percent: 75.0,
            status: 'busy',
            status_color: '#ff9800'
          },
        ],
        summary: {
          total_tickets: 31,
          avg_workload_percent: 76.2,
          available_agents: 2,
          busy_agents: 2,
          overloaded_agents: 1
        }
      };

      setWorkloadData(mockData);
      setLoading(false);
    }, 500);
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'available':
        return theme.palette.success.main;
      case 'busy':
        return theme.palette.warning.main;
      case 'overloaded':
        return theme.palette.error.main;
      default:
        return theme.palette.grey[500];
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'overloaded':
        return <WarningIcon fontSize="small" />;
      case 'busy':
        return <TrendingUpIcon fontSize="small" />;
      default:
        return null;
    }
  };

  const handleReassignTicket = (agent) => {
    // This would open a dialog to reassign tickets
    setSelectedTicket({ agent_id: agent.agent_id, agent_name: agent.name });
    setReassignDialogOpen(true);
  };

  const handleReassignConfirm = () => {
    // TODO: API call to reassign ticket
    setReassignDialogOpen(false);
    // Refresh data
    fetchWorkloadData();
  };

  if (loading) {
    return (
      <Box sx={{ p: 3 }}>
        <Typography variant="h4">Loading...</Typography>
        <LinearProgress sx={{ mt: 2 }} />
      </Box>
    );
  }

  return (
    <Box className="fade-in">
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>
            Workload Management
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Monitor and balance team workload in real-time
          </Typography>
        </Box>
        
        <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
          <Typography variant="body2" color="text.secondary">
            {workloadData?.day_of_week}, {new Date(workloadData?.date).toLocaleDateString()}
          </Typography>
          <Tooltip title="Refresh Data">
            <IconButton onClick={fetchWorkloadData} color="primary">
              <RefreshIcon />
            </IconButton>
          </Tooltip>
        </Box>
      </Box>

      {/* Summary Cards */}
      {workloadData?.summary && (
        <Grid container spacing={3} sx={{ mb: 3 }}>
          <Grid item xs={12} sm={6} md={3}>
            <Card sx={{ bgcolor: theme.palette.success.light }}>
              <CardContent>
                <Typography variant="h6" sx={{ fontWeight: 600, color: theme.palette.success.dark }}>
                  {workloadData.summary.available_agents}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Available Agents
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card sx={{ bgcolor: theme.palette.warning.light }}>
              <CardContent>
                <Typography variant="h6" sx={{ fontWeight: 600, color: theme.palette.warning.dark }}>
                  {workloadData.summary.busy_agents}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Busy Agents
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card sx={{ bgcolor: theme.palette.error.light }}>
              <CardContent>
                <Typography variant="h6" sx={{ fontWeight: 600, color: theme.palette.error.dark }}>
                  {workloadData.summary.overloaded_agents}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Overloaded Agents
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Typography variant="h6" sx={{ fontWeight: 600 }}>
                  {workloadData.summary.avg_workload_percent.toFixed(1)}%
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Avg Team Capacity
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}

      {/* Agent Workload Cards */}
      <Card>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 600, mb: 3 }}>
            Agent Capacity Overview
          </Typography>

          <Grid container spacing={2}>
            {workloadData?.agents.map((agent) => (
              <Grid item xs={12} key={agent.agent_id}>
                <Card variant="outlined">
                  <CardContent>
                    <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                        <Avatar 
                          sx={{ 
                            bgcolor: agent.avatar_color,
                            width: 48,
                            height: 48
                          }}
                        >
                          {agent.name.split(' ').map(n => n[0]).join('')}
                        </Avatar>
                        <Box>
                          <Typography variant="body1" sx={{ fontWeight: 600 }}>
                            {agent.name}
                          </Typography>
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Chip 
                              label={agent.status.toUpperCase()}
                              size="small"
                              icon={getStatusIcon(agent.status)}
                              sx={{ 
                                bgcolor: agent.status_color,
                                color: 'white',
                                fontWeight: 600,
                                fontSize: '0.7rem'
                              }}
                            />
                            <Typography variant="caption" color="text.secondary">
                              {agent.tickets_count} tickets • {agent.estimated_hours.toFixed(0)}h estimated
                            </Typography>
                          </Box>
                        </Box>
                      </Box>

                      {agent.workload_percent > 90 && (
                        <Button
                          variant="outlined"
                          size="small"
                          startIcon={<SwapIcon />}
                          onClick={() => handleReassignTicket(agent)}
                        >
                          Reassign Tickets
                        </Button>
                      )}
                    </Box>

                    {/* Workload Progress Bar */}
                    <Box>
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                        <Typography variant="body2" color="text.secondary">
                          Capacity Utilization
                        </Typography>
                        <Typography 
                          variant="body2" 
                          sx={{ 
                            fontWeight: 600,
                            color: agent.workload_percent > 100 ? theme.palette.error.main :
                                   agent.workload_percent > 80 ? theme.palette.warning.main :
                                   theme.palette.success.main
                          }}
                        >
                          {agent.workload_percent.toFixed(1)}%
                        </Typography>
                      </Box>
                      <LinearProgress 
                        variant="determinate" 
                        value={Math.min(100, agent.workload_percent)}
                        sx={{
                          height: 10,
                          borderRadius: 5,
                          bgcolor: theme.palette.grey[200],
                          '& .MuiLinearProgress-bar': {
                            borderRadius: 5,
                            bgcolor: agent.workload_percent > 100 ? theme.palette.error.main :
                                     agent.workload_percent > 80 ? theme.palette.warning.main :
                                     theme.palette.success.main
                          }
                        }}
                      />
                    </Box>
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>
        </CardContent>
      </Card>

      {/* Legend */}
      <Card sx={{ mt: 3 }}>
        <CardContent>
          <Typography variant="body2" sx={{ fontWeight: 600, mb: 2 }}>
            Capacity Status Guide
          </Typography>
          <Box sx={{ display: 'flex', gap: 3, flexWrap: 'wrap' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Box sx={{ width: 16, height: 16, borderRadius: 1, bgcolor: theme.palette.success.main }} />
              <Typography variant="body2">
                <strong>Available:</strong> &lt; 70% capacity
              </Typography>
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Box sx={{ width: 16, height: 16, borderRadius: 1, bgcolor: theme.palette.warning.main }} />
              <Typography variant="body2">
                <strong>Busy:</strong> 70-90% capacity
              </Typography>
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Box sx={{ width: 16, height: 16, borderRadius: 1, bgcolor: theme.palette.error.main }} />
              <Typography variant="body2">
                <strong>Overloaded:</strong> &gt; 90% capacity
              </Typography>
            </Box>
          </Box>
        </CardContent>
      </Card>

      {/* Reassign Dialog */}
      <Dialog open={reassignDialogOpen} onClose={() => setReassignDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Reassign Tickets</DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 2 }}>
            Select tickets from <strong>{selectedTicket?.agent_name}</strong> to reassign:
          </Typography>
          
          <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
            <InputLabel>Select Ticket</InputLabel>
            <Select label="Select Ticket" defaultValue="">
              <MenuItem value="ticket1">TKT-001: VPN Connection Issue</MenuItem>
              <MenuItem value="ticket2">TKT-002: Email Setup</MenuItem>
              <MenuItem value="ticket3">TKT-003: Software Installation</MenuItem>
            </Select>
          </FormControl>

          <FormControl fullWidth>
            <InputLabel>Reassign To</InputLabel>
            <Select label="Reassign To" defaultValue="">
              {workloadData?.agents
                .filter(a => a.status === 'available')
                .map(agent => (
                  <MenuItem key={agent.agent_id} value={agent.agent_id}>
                    {agent.name} - {agent.workload_percent.toFixed(0)}% capacity
                  </MenuItem>
                ))}
            </Select>
          </FormControl>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setReassignDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleReassignConfirm} variant="contained">
            Reassign
          </Button>
        </DialogActions>
      </Dialog>

      {/* Note */}
      <Box sx={{ mt: 3, p: 2, bgcolor: 'info.light', borderRadius: 1 }}>
        <Typography variant="body2" color="info.dark">
          💡 <strong>Tip:</strong> Workload is calculated based on active tickets and estimated resolution time. 
          The system automatically suggests reassignments when agents are overloaded. 
          Full heat map calendar view coming soon!
        </Typography>
      </Box>
    </Box>
  );
};

export default WorkloadManagement;

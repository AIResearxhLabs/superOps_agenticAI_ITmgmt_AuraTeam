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
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  useTheme,
} from '@mui/material';
import {
  TrendingUp as TrendingUpIcon,
  TrendingDown as TrendingDownIcon,
  Remove as RemoveIcon,
  Star as StarIcon,
  AccessTime as TimeIcon,
  CheckCircle as CheckCircleIcon,
  Assignment as AssignmentIcon,
} from '@mui/icons-material';
import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';

// Register ChartJS components
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

const AgentPerformance = () => {
  const theme = useTheme();
  const [timeframe, setTimeframe] = useState('week');
  const [agents, setAgents] = useState([]);
  const [teamStats, setTeamStats] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // TODO: Replace with actual API call
    fetchPerformanceData();
  }, [timeframe]);

  const fetchPerformanceData = async () => {
    setLoading(true);
    
    // Mock data - will be replaced with actual API call
    setTimeout(() => {
      const mockAgents = [
        {
          agent_id: 'agent_001',
          name: 'John Doe',
          email: 'john.doe@company.com',
          role: 'Senior IT Specialist',
          avatar_color: '#1976d2',
          tier: 'high',
          metrics: {
            resolved_today: 8,
            resolved_this_week: 45,
            resolved_this_month: 180,
            avg_resolution_time_hours: 3.2,
            satisfaction_score: 4.8,
            current_active_tickets: 5,
            performance_trend: 'improving'
          }
        },
        {
          agent_id: 'agent_002',
          name: 'Jane Smith',
          email: 'jane.smith@company.com',
          role: 'IT Specialist',
          avatar_color: '#388e3c',
          tier: 'average',
          metrics: {
            resolved_today: 6,
            resolved_this_week: 38,
            resolved_this_month: 152,
            avg_resolution_time_hours: 5.5,
            satisfaction_score: 4.5,
            current_active_tickets: 7,
            performance_trend: 'stable'
          }
        },
        {
          agent_id: 'agent_003',
          name: 'Mike Johnson',
          email: 'mike.j@company.com',
          role: 'IT Support Specialist',
          avatar_color: '#f57c00',
          tier: 'new',
          metrics: {
            resolved_today: 3,
            resolved_this_week: 20,
            resolved_this_month: 85,
            avg_resolution_time_hours: 8.5,
            satisfaction_score: 4.2,
            current_active_tickets: 9,
            performance_trend: 'improving'
          }
        },
      ];

      const mockTeamStats = {
        team_size: 12,
        total_resolved_this_week: 342,
        team_avg_satisfaction: 4.44,
        team_avg_resolution_time: 6.0,
        capacity_utilization: 63.5
      };

      setAgents(mockAgents);
      setTeamStats(mockTeamStats);
      setLoading(false);
    }, 500);
  };

  const getTrendIcon = (trend) => {
    switch (trend) {
      case 'improving':
        return <TrendingUpIcon sx={{ color: theme.palette.success.main, fontSize: '1rem' }} />;
      case 'declining':
        return <TrendingDownIcon sx={{ color: theme.palette.error.main, fontSize: '1rem' }} />;
      default:
        return <RemoveIcon sx={{ color: theme.palette.grey[500], fontSize: '1rem' }} />;
    }
  };

  const getTierColor = (tier) => {
    switch (tier) {
      case 'high':
        return theme.palette.success.main;
      case 'average':
        return theme.palette.info.main;
      case 'new':
        return theme.palette.warning.main;
      default:
        return theme.palette.grey[500];
    }
  };

  const getTierLabel = (tier) => {
    switch (tier) {
      case 'high':
        return 'High Performer';
      case 'average':
        return 'Average';
      case 'new':
        return 'New Agent';
      default:
        return 'Unknown';
    }
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
            Agent Performance Dashboard
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Track individual and team performance metrics
          </Typography>
        </Box>
        
        <FormControl sx={{ minWidth: 150 }}>
          <InputLabel>Timeframe</InputLabel>
          <Select
            value={timeframe}
            label="Timeframe"
            onChange={(e) => setTimeframe(e.target.value)}
          >
            <MenuItem value="today">Today</MenuItem>
            <MenuItem value="week">This Week</MenuItem>
            <MenuItem value="month">This Month</MenuItem>
            <MenuItem value="quarter">This Quarter</MenuItem>
          </Select>
        </FormControl>
      </Box>

      {/* Team Summary Cards */}
      {teamStats && (
        <Grid container spacing={3} sx={{ mb: 3 }}>
          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                  <AssignmentIcon sx={{ mr: 1, color: theme.palette.primary.main }} />
                  <Typography variant="body2" color="text.secondary">
                    Total Resolved
                  </Typography>
                </Box>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>
                  {teamStats.total_resolved_this_week}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  This week
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                  <StarIcon sx={{ mr: 1, color: theme.palette.warning.main }} />
                  <Typography variant="body2" color="text.secondary">
                    Team Satisfaction
                  </Typography>
                </Box>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>
                  {teamStats.team_avg_satisfaction.toFixed(2)}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Out of 5.0
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                  <TimeIcon sx={{ mr: 1, color: theme.palette.info.main }} />
                  <Typography variant="body2" color="text.secondary">
                    Avg Resolution Time
                  </Typography>
                </Box>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>
                  {teamStats.team_avg_resolution_time}h
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Team average
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                  <CheckCircleIcon sx={{ mr: 1, color: theme.palette.success.main }} />
                  <Typography variant="body2" color="text.secondary">
                    Capacity Utilization
                  </Typography>
                </Box>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>
                  {teamStats.capacity_utilization}%
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Of team capacity
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}

      {/* Agent Performance Table */}
      <Card>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
            Individual Agent Performance
          </Typography>
          
          <TableContainer component={Paper} elevation={0}>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Agent</TableCell>
                  <TableCell>Performance Tier</TableCell>
                  <TableCell align="right">Resolved Today</TableCell>
                  <TableCell align="right">Resolved This Week</TableCell>
                  <TableCell align="right">Avg Resolution Time</TableCell>
                  <TableCell align="right">Satisfaction Score</TableCell>
                  <TableCell align="right">Active Tickets</TableCell>
                  <TableCell align="center">Trend</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {agents.map((agent) => (
                  <TableRow key={agent.agent_id} hover>
                    <TableCell>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                        <Avatar 
                          sx={{ 
                            bgcolor: agent.avatar_color,
                            width: 40,
                            height: 40
                          }}
                        >
                          {agent.name.split(' ').map(n => n[0]).join('')}
                        </Avatar>
                        <Box>
                          <Typography variant="body2" sx={{ fontWeight: 600 }}>
                            {agent.name}
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            {agent.role}
                          </Typography>
                        </Box>
                      </Box>
                    </TableCell>
                    <TableCell>
                      <Chip 
                        label={getTierLabel(agent.tier)}
                        size="small"
                        sx={{ 
                          bgcolor: getTierColor(agent.tier),
                          color: 'white',
                          fontWeight: 500
                        }}
                      />
                    </TableCell>
                    <TableCell align="right">
                      <Typography variant="body2" sx={{ fontWeight: 600 }}>
                        {agent.metrics.resolved_today}
                      </Typography>
                    </TableCell>
                    <TableCell align="right">
                      <Typography variant="body2" sx={{ fontWeight: 600 }}>
                        {agent.metrics.resolved_this_week}
                      </Typography>
                    </TableCell>
                    <TableCell align="right">
                      <Typography variant="body2">
                        {agent.metrics.avg_resolution_time_hours}h
                      </Typography>
                    </TableCell>
                    <TableCell align="right">
                      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 0.5 }}>
                        <StarIcon sx={{ fontSize: '1rem', color: theme.palette.warning.main }} />
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                          {agent.metrics.satisfaction_score}
                        </Typography>
                      </Box>
                    </TableCell>
                    <TableCell align="right">
                      <Chip 
                        label={agent.metrics.current_active_tickets}
                        size="small"
                        color={agent.metrics.current_active_tickets > 8 ? 'error' : 
                               agent.metrics.current_active_tickets > 5 ? 'warning' : 'success'}
                      />
                    </TableCell>
                    <TableCell align="center">
                      {getTrendIcon(agent.metrics.performance_trend)}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </CardContent>
      </Card>

      {/* Note about data */}
      <Box sx={{ mt: 3, p: 2, bgcolor: 'info.light', borderRadius: 1 }}>
        <Typography variant="body2" color="info.dark">
          💡 <strong>Note:</strong> This dashboard displays real-time performance metrics. 
          Data is automatically refreshed every 5 minutes. Full API integration coming soon with historical trends and detailed analytics.
        </Typography>
      </Box>
    </Box>
  );
};

export default AgentPerformance;

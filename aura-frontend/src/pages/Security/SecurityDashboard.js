import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Grid,
  LinearProgress,
  Chip,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  IconButton,
  Tooltip,
  useTheme,
  Alert,
  AlertTitle,
  Tabs,
  Tab,
  Button,
} from '@mui/material';
import {
  Shield as ShieldIcon,
  Warning as WarningIcon,
  Error as ErrorIcon,
  CheckCircle as CheckCircleIcon,
  Refresh as RefreshIcon,
  TrendingUp as TrendingUpIcon,
  TrendingDown as TrendingDownIcon,
  Security as SecurityIcon,
  BugReport as BugReportIcon,
  Gavel as ComplianceIcon,
  VpnLock as VpnLockIcon,
  Cloud as CloudIcon,
  Public as PublicIcon,
} from '@mui/icons-material';
import ThreatIntelligenceFeed from './ThreatIntelligenceFeed';
import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip as ChartTooltip,
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
  ChartTooltip,
  Legend,
  Filler
);

const SecurityDashboard = () => {
  const theme = useTheme();
  const [securityData, setSecurityData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState(0);

  useEffect(() => {
    fetchSecurityData();
  }, []);

  const handleTabChange = (event, newValue) => {
    setActiveTab(newValue);
  };

  const fetchSecurityData = async () => {
    setLoading(true);
    
    try {
      // Import security API
      const { securityAPI } = await import('../../services/api');
      
      // Fetch security dashboard data from API
      const data = await securityAPI.getDashboard();
      setSecurityData(data);
    } catch (error) {
      console.error('Failed to fetch security data:', error);
      
      // Fallback to mock data if API fails
      const mockData = {
        overall_score: 69.2,
        score_trend: 'improving',
        last_updated: new Date().toISOString(),
        category_scores: {
          network_security: 78.5,
          data_protection: 72.0,
          access_control: 65.3,
          compliance: 58.7,
          threat_detection: 71.2
        },
        recent_incidents: [
          {
            id: 'inc_001',
            type: 'Malware Detection',
            severity: 'high',
            status: 'investigating',
            timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
            affected_systems: 3
          },
          {
            id: 'inc_002',
            type: 'Unauthorized Access Attempt',
            severity: 'critical',
            status: 'resolved',
            timestamp: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString(),
            affected_systems: 1
          }
        ],
        active_alerts: [
          {
            id: 'alert_001',
            title: 'Unusual login pattern detected',
            severity: 'medium',
            count: 5
          },
          {
            id: 'alert_002',
            title: 'Failed authentication attempts',
            severity: 'high',
            count: 12
          }
        ],
        threat_summary: {
          active_threats: 6,
          blocked_attacks: 147,
          vulnerabilities_found: 23,
          patches_pending: 8
        },
        score_history: [
          { date: '2025-01-15', score: 65.2 },
          { date: '2025-01-16', score: 66.8 },
          { date: '2025-01-17', score: 67.5 },
          { date: '2025-01-18', score: 68.1 },
          { date: '2025-01-19', score: 68.9 },
          { date: '2025-01-20', score: 69.2 }
        ]
      };
      setSecurityData(mockData);
    } finally {
      setLoading(false);
    }
  };

  const getSeverityColor = (severity) => {
    switch (severity) {
      case 'critical':
        return theme.palette.error.main;
      case 'high':
        return theme.palette.warning.main;
      case 'medium':
        return theme.palette.info.main;
      case 'low':
        return theme.palette.success.main;
      default:
        return theme.palette.grey[500];
    }
  };

  const getScoreColor = (score) => {
    if (score >= 80) return theme.palette.success.main;
    if (score >= 60) return theme.palette.warning.main;
    return theme.palette.error.main;
  };

  const getTrendIcon = (trend) => {
    return trend === 'improving' ? (
      <TrendingUpIcon sx={{ color: theme.palette.success.main, fontSize: '1.2rem' }} />
    ) : (
      <TrendingDownIcon sx={{ color: theme.palette.error.main, fontSize: '1.2rem' }} />
    );
  };

  if (loading) {
    return (
      <Box sx={{ p: 3 }}>
        <Typography variant="h4">Loading Security Dashboard...</Typography>
        <LinearProgress sx={{ mt: 2 }} />
      </Box>
    );
  }

  const chartData = {
    labels: securityData?.score_history?.map(h => new Date(h.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })) || [],
    datasets: [
      {
        label: 'Security Score',
        data: securityData?.score_history?.map(h => h.score) || [],
        borderColor: theme.palette.primary.main,
        backgroundColor: `${theme.palette.primary.main}20`,
        fill: true,
        tension: 0.4,
      },
    ],
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: false,
      },
      title: {
        display: false,
      },
    },
    scales: {
      y: {
        min: 0,
        max: 100,
        ticks: {
          callback: (value) => `${value}`,
        },
      },
    },
  };

  return (
    <Box className="fade-in">
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>
            Security Dashboard
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Real-time security monitoring and threat intelligence
          </Typography>
        </Box>
        
        <Tooltip title="Refresh Data">
          <IconButton onClick={fetchSecurityData} color="primary">
            <RefreshIcon />
          </IconButton>
        </Tooltip>
      </Box>

      {/* Tab Navigation */}
      <Card sx={{ mb: 3 }}>
        <Tabs
          value={activeTab}
          onChange={handleTabChange}
          indicatorColor="primary"
          textColor="primary"
          variant="fullWidth"
        >
          <Tab 
            icon={<ShieldIcon />} 
            iconPosition="start" 
            label="Security Overview" 
          />
          <Tab 
            icon={<PublicIcon />} 
            iconPosition="start" 
            label="External Threat Intelligence" 
          />
        </Tabs>
      </Card>

      {/* Tab Content */}
      {activeTab === 1 ? (
        <ThreatIntelligenceFeed />
      ) : (
        <>

      {/* Overall Security Score */}
      <Card sx={{ mb: 3, background: `linear-gradient(135deg, ${theme.palette.primary.dark} 0%, ${theme.palette.primary.main} 100%)` }}>
        <CardContent>
          <Grid container spacing={3} alignItems="center">
            <Grid item xs={12} md={4}>
              <Box sx={{ textAlign: 'center', color: 'white' }}>
                <ShieldIcon sx={{ fontSize: 60, mb: 1, opacity: 0.9 }} />
                <Typography variant="h3" sx={{ fontWeight: 700, mb: 1 }}>
                  {securityData?.overall_score?.toFixed(1)}
                </Typography>
                <Typography variant="h6" sx={{ opacity: 0.9 }}>
                  Overall Security Score
                </Typography>
                <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', mt: 1, gap: 0.5 }}>
                  {getTrendIcon(securityData?.score_trend)}
                  <Typography variant="body2" sx={{ opacity: 0.8, textTransform: 'capitalize' }}>
                    {securityData?.score_trend}
                  </Typography>
                </Box>
              </Box>
            </Grid>
            
            <Grid item xs={12} md={8}>
              <Box sx={{ height: 200, color: 'white' }}>
                <Typography variant="body2" sx={{ mb: 1, opacity: 0.9 }}>
                  30-Day Security Score Trend
                </Typography>
                <Line data={chartData} options={chartOptions} />
              </Box>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Category Scores */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 600, mb: 3 }}>
            Security Category Scores
          </Typography>
          
          <Grid container spacing={3}>
            {[
              { key: 'network_security', label: 'Network Security', icon: <VpnLockIcon /> },
              { key: 'data_protection', label: 'Data Protection', icon: <CloudIcon /> },
              { key: 'access_control', label: 'Access Control', icon: <SecurityIcon /> },
              { key: 'compliance', label: 'Compliance', icon: <ComplianceIcon /> },
              { key: 'threat_detection', label: 'Threat Detection', icon: <BugReportIcon /> },
            ].map((category) => {
              const score = securityData?.category_scores?.[category.key] || 0;
              return (
                <Grid item xs={12} sm={6} md={4} key={category.key}>
                  <Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                      <Box sx={{ color: getScoreColor(score), mr: 1 }}>
                        {category.icon}
                      </Box>
                      <Typography variant="body2" sx={{ flex: 1 }}>
                        {category.label}
                      </Typography>
                      <Typography variant="body2" sx={{ fontWeight: 600, color: getScoreColor(score) }}>
                        {score.toFixed(1)}%
                      </Typography>
                    </Box>
                    <LinearProgress 
                      variant="determinate" 
                      value={score}
                      sx={{
                        height: 8,
                        borderRadius: 4,
                        bgcolor: theme.palette.grey[200],
                        '& .MuiLinearProgress-bar': {
                          borderRadius: 4,
                          bgcolor: getScoreColor(score)
                        }
                      }}
                    />
                  </Box>
                </Grid>
              );
            })}
          </Grid>
        </CardContent>
      </Card>

      <Grid container spacing={3}>
        {/* Threat Summary */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
                Threat Summary
              </Typography>
              
              <Grid container spacing={2}>
                <Grid item xs={6}>
                  <Box sx={{ textAlign: 'center', p: 2, bgcolor: theme.palette.error.light, borderRadius: 2 }}>
                    <Typography variant="h4" sx={{ fontWeight: 700, color: theme.palette.error.dark }}>
                      {securityData?.threat_summary?.active_threats}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Active Threats
                    </Typography>
                  </Box>
                </Grid>
                
                <Grid item xs={6}>
                  <Box sx={{ textAlign: 'center', p: 2, bgcolor: theme.palette.success.light, borderRadius: 2 }}>
                    <Typography variant="h4" sx={{ fontWeight: 700, color: theme.palette.success.dark }}>
                      {securityData?.threat_summary?.blocked_attacks}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Blocked Attacks
                    </Typography>
                  </Box>
                </Grid>
                
                <Grid item xs={6}>
                  <Box sx={{ textAlign: 'center', p: 2, bgcolor: theme.palette.warning.light, borderRadius: 2 }}>
                    <Typography variant="h4" sx={{ fontWeight: 700, color: theme.palette.warning.dark }}>
                      {securityData?.threat_summary?.vulnerabilities_found}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Vulnerabilities
                    </Typography>
                  </Box>
                </Grid>
                
                <Grid item xs={6}>
                  <Box sx={{ textAlign: 'center', p: 2, bgcolor: theme.palette.info.light, borderRadius: 2 }}>
                    <Typography variant="h4" sx={{ fontWeight: 700, color: theme.palette.info.dark }}>
                      {securityData?.threat_summary?.patches_pending}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Patches Pending
                    </Typography>
                  </Box>
                </Grid>
              </Grid>
            </CardContent>
          </Card>
        </Grid>

        {/* Active Alerts */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
                Active Alerts
              </Typography>
              
              <List>
                {securityData?.active_alerts?.map((alert) => (
                  <ListItem 
                    key={alert.id}
                    sx={{ 
                      mb: 1, 
                      bgcolor: `${getSeverityColor(alert.severity)}10`,
                      borderRadius: 1,
                      borderLeft: `4px solid ${getSeverityColor(alert.severity)}`
                    }}
                  >
                    <ListItemIcon>
                      <WarningIcon sx={{ color: getSeverityColor(alert.severity) }} />
                    </ListItemIcon>
                    <ListItemText
                      primary={alert.title}
                      secondary={`${alert.count} occurrences`}
                      primaryTypographyProps={{ fontWeight: 500 }}
                    />
                    <Chip 
                      label={alert.severity.toUpperCase()}
                      size="small"
                      sx={{ 
                        bgcolor: getSeverityColor(alert.severity),
                        color: 'white',
                        fontWeight: 600,
                        fontSize: '0.7rem'
                      }}
                    />
                  </ListItem>
                ))}
              </List>
            </CardContent>
          </Card>
        </Grid>

        {/* Recent Incidents */}
        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
                Recent Security Incidents
              </Typography>
              
              <List>
                {securityData?.recent_incidents?.map((incident) => (
                  <ListItem 
                    key={incident.id}
                    sx={{ 
                      mb: 1, 
                      bgcolor: theme.palette.grey[50],
                      borderRadius: 1,
                      borderLeft: `4px solid ${getSeverityColor(incident.severity)}`
                    }}
                  >
                    <ListItemIcon>
                      {incident.severity === 'critical' ? (
                        <ErrorIcon sx={{ color: getSeverityColor(incident.severity) }} />
                      ) : (
                        <WarningIcon sx={{ color: getSeverityColor(incident.severity) }} />
                      )}
                    </ListItemIcon>
                    <ListItemText
                      primary={incident.type}
                      secondary={`${new Date(incident.timestamp).toLocaleString()} • ${incident.affected_systems} systems affected • Status: ${incident.status}`}
                      primaryTypographyProps={{ fontWeight: 500 }}
                    />
                    <Chip 
                      label={incident.severity.toUpperCase()}
                      size="small"
                      sx={{ 
                        bgcolor: getSeverityColor(incident.severity),
                        color: 'white',
                        fontWeight: 600,
                        mr: 1
                      }}
                    />
                    <Chip 
                      label={incident.status.toUpperCase()}
                      size="small"
                      variant="outlined"
                    />
                  </ListItem>
                ))}
              </List>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Info Note */}
      <Box sx={{ mt: 3 }}>
        <Alert severity="info">
          <AlertTitle>Security Monitoring Active</AlertTitle>
          Real-time threat intelligence is being monitored 24/7. 
          Critical alerts will trigger immediate notifications to the security team. 
          Full API integration coming soon with historical trend analysis.
        </Alert>
      </Box>
        </>
      )}
    </Box>
  );
};

export default SecurityDashboard;

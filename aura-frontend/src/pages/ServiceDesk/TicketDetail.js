import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  Grid,
  Chip,
  CircularProgress,
  Alert,
  Divider,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  Avatar,
  Paper,
  LinearProgress,
  IconButton,
  Tooltip,
} from '@mui/material';
import {
  ArrowBack as ArrowBackIcon,
  Psychology as PsychologyIcon,
  Person as PersonIcon,
  Schedule as ScheduleIcon,
  Category as CategoryIcon,
  Flag as FlagIcon,
  CheckCircle as CheckCircleIcon,
  Lightbulb as LightbulbIcon,
  TrendingUp as TrendingUpIcon,
  AccessTime as AccessTimeIcon,
  Refresh as RefreshIcon,
} from '@mui/icons-material';
import { useParams, useNavigate } from 'react-router-dom';
import { apiWithFallback, serviceDeskAPI } from '../../services/api';
import { useSnackbar } from 'notistack';

const TicketDetail = () => {
  const { ticketId } = useParams();
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();

  const [loading, setLoading] = useState(true);
  const [analyzing, setAnalyzing] = useState(false);
  const [ticket, setTicket] = useState(null);
  const [aiAnalysis, setAiAnalysis] = useState(null);

  // Load ticket details
  const loadTicket = async () => {
    try {
      setLoading(true);
      const response = await apiWithFallback.getTicket(ticketId);
      // Handle both API response format (direct ticket) and fallback format (wrapped in data)
      const ticketData = response.data || response;
      setTicket(ticketData);
    } catch (error) {
      enqueueSnackbar('Failed to load ticket details', { variant: 'error' });
      console.error('Load ticket error:', error);
    } finally {
      setLoading(false);
    }
  };

  // Analyze ticket with AI
  const analyzeTicket = async () => {
    if (!ticketId) {
      enqueueSnackbar('No ticket ID available for analysis', { variant: 'error' });
      return;
    }

    try {
      setAnalyzing(true);
      console.log('Analyzing ticket with ID:', ticketId);
      const response = await serviceDeskAPI.analyzeTicket(ticketId);
      // Handle both API response format (direct analysis) and fallback format (wrapped in data)
      const analysisData = response.analysis || response.data?.analysis || response;
      setAiAnalysis(analysisData.analysis || analysisData);
      enqueueSnackbar('AI analysis completed successfully', { variant: 'success' });
    } catch (error) {
      enqueueSnackbar('Failed to analyze ticket with AI', { variant: 'error' });
      console.error('AI analysis error:', error);
    } finally {
      setAnalyzing(false);
    }
  };

  useEffect(() => {
    loadTicket();
  }, [ticketId]);

  const getStatusColor = (status) => {
    switch (status) {
      case 'open': return 'info';
      case 'in_progress': return 'warning';
      case 'resolved': return 'success';
      case 'closed': return 'default';
      default: return 'default';
    }
  };

  const getPriorityColor = (priority) => {
    switch (priority) {
      case 'low': return 'success';
      case 'medium': return 'warning';
      case 'high': return 'error';
      case 'critical': return 'error';
      default: return 'default';
    }
  };

  const formatDateTime = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  if (!ticket) {
    return (
      <Box>
        <Alert severity="error">Ticket not found</Alert>
      </Box>
    );
  }

  return (
    <Box className="fade-in">
      {/* Header */}
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
        <IconButton onClick={() => navigate('/tickets')} sx={{ mr: 2 }}>
          <ArrowBackIcon />
        </IconButton>
        <Box sx={{ flexGrow: 1 }}>
          <Typography variant="h4" sx={{ fontWeight: 600 }}>
            Ticket #{ticketId}
          </Typography>
          <Typography variant="h6" color="text.secondary">
            {ticket.title}
          </Typography>
        </Box>
        <Button
          variant="contained"
          startIcon={analyzing ? <CircularProgress size={20} /> : <PsychologyIcon />}
          onClick={analyzeTicket}
          disabled={analyzing}
          color="primary"
        >
          {analyzing ? 'Analyzing...' : 'AI Analysis'}
        </Button>
      </Box>

      <Grid container spacing={3}>
        {/* Main Ticket Information */}
        <Grid item xs={12} md={8}>
          <Card sx={{ mb: 3 }}>
            <CardContent>
              <Box sx={{ display: 'flex', gap: 1, mb: 3, flexWrap: 'wrap' }}>
                <Chip
                  label={(ticket.status || 'unknown').replace('_', ' ').toUpperCase()}
                  color={getStatusColor(ticket.status)}
                  variant="filled"
                />
                <Chip
                  label={(ticket.priority || 'unknown').toUpperCase()}
                  color={getPriorityColor(ticket.priority)}
                  variant="outlined"
                />
                <Chip
                  label={ticket.category || 'Uncategorized'}
                  icon={<CategoryIcon />}
                  variant="outlined"
                />
              </Box>

              <Typography variant="h6" sx={{ mb: 2 }}>
                Description
              </Typography>
              <Typography variant="body1" sx={{ mb: 3, whiteSpace: 'pre-wrap' }}>
                {ticket.description || 'No description provided'}
              </Typography>

              <Divider sx={{ my: 3 }} />

              <Grid container spacing={2}>
                <Grid item xs={12} sm={6}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Requester
                  </Typography>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mt: 1 }}>
                    <Avatar sx={{ width: 32, height: 32 }}>
                      {(ticket.user_name || ticket.requester || 'Unknown').charAt(0)}
                    </Avatar>
                    <Box>
                      <Typography variant="body2">
                        {ticket.user_name || ticket.requester || 'Unknown'}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {ticket.user_email || ticket.requester || 'No email'}
                      </Typography>
                    </Box>
                  </Box>
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Department
                  </Typography>
                  <Typography variant="body2" sx={{ mt: 1 }}>
                    {ticket.department || 'Not specified'}
                  </Typography>
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Created At
                  </Typography>
                  <Typography variant="body2" sx={{ mt: 1 }}>
                    {ticket.created_at ? formatDateTime(ticket.created_at) : 'Unknown'}
                  </Typography>
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Last Updated
                  </Typography>
                  <Typography variant="body2" sx={{ mt: 1 }}>
                    {ticket.updated_at ? formatDateTime(ticket.updated_at) : 'Unknown'}
                  </Typography>
                </Grid>
              </Grid>

              {ticket.assigned_to && (
                <Box sx={{ mt: 3 }}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Assigned To
                  </Typography>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mt: 1 }}>
                    <PersonIcon sx={{ fontSize: 20, color: 'text.secondary' }} />
                    <Typography variant="body2">{ticket.assigned_to}</Typography>
                  </Box>
                </Box>
              )}

              {ticket.resolution && (
                <Box sx={{ mt: 3 }}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Resolution
                  </Typography>
                  <Paper sx={{ p: 2, mt: 1, bgcolor: 'success.light', color: 'success.contrastText' }}>
                    <Typography variant="body2">{ticket.resolution}</Typography>
                  </Paper>
                </Box>
              )}
            </CardContent>
          </Card>
        </Grid>

        {/* AI Analysis Panel */}
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                <PsychologyIcon sx={{ mr: 1, color: 'primary.main' }} />
                <Typography variant="h6">AI Analysis</Typography>
                {aiAnalysis && (
                  <Tooltip title="Refresh Analysis">
                    <IconButton onClick={analyzeTicket} size="small" sx={{ ml: 'auto' }}>
                      <RefreshIcon />
                    </IconButton>
                  </Tooltip>
                )}
              </Box>

              {analyzing && (
                <Box sx={{ mb: 2 }}>
                  <Typography variant="body2" sx={{ mb: 1 }}>
                    Analyzing ticket with AI...
                  </Typography>
                  <LinearProgress />
                </Box>
              )}

              {!aiAnalysis && !analyzing && (
                <Alert severity="info" sx={{ mb: 2 }}>
                  Click "AI Analysis" to get intelligent recommendations for this ticket.
                </Alert>
              )}

              {aiAnalysis && (
                <Box>
                  {/* Suggested Processor */}
                  {aiAnalysis.suggested_processor && (
                    <Paper sx={{ p: 2, mb: 2, border: '1px solid', borderColor: 'primary.light' }}>
                      <Typography variant="subtitle2" sx={{ mb: 1, display: 'flex', alignItems: 'center' }}>
                        <PersonIcon sx={{ mr: 1, fontSize: 18 }} />
                        Suggested Processor
                      </Typography>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                        <Avatar sx={{ width: 24, height: 24, fontSize: '0.75rem' }}>
                          {(aiAnalysis.suggested_processor?.name || 'U').charAt(0).toUpperCase()}
                        </Avatar>
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                          {aiAnalysis.suggested_processor?.name || 'Unassigned'}
                        </Typography>
                        {aiAnalysis.suggested_processor?.confidence !== undefined && (
                          <Chip 
                            label={`${Math.round((aiAnalysis.suggested_processor.confidence || 0) * 100)}%`}
                            size="small"
                            color="primary"
                          />
                        )}
                      </Box>
                      {aiAnalysis.suggested_processor?.reason && (
                        <Typography variant="caption" color="text.secondary">
                          {aiAnalysis.suggested_processor.reason}
                        </Typography>
                      )}
                    </Paper>
                  )}

                  {/* Self-Fix Suggestions */}
                  {aiAnalysis.self_fix_suggestions && Array.isArray(aiAnalysis.self_fix_suggestions) && aiAnalysis.self_fix_suggestions.length > 0 && (
                    <Paper sx={{ p: 2, mb: 2, border: '1px solid', borderColor: 'success.light' }}>
                      <Typography variant="subtitle2" sx={{ mb: 1, display: 'flex', alignItems: 'center' }}>
                        <LightbulbIcon sx={{ mr: 1, fontSize: 18 }} />
                        Self-Fix Suggestions
                      </Typography>
                      <List dense>
                        {aiAnalysis.self_fix_suggestions.map((suggestion, index) => (
                          <ListItem key={index} sx={{ px: 0 }}>
                            <ListItemIcon sx={{ minWidth: 24 }}>
                              <CheckCircleIcon sx={{ fontSize: 16, color: 'success.main' }} />
                            </ListItemIcon>
                            <ListItemText 
                              primary={suggestion}
                              primaryTypographyProps={{ variant: 'caption' }}
                            />
                          </ListItem>
                        ))}
                      </List>
                    </Paper>
                  )}

                  {/* Estimated Resolution Time */}
                  {aiAnalysis.estimated_resolution_time && (
                    <Paper sx={{ p: 2, mb: 2, border: '1px solid', borderColor: 'warning.light' }}>
                      <Typography variant="subtitle2" sx={{ mb: 1, display: 'flex', alignItems: 'center' }}>
                        <AccessTimeIcon sx={{ mr: 1, fontSize: 18 }} />
                        Estimated Resolution Time
                      </Typography>
                      <Typography variant="body2">{aiAnalysis.estimated_resolution_time}</Typography>
                    </Paper>
                  )}

                  {/* Priority Recommendation */}
                  {aiAnalysis.priority_recommendation && (
                    <Paper sx={{ p: 2, mb: 2, border: '1px solid', borderColor: 'info.light' }}>
                      <Typography variant="subtitle2" sx={{ mb: 1, display: 'flex', alignItems: 'center' }}>
                        <FlagIcon sx={{ mr: 1, fontSize: 18 }} />
                        Priority Recommendation
                      </Typography>
                      <Typography variant="body2">{aiAnalysis.priority_recommendation}</Typography>
                    </Paper>
                  )}

                  {/* Similar Tickets */}
                  {aiAnalysis.similar_tickets && Array.isArray(aiAnalysis.similar_tickets) && aiAnalysis.similar_tickets.length > 0 && (
                    <Paper sx={{ p: 2, mb: 2, border: '1px solid', borderColor: 'grey.300' }}>
                      <Typography variant="subtitle2" sx={{ mb: 1, display: 'flex', alignItems: 'center' }}>
                        <TrendingUpIcon sx={{ mr: 1, fontSize: 18 }} />
                        Similar Tickets
                      </Typography>
                      <List dense>
                        {aiAnalysis.similar_tickets.map((similar, index) => (
                          <ListItem key={index} sx={{ px: 0 }}>
                            <ListItemText 
                              primary={similar?.title || 'Untitled Ticket'}
                              secondary={`Similarity: ${Math.round((similar?.similarity_score || 0) * 100)}% - ${similar?.resolution_approach || 'No approach specified'}`}
                              primaryTypographyProps={{ variant: 'caption', fontWeight: 600 }}
                              secondaryTypographyProps={{ variant: 'caption' }}
                            />
                          </ListItem>
                        ))}
                      </List>
                    </Paper>
                  )}

                  {/* Additional Insights */}
                  {aiAnalysis.additional_insights && Array.isArray(aiAnalysis.additional_insights) && aiAnalysis.additional_insights.length > 0 && (
                    <Paper sx={{ p: 2, border: '1px solid', borderColor: 'grey.300' }}>
                      <Typography variant="subtitle2" sx={{ mb: 1 }}>
                        Additional Insights
                      </Typography>
                      <List dense>
                        {aiAnalysis.additional_insights.map((insight, index) => (
                          <ListItem key={index} sx={{ px: 0 }}>
                            <ListItemText 
                              primary={insight}
                              primaryTypographyProps={{ variant: 'caption' }}
                            />
                          </ListItem>
                        ))}
                      </List>
                    </Paper>
                  )}
                </Box>
              )}
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default TicketDetail;

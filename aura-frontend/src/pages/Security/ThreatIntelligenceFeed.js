import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Grid,
  Chip,
  Button,
  IconButton,
  TextField,
  MenuItem,
  Select,
  FormControl,
  InputLabel,
  Collapse,
  Alert,
  CircularProgress,
  Tooltip,
  Link,
  Divider,
  Stack,
} from '@mui/material';
import {
  ExpandMore as ExpandMoreIcon,
  ExpandLess as ExpandLessIcon,
  Refresh as RefreshIcon,
  Search as SearchIcon,
  OpenInNew as OpenInNewIcon,
  Warning as WarningIcon,
  Error as ErrorIcon,
  Info as InfoIcon,
  CheckCircle as CheckCircleIcon,
} from '@mui/icons-material';
import { securityAPI } from '../../services/api';

const ThreatIntelligenceFeed = () => {
  const [threats, setThreats] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);
  const [expandedThreat, setExpandedThreat] = useState(null);
  
  // Filters
  const [sourceFilter, setSourceFilter] = useState('');
  const [severityFilter, setSeverityFilter] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  
  // Summary stats
  const [summary, setSummary] = useState(null);

  useEffect(() => {
    fetchThreats();
    fetchSummary();
  }, [sourceFilter, severityFilter]);

  const fetchThreats = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const data = await securityAPI.getThreatIntelFeeds(
        sourceFilter || null,
        severityFilter || null,
        50,
        true
      );
      
      setThreats(data.threats || []);
    } catch (err) {
      console.error('Error fetching threats:', err);
      setError('Failed to fetch threat intelligence feeds. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const fetchSummary = async () => {
    try {
      const data = await securityAPI.getThreatIntelSummary();
      setSummary(data.summary || null);
    } catch (err) {
      console.error('Error fetching summary:', err);
    }
  };

  const handleRefresh = async () => {
    try {
      setRefreshing(true);
      await securityAPI.refreshThreatIntel(true);
      await fetchThreats();
      await fetchSummary();
    } catch (err) {
      console.error('Error refreshing threats:', err);
      setError('Failed to refresh threat intelligence. Please try again.');
    } finally {
      setRefreshing(false);
    }
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      fetchThreats();
      return;
    }

    try {
      setLoading(true);
      setError(null);
      
      const data = await securityAPI.searchThreatIntel(
        searchQuery,
        severityFilter || null
      );
      
      setThreats(data.results || []);
    } catch (err) {
      console.error('Error searching threats:', err);
      setError('Failed to search threats. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleExpandThreat = (feedId) => {
    setExpandedThreat(expandedThreat === feedId ? null : feedId);
  };

  const getSeverityColor = (severity) => {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return 'error';
      case 'high':
        return 'warning';
      case 'medium':
        return 'info';
      case 'low':
        return 'success';
      default:
        return 'default';
    }
  };

  const getSeverityIcon = (severity) => {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return <ErrorIcon />;
      case 'high':
        return <WarningIcon />;
      case 'medium':
        return <InfoIcon />;
      case 'low':
        return <CheckCircleIcon />;
      default:
        return <InfoIcon />;
    }
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'Unknown';
    const date = new Date(dateString);
    return date.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const filteredThreats = threats.filter(threat => {
    if (searchQuery && !threat.title?.toLowerCase().includes(searchQuery.toLowerCase())) {
      return false;
    }
    return true;
  });

  return (
    <Box sx={{ p: 3 }}>
      {/* Header */}
      <Box sx={{ mb: 3 }}>
        <Typography variant="h4" gutterBottom>
          External Threat Intelligence
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Real-time cybersecurity threats from trusted sources
        </Typography>
      </Box>

      {/* Summary Stats */}
      {summary && (
        <Grid container spacing={2} sx={{ mb: 3 }}>
          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Typography color="text.secondary" gutterBottom>
                  Total Threats
                </Typography>
                <Typography variant="h4">{summary.total_threats || 0}</Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <Card sx={{ bgcolor: '#ffebee' }}>
              <CardContent>
                <Typography color="text.secondary" gutterBottom>
                  Critical/High
                </Typography>
                <Typography variant="h4" color="error">
                  {(summary.severity_breakdown?.critical || 0) + 
                   (summary.severity_breakdown?.high || 0)}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Typography color="text.secondary" gutterBottom>
                  Last 24 Hours
                </Typography>
                <Typography variant="h4">{summary.recent_24h || 0}</Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Typography color="text.secondary" gutterBottom>
                  Cache Expires
                </Typography>
                <Typography variant="h4">
                  {summary.cache_expires_in_minutes || 0}m
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}

      {/* Filters and Search */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Source</InputLabel>
                <Select
                  value={sourceFilter}
                  label="Source"
                  onChange={(e) => setSourceFilter(e.target.value)}
                >
                  <MenuItem value="">All Sources</MenuItem>
                  <MenuItem value="CISA">CISA</MenuItem>
                  <MenuItem value="CERT-IN">CERT-IN</MenuItem>
                  <MenuItem value="FBI">FBI</MenuItem>
                  <MenuItem value="BleepingComputer">BleepingComputer</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Severity</InputLabel>
                <Select
                  value={severityFilter}
                  label="Severity"
                  onChange={(e) => setSeverityFilter(e.target.value)}
                >
                  <MenuItem value="">All Severities</MenuItem>
                  <MenuItem value="critical">Critical</MenuItem>
                  <MenuItem value="high">High</MenuItem>
                  <MenuItem value="medium">Medium</MenuItem>
                  <MenuItem value="low">Low</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={8} md={4}>
              <TextField
                fullWidth
                size="small"
                placeholder="Search threats..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                InputProps={{
                  endAdornment: (
                    <IconButton onClick={handleSearch} size="small">
                      <SearchIcon />
                    </IconButton>
                  ),
                }}
              />
            </Grid>
            <Grid item xs={12} sm={4} md={2}>
              <Button
                fullWidth
                variant="outlined"
                startIcon={refreshing ? <CircularProgress size={20} /> : <RefreshIcon />}
                onClick={handleRefresh}
                disabled={refreshing}
              >
                Refresh
              </Button>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Error Message */}
      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* Loading State */}
      {loading && (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
          <CircularProgress />
        </Box>
      )}

      {/* Threat List */}
      {!loading && filteredThreats.length === 0 && (
        <Alert severity="info">
          No threats found. Try adjusting your filters or refresh the feed.
        </Alert>
      )}

      {!loading && filteredThreats.length > 0 && (
        <Box>
          {filteredThreats.map((threat) => (
            <Card key={threat.feed_id} sx={{ mb: 2 }}>
              <CardContent>
                {/* Threat Header */}
                <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 2 }}>
                  <Box sx={{ flexGrow: 1 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                      <Chip
                        icon={getSeverityIcon(threat.severity)}
                        label={threat.severity?.toUpperCase() || 'UNKNOWN'}
                        color={getSeverityColor(threat.severity)}
                        size="small"
                      />
                      <Chip
                        label={threat.source}
                        size="small"
                        variant="outlined"
                      />
                      <Typography variant="caption" color="text.secondary">
                        {formatDate(threat.published_date)}
                      </Typography>
                    </Box>
                    
                    <Typography variant="h6" gutterBottom>
                      {threat.title}
                    </Typography>

                    {/* Quick Summary */}
                    {threat.quick_summary && (
                      <Typography variant="body2" color="text.secondary" paragraph>
                        {threat.quick_summary}
                      </Typography>
                    )}

                    {/* Tags */}
                    {threat.tags && threat.tags.length > 0 && (
                      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5, mt: 1 }}>
                        {threat.tags.slice(0, 5).map((tag, index) => (
                          <Chip
                            key={index}
                            label={tag}
                            size="small"
                            variant="outlined"
                          />
                        ))}
                      </Box>
                    )}
                  </Box>

                  <Box sx={{ display: 'flex', gap: 1 }}>
                    <Tooltip title="View Source">
                      <IconButton
                        size="small"
                        component={Link}
                        href={threat.source_url}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <OpenInNewIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title={expandedThreat === threat.feed_id ? "Show less" : "Show more"}>
                      <IconButton
                        size="small"
                        onClick={() => handleExpandThreat(threat.feed_id)}
                      >
                        {expandedThreat === threat.feed_id ? 
                          <ExpandLessIcon /> : <ExpandMoreIcon />
                        }
                      </IconButton>
                    </Tooltip>
                  </Box>
                </Box>

                {/* Expanded Details */}
                <Collapse in={expandedThreat === threat.feed_id}>
                  <Divider sx={{ my: 2 }} />
                  
                  <Grid container spacing={3}>
                    {/* Full Content */}
                    <Grid item xs={12}>
                      <Typography variant="subtitle2" gutterBottom>
                        Full Description
                      </Typography>
                      <Typography variant="body2" paragraph>
                        {threat.full_content || 'No detailed content available.'}
                      </Typography>
                    </Grid>

                    {/* Affected Systems */}
                    {threat.affected_systems && threat.affected_systems.length > 0 && (
                      <Grid item xs={12} md={6}>
                        <Typography variant="subtitle2" gutterBottom>
                          Affected Systems
                        </Typography>
                        <Stack spacing={0.5}>
                          {threat.affected_systems.map((system, index) => (
                            <Chip
                              key={index}
                              label={system}
                              size="small"
                              color="warning"
                              variant="outlined"
                            />
                          ))}
                        </Stack>
                      </Grid>
                    )}

                    {/* IoCs */}
                    {threat.iocs && threat.iocs.length > 0 && (
                      <Grid item xs={12} md={6}>
                        <Typography variant="subtitle2" gutterBottom>
                          Indicators of Compromise
                        </Typography>
                        <Stack spacing={0.5}>
                          {threat.iocs.map((ioc, index) => (
                            <Typography key={index} variant="body2" fontFamily="monospace">
                              • {ioc}
                            </Typography>
                          ))}
                        </Stack>
                      </Grid>
                    )}

                    {/* Recommendations */}
                    {threat.recommendations && threat.recommendations.length > 0 && (
                      <Grid item xs={12}>
                        <Typography variant="subtitle2" gutterBottom>
                          Security Recommendations
                        </Typography>
                        <Box component="ul" sx={{ mt: 1, pl: 2 }}>
                          {threat.recommendations.map((rec, index) => (
                            <Typography
                              key={index}
                              component="li"
                              variant="body2"
                              sx={{ mb: 0.5 }}
                            >
                              {rec}
                            </Typography>
                          ))}
                        </Box>
                      </Grid>
                    )}

                    {/* Source Link */}
                    <Grid item xs={12}>
                      <Button
                        variant="outlined"
                        startIcon={<OpenInNewIcon />}
                        component={Link}
                        href={threat.source_url}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        Read Full Report on {threat.source}
                      </Button>
                    </Grid>
                  </Grid>
                </Collapse>
              </CardContent>
            </Card>
          ))}
        </Box>
      )}
    </Box>
  );
};

export default ThreatIntelligenceFeed;

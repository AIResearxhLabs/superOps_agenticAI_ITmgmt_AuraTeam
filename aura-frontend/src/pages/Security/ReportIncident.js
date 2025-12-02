import React, { useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  TextField,
  Button,
  Grid,
  MenuItem,
  FormControl,
  InputLabel,
  Select,
  Chip,
  Alert,
  AlertTitle,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  useTheme,
} from '@mui/material';
import {
  Send as SendIcon,
  CheckCircle as CheckCircleIcon,
  Error as ErrorIcon,
  Warning as WarningIcon,
  Info as InfoIcon,
} from '@mui/icons-material';

const ReportIncident = () => {
  const theme = useTheme();
  const [formData, setFormData] = useState({
    incidentType: '',
    severity: '',
    title: '',
    description: '',
    affectedSystems: '',
    detectedTime: '',
    reporterName: '',
    reporterEmail: '',
  });
  
  const [submitted, setSubmitted] = useState(false);
  const [errors, setErrors] = useState({});

  const incidentTypes = [
    'Malware Detection',
    'Unauthorized Access',
    'Data Breach',
    'Phishing Attack',
    'DDoS Attack',
    'Ransomware',
    'Insider Threat',
    'System Vulnerability',
    'Compliance Violation',
    'Other',
  ];

  const severityLevels = [
    { value: 'low', label: 'Low', color: theme.palette.success.main },
    { value: 'medium', label: 'Medium', color: theme.palette.info.main },
    { value: 'high', label: 'High', color: theme.palette.warning.main },
    { value: 'critical', label: 'Critical', color: theme.palette.error.main },
  ];

  const handleChange = (field) => (event) => {
    setFormData({
      ...formData,
      [field]: event.target.value,
    });
    // Clear error for this field
    if (errors[field]) {
      setErrors({
        ...errors,
        [field]: null,
      });
    }
  };

  const validateForm = () => {
    const newErrors = {};

    if (!formData.incidentType) newErrors.incidentType = 'Incident type is required';
    if (!formData.severity) newErrors.severity = 'Severity level is required';
    if (!formData.title) newErrors.title = 'Title is required';
    if (!formData.description) newErrors.description = 'Description is required';
    if (!formData.reporterName) newErrors.reporterName = 'Reporter name is required';
    if (!formData.reporterEmail) {
      newErrors.reporterEmail = 'Reporter email is required';
    } else if (!/\S+@\S+\.\S+/.test(formData.reporterEmail)) {
      newErrors.reporterEmail = 'Invalid email format';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (validateForm()) {
      try {
        // Import security API
        const { securityAPI } = await import('../../services/api');
        
        // Prepare incident data for API
        const incidentData = {
          incident_type: formData.incidentType,
          severity: formData.severity,
          title: formData.title,
          description: formData.description,
          affected_systems: formData.affectedSystems,
          detected_time: formData.detectedTime,
          reporter_name: formData.reporterName,
          reporter_email: formData.reporterEmail,
        };
        
        // Submit to API
        const response = await securityAPI.reportIncident(incidentData);
        console.log('Incident reported successfully:', response);
        
        // Show success state
        setSubmitted(true);
        
        // Reset form
        setFormData({
          incidentType: '',
          severity: '',
          title: '',
          description: '',
          affectedSystems: '',
          detectedTime: '',
          reporterName: '',
          reporterEmail: '',
        });
        
      } catch (error) {
        console.error('Failed to submit incident report:', error);
        // Could add error state/notification here
        alert('Failed to submit incident report. Please try again.');
      }
    }
  };

  const handleReset = () => {
    setSubmitted(false);
    setErrors({});
  };

  if (submitted) {
    return (
      <Box className="fade-in">
        <Card sx={{ maxWidth: 800, mx: 'auto', mt: 4 }}>
          <CardContent sx={{ textAlign: 'center', py: 6 }}>
            <CheckCircleIcon sx={{ fontSize: 80, color: theme.palette.success.main, mb: 2 }} />
            <Typography variant="h4" sx={{ fontWeight: 600, mb: 2 }}>
              Incident Report Submitted
            </Typography>
            <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
              Your security incident report has been submitted successfully. 
              The security team has been notified and will investigate immediately.
            </Typography>
            <Alert severity="info" sx={{ mb: 3, textAlign: 'left' }}>
              <AlertTitle>What Happens Next?</AlertTitle>
              <List dense>
                <ListItem>
                  <ListItemIcon><CheckCircleIcon color="info" /></ListItemIcon>
                  <ListItemText primary="Immediate acknowledgment sent to your email" />
                </ListItem>
                <ListItem>
                  <ListItemIcon><CheckCircleIcon color="info" /></ListItemIcon>
                  <ListItemText primary="Security team reviews and prioritizes the incident" />
                </ListItem>
                <ListItem>
                  <ListItemIcon><CheckCircleIcon color="info" /></ListItemIcon>
                  <ListItemText primary="Investigation initiated based on severity level" />
                </ListItem>
                <ListItem>
                  <ListItemIcon><CheckCircleIcon color="info" /></ListItemIcon>
                  <ListItemText primary="Regular updates provided until resolution" />
                </ListItem>
              </List>
            </Alert>
            <Button 
              variant="contained" 
              onClick={handleReset}
              size="large"
            >
              Report Another Incident
            </Button>
          </CardContent>
        </Card>
      </Box>
    );
  }

  return (
    <Box className="fade-in">
      {/* Header */}
      <Box sx={{ mb: 3 }}>
        <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>
          Report Security Incident
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Report any security concerns or incidents immediately for investigation
        </Typography>
      </Box>

      {/* Important Notice */}
      <Alert severity="warning" sx={{ mb: 3 }}>
        <AlertTitle>Critical Incidents</AlertTitle>
        If you believe a critical security breach is occurring right now, 
        please call the Security Hotline at <strong>1-800-SECURITY</strong> immediately 
        in addition to submitting this form.
      </Alert>

      <Grid container spacing={3}>
        {/* Main Form */}
        <Grid item xs={12} md={8}>
          <Card>
            <CardContent>
              <form onSubmit={handleSubmit}>
                <Grid container spacing={3}>
                  {/* Incident Type */}
                  <Grid item xs={12} sm={6}>
                    <FormControl fullWidth error={!!errors.incidentType}>
                      <InputLabel>Incident Type *</InputLabel>
                      <Select
                        value={formData.incidentType}
                        label="Incident Type *"
                        onChange={handleChange('incidentType')}
                      >
                        {incidentTypes.map((type) => (
                          <MenuItem key={type} value={type}>
                            {type}
                          </MenuItem>
                        ))}
                      </Select>
                      {errors.incidentType && (
                        <Typography variant="caption" color="error" sx={{ mt: 0.5 }}>
                          {errors.incidentType}
                        </Typography>
                      )}
                    </FormControl>
                  </Grid>

                  {/* Severity */}
                  <Grid item xs={12} sm={6}>
                    <FormControl fullWidth error={!!errors.severity}>
                      <InputLabel>Severity Level *</InputLabel>
                      <Select
                        value={formData.severity}
                        label="Severity Level *"
                        onChange={handleChange('severity')}
                      >
                        {severityLevels.map((level) => (
                          <MenuItem key={level.value} value={level.value}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              <Box
                                sx={{
                                  width: 12,
                                  height: 12,
                                  borderRadius: '50%',
                                  bgcolor: level.color,
                                }}
                              />
                              {level.label}
                            </Box>
                          </MenuItem>
                        ))}
                      </Select>
                      {errors.severity && (
                        <Typography variant="caption" color="error" sx={{ mt: 0.5 }}>
                          {errors.severity}
                        </Typography>
                      )}
                    </FormControl>
                  </Grid>

                  {/* Title */}
                  <Grid item xs={12}>
                    <TextField
                      fullWidth
                      label="Incident Title *"
                      value={formData.title}
                      onChange={handleChange('title')}
                      error={!!errors.title}
                      helperText={errors.title || 'Brief, descriptive title of the incident'}
                      placeholder="e.g., Suspicious email with malicious attachment received"
                    />
                  </Grid>

                  {/* Description */}
                  <Grid item xs={12}>
                    <TextField
                      fullWidth
                      multiline
                      rows={6}
                      label="Detailed Description *"
                      value={formData.description}
                      onChange={handleChange('description')}
                      error={!!errors.description}
                      helperText={errors.description || 'Provide as much detail as possible about the incident'}
                      placeholder="Describe what happened, when it was discovered, what actions were taken, and any other relevant information..."
                    />
                  </Grid>

                  {/* Affected Systems */}
                  <Grid item xs={12} sm={6}>
                    <TextField
                      fullWidth
                      label="Affected Systems/Users"
                      value={formData.affectedSystems}
                      onChange={handleChange('affectedSystems')}
                      helperText="List systems, servers, or users affected"
                      placeholder="e.g., Server-001, john.doe@company.com"
                    />
                  </Grid>

                  {/* Detection Time */}
                  <Grid item xs={12} sm={6}>
                    <TextField
                      fullWidth
                      type="datetime-local"
                      label="When Detected"
                      value={formData.detectedTime}
                      onChange={handleChange('detectedTime')}
                      helperText="When was this incident first detected?"
                      InputLabelProps={{
                        shrink: true,
                      }}
                    />
                  </Grid>

                  {/* Reporter Name */}
                  <Grid item xs={12} sm={6}>
                    <TextField
                      fullWidth
                      label="Your Name *"
                      value={formData.reporterName}
                      onChange={handleChange('reporterName')}
                      error={!!errors.reporterName}
                      helperText={errors.reporterName}
                      placeholder="Full name"
                    />
                  </Grid>

                  {/* Reporter Email */}
                  <Grid item xs={12} sm={6}>
                    <TextField
                      fullWidth
                      type="email"
                      label="Your Email *"
                      value={formData.reporterEmail}
                      onChange={handleChange('reporterEmail')}
                      error={!!errors.reporterEmail}
                      helperText={errors.reporterEmail}
                      placeholder="email@company.com"
                    />
                  </Grid>

                  {/* Submit Button */}
                  <Grid item xs={12}>
                    <Box sx={{ display: 'flex', gap: 2, justifyContent: 'flex-end' }}>
                      <Button
                        type="button"
                        variant="outlined"
                        onClick={() => {
                          setFormData({
                            incidentType: '',
                            severity: '',
                            title: '',
                            description: '',
                            affectedSystems: '',
                            detectedTime: '',
                            reporterName: '',
                            reporterEmail: '',
                          });
                          setErrors({});
                        }}
                      >
                        Clear Form
                      </Button>
                      <Button
                        type="submit"
                        variant="contained"
                        startIcon={<SendIcon />}
                        size="large"
                      >
                        Submit Incident Report
                      </Button>
                    </Box>
                  </Grid>
                </Grid>
              </form>
            </CardContent>
          </Card>
        </Grid>

        {/* Sidebar - Guidelines */}
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
                Reporting Guidelines
              </Typography>

              <List>
                <ListItem alignItems="flex-start" sx={{ px: 0 }}>
                  <ListItemIcon>
                    <ErrorIcon color="error" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Act Immediately"
                    secondary="Report security incidents as soon as you become aware of them"
                  />
                </ListItem>

                <ListItem alignItems="flex-start" sx={{ px: 0 }}>
                  <ListItemIcon>
                    <WarningIcon color="warning" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Preserve Evidence"
                    secondary="Do not delete files, emails, or logs. They may be needed for investigation"
                  />
                </ListItem>

                <ListItem alignItems="flex-start" sx={{ px: 0 }}>
                  <ListItemIcon>
                    <InfoIcon color="info" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Be Detailed"
                    secondary="Include specific information like times, systems, error messages, and screenshots"
                  />
                </ListItem>

                <ListItem alignItems="flex-start" sx={{ px: 0 }}>
                  <ListItemIcon>
                    <CheckCircleIcon color="success" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Follow Up"
                    secondary="You'll receive updates via email. Check your inbox regularly for next steps"
                  />
                </ListItem>
              </List>
            </CardContent>
          </Card>

          <Card sx={{ mt: 2 }}>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
                Severity Levels
              </Typography>

              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {severityLevels.map((level) => (
                  <Box key={level.value}>
                    <Chip
                      label={level.label}
                      size="small"
                      sx={{
                        bgcolor: level.color,
                        color: 'white',
                        fontWeight: 600,
                        mb: 0.5,
                      }}
                    />
                    <Typography variant="caption" display="block" color="text.secondary">
                      {level.value === 'critical' && 'Immediate threat to business operations or data'}
                      {level.value === 'high' && 'Significant security risk requiring urgent action'}
                      {level.value === 'medium' && 'Moderate risk, should be addressed promptly'}
                      {level.value === 'low' && 'Minor security concern, no immediate threat'}
                    </Typography>
                  </Box>
                ))}
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default ReportIncident;

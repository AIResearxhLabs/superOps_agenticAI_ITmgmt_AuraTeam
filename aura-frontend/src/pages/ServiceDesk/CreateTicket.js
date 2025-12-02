import React, { useState, useEffect, useCallback } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  TextField,
  Button,
  Grid,
  MenuItem,
  FormControl,
  InputLabel,
  Select,
  FormHelperText,
  Alert,
  CircularProgress,
  Chip,
  Stack,
  Paper,
  IconButton,
  Divider,
  Stepper,
  Step,
  StepLabel,
  Container,
  useTheme,
  useMediaQuery,
  Fade,
  LinearProgress,
  Collapse,
} from '@mui/material';
import {
  Send as SendIcon,
  Clear as ClearIcon,
  AttachFile as AttachFileIcon,
  Delete as DeleteIcon,
  ContactSupport as ContactIcon,
  Description as DescriptionIcon,
  Person as PersonIcon,
  Info as InfoIcon,
  AutoAwesome as AIIcon,
  Psychology as BrainIcon,
  TrendingUp as ConfidenceIcon,
  Lightbulb as SuggestionIcon,
  CloudUpload as UploadIcon,
  CheckCircle as CheckIcon,
  Schedule as TimeIcon,
  Group as TeamIcon,
  ShowChart as ChartIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import { serviceDeskAPI } from '../../services/api';

const CreateTicket = () => {
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const isSmallScreen = useMediaQuery(theme.breakpoints.down('sm'));

  // Form state
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    category: '',
    priority: 'medium',
    user_email: '',
    user_name: '',
    department: '',
    attachments: []
  });

  // Form validation state
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);
  const [activeStep, setActiveStep] = useState(0);

  // AI-powered features state
  const [aiSuggestions, setAiSuggestions] = useState([]);
  const [aiLoading, setAiLoading] = useState(false);
  const [showAiSuggestions, setShowAiSuggestions] = useState(false);
  const [aiAnalysis, setAiAnalysis] = useState(null);
  const [suggestedCategory, setSuggestedCategory] = useState('');
  const [suggestedPriority, setSuggestedPriority] = useState('');
  const [confidenceScore, setConfidenceScore] = useState(0);
  const [aiStatusMessage, setAiStatusMessage] = useState('');
  const [showAiIntro, setShowAiIntro] = useState(true);

  // Steps for the form
  const steps = [
    'Issue Details',
    'Contact Info',
    'Review & Submit'
  ];

  // Available options with icons
  const categories = [
    { value: 'Hardware Issues', icon: '💻', color: '#6366F1' },
    { value: 'Software Issues', icon: '⚙️', color: '#8B5CF6' },
    { value: 'Network Issues', icon: '🌐', color: '#EC4899' },
    { value: 'Email Issues', icon: '📧', color: '#10B981' },
    { value: 'Account Management', icon: '👤', color: '#F59E0B' },
    { value: 'Security Issues', icon: '🔒', color: '#EF4444' },
    { value: 'Installation Request', icon: '📦', color: '#3B82F6' },
    { value: 'Access Request', icon: '🔐', color: '#8B5CF6' },
    { value: 'Other', icon: '📋', color: '#6B7280' }
  ];

  const priorities = [
    { value: 'low', label: 'Low', color: 'success', icon: '🟢', description: 'Minor issue, can wait' },
    { value: 'medium', label: 'Medium', color: 'warning', icon: '🟡', description: 'Some impact, workaround available' },
    { value: 'high', label: 'High', color: 'error', icon: '🟠', description: 'Significant impact on work' },
    { value: 'critical', label: 'Critical', color: 'error', icon: '🔴', description: 'System down, no workaround' }
  ];

  const departments = [
    'IT',
    'HR',
    'Finance',
    'Marketing',
    'Sales',
    'Operations',
    'Legal',
    'Other'
  ];

  // Input validation functions
  const validateEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const sanitizeInput = (input) => {
    if (typeof input !== 'string') return input;
    
    return input
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<[^>]*>/g, '')
      .replace(/javascript:/gi, '')
      .replace(/on\w+\s*=\s*["'][^"']*["']/gi, '')
      .replace(/[<>]/g, '');
  };

  const validateForm = () => {
    const newErrors = {};

    if (!formData.title.trim()) {
      newErrors.title = 'Title is required';
    } else if (formData.title.trim().length < 5) {
      newErrors.title = 'Title must be at least 5 characters long';
    } else if (formData.title.trim().length > 200) {
      newErrors.title = 'Title must be less than 200 characters';
    }

    if (!formData.description.trim()) {
      newErrors.description = 'Description is required';
    } else if (formData.description.trim().length < 10) {
      newErrors.description = 'Description must be at least 10 characters long';
    } else if (formData.description.trim().length > 2000) {
      newErrors.description = 'Description must be less than 2000 characters';
    }

    if (!formData.category) {
      newErrors.category = 'Category is required';
    }

    if (!formData.user_email.trim()) {
      newErrors.user_email = 'Email is required';
    } else if (!validateEmail(formData.user_email)) {
      newErrors.user_email = 'Please enter a valid email address';
    }

    if (!formData.user_name.trim()) {
      newErrors.user_name = 'Name is required';
    } else if (formData.user_name.trim().length < 2) {
      newErrors.user_name = 'Name must be at least 2 characters long';
    } else if (formData.user_name.trim().length > 100) {
      newErrors.user_name = 'Name must be less than 100 characters';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleInputChange = (field, value) => {
    const sanitizedValue = typeof value === 'string' ? sanitizeInput(value) : value;
    
    setFormData(prev => ({
      ...prev,
      [field]: sanitizedValue
    }));

    if (errors[field]) {
      setErrors(prev => ({
        ...prev,
        [field]: ''
      }));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!validateForm()) {
      enqueueSnackbar('Please fix the validation errors', { variant: 'error' });
      return;
    }

    setLoading(true);

    try {
      const ticketData = {
        title: formData.title.trim(),
        description: formData.description.trim(),
        category: formData.category,
        priority: formData.priority,
        user_email: formData.user_email.trim().toLowerCase(),
        user_name: formData.user_name.trim(),
        department: formData.department,
        user_id: formData.user_email.trim().toLowerCase(),
        attachments: formData.attachments
      };

      const response = await serviceDeskAPI.createTicket(ticketData);
      
      enqueueSnackbar('🎉 Ticket created successfully with AI assistance!', { variant: 'success' });
      navigate('/tickets');
      
    } catch (error) {
      console.error('Error creating ticket:', error);
      enqueueSnackbar(
        error.message || 'Failed to create ticket. Please try again.', 
        { variant: 'error' }
      );
    } finally {
      setLoading(false);
    }
  };

  const handleClear = () => {
    setFormData({
      title: '',
      description: '',
      category: '',
      priority: 'medium',
      user_email: '',
      user_name: '',
      department: '',
      attachments: []
    });
    setErrors({});
    setAiSuggestions([]);
    setSuggestedCategory('');
    setSuggestedPriority('');
    setConfidenceScore(0);
    setAiStatusMessage('');
    setShowAiSuggestions(false);
  };

  const handleFileAttachment = (event) => {
    const files = Array.from(event.target.files);
    const fileNames = files.map(file => file.name);
    setFormData(prev => ({
      ...prev,
      attachments: [...prev.attachments, ...fileNames]
    }));
    enqueueSnackbar(`Added ${files.length} file(s)`, { variant: 'success' });
  };

  const removeAttachment = (index) => {
    setFormData(prev => ({
      ...prev,
      attachments: prev.attachments.filter((_, i) => i !== index)
    }));
  };

  const getPriorityData = (priority) => {
    return priorities.find(p => p.value === priority) || priorities[1];
  };

  const getCategoryData = (categoryValue) => {
    return categories.find(c => c.value === categoryValue) || categories[categories.length - 1];
  };

  // AI-powered functions
  const getAiSuggestions = useCallback(async (title, description) => {
    if (!title.trim() && !description.trim()) {
      setAiSuggestions([]);
      setShowAiSuggestions(false);
      setAiStatusMessage('');
      return;
    }

    if (title.length < 3 && description.length < 10) {
      return;
    }

    setAiLoading(true);
    setAiStatusMessage('✨ AI is analyzing your issue...');
    
    try {
      const mockSuggestions = await simulateAiSuggestions(title, description);
      
      setAiSuggestions(mockSuggestions);
      setShowAiSuggestions(mockSuggestions.length > 0);
      
      if (mockSuggestions.length > 0) {
        setAiStatusMessage(`✅ AI analysis complete with ${Math.round(mockSuggestions[0].confidence * 100)}% confidence`);
        
        if (mockSuggestions[0].confidence > 0.8) {
          setSuggestedCategory(mockSuggestions[0].category);
          setConfidenceScore(mockSuggestions[0].confidence);
        }
      } else {
        setAiStatusMessage('💡 Add more details for better AI suggestions');
      }
      
    } catch (error) {
      console.error('Error getting AI suggestions:', error);
      setAiStatusMessage('');
    } finally {
      setAiLoading(false);
    }
  }, []);

  // Simulate AI suggestions
  const simulateAiSuggestions = async (title, description) => {
    await new Promise(resolve => setTimeout(resolve, 600));
    
    const text = `${title} ${description}`.toLowerCase();
    const suggestions = [];
    
    const categoryKeywords = {
      'Email Issues': ['email', 'outlook', 'mail', 'inbox', 'send', 'receive', 'smtp'],
      'Network Issues': ['network', 'internet', 'wifi', 'connection', 'vpn', 'slow', 'offline'],
      'Hardware Issues': ['computer', 'laptop', 'printer', 'monitor', 'keyboard', 'mouse', 'device'],
      'Software Issues': ['software', 'application', 'app', 'program', 'windows', 'install', 'crash'],
      'Access Request': ['password', 'login', 'access', 'account', 'locked', 'reset', 'unlock'],
      'Security Issues': ['security', 'virus', 'malware', 'suspicious', 'phishing', 'breach', 'hack']
    };

    Object.entries(categoryKeywords).forEach(([category, keywords]) => {
      let score = 0;
      let matchedKeywords = [];
      
      keywords.forEach(keyword => {
        if (text.includes(keyword)) {
          score += keyword.length > 4 ? 2 : 1;
          matchedKeywords.push(keyword);
        }
      });
      
      if (score > 0) {
        suggestions.push({
          category,
          confidence: Math.min(score * 0.2, 0.95),
          reason: `Matches keywords: ${matchedKeywords.join(', ')}`,
          matchedKeywords
        });
      }
    });

    return suggestions
      .sort((a, b) => b.confidence - a.confidence)
      .slice(0, 3);
  };

  // Debounced AI suggestions
  useEffect(() => {
    const timeoutId = setTimeout(() => {
      if (formData.title || formData.description) {
        getAiSuggestions(formData.title, formData.description);
      }
    }, 1000);

    return () => clearTimeout(timeoutId);
  }, [formData.title, formData.description, getAiSuggestions]);

  // Apply AI suggestion
  const applyAiSuggestion = (suggestion) => {
    handleInputChange('category', suggestion.category);
    setSuggestedCategory('');
    setShowAiSuggestions(false);
    enqueueSnackbar(`✨ Applied AI suggestion: ${suggestion.category}`, { variant: 'success' });
  };

  // Get comprehensive AI analysis for review step
  const getAiAnalysis = async () => {
    if (!formData.title.trim() || !formData.description.trim()) {
      return;
    }

    setAiLoading(true);
    
    try {
      const analysis = await simulateComprehensiveAnalysis();
      setAiAnalysis(analysis);
      
      if (analysis.suggestedPriority && analysis.confidence > 0.7) {
        setSuggestedPriority(analysis.suggestedPriority);
      }
      
    } catch (error) {
      console.error('Error getting AI analysis:', error);
    } finally {
      setAiLoading(false);
    }
  };

  // Simulate comprehensive AI analysis
  const simulateComprehensiveAnalysis = async () => {
    await new Promise(resolve => setTimeout(resolve, 800));
    
    const text = `${formData.title} ${formData.description}`.toLowerCase();
    
    const urgencyKeywords = ['urgent', 'asap', 'critical', 'emergency', 'down', 'offline', 'crash'];
    const hasUrgency = urgencyKeywords.some(keyword => text.includes(keyword));
    
    const impactKeywords = ['everyone', 'team', 'multiple users', 'can\'t work', 'blocking', 'all'];
    const hasHighImpact = impactKeywords.some(keyword => text.includes(keyword));
    
    let suggestedPriority = 'medium';
    if (hasUrgency && hasHighImpact) {
      suggestedPriority = 'critical';
    } else if (hasUrgency || hasHighImpact) {
      suggestedPriority = 'high';
    } else if (text.includes('slow') || text.includes('issue')) {
      suggestedPriority = 'medium';
    } else {
      suggestedPriority = 'low';
    }

    return {
      suggestedPriority,
      confidence: 0.87,
      urgencyIndicators: urgencyKeywords.filter(keyword => text.includes(keyword)),
      impactIndicators: impactKeywords.filter(keyword => text.includes(keyword)),
      estimatedResolutionTime: suggestedPriority === 'critical' ? '1-2 hours' : 
                               suggestedPriority === 'high' ? '4-6 hours' : 
                               suggestedPriority === 'medium' ? '1-2 days' : '2-3 days',
      similarTickets: Math.floor(Math.random() * 10) + 1,
      suggestedAgent: 'Sarah Johnson',
      recommendedActions: [
        'Check system logs',
        'Verify user permissions',
        'Review recent changes'
      ]
    };
  };

  // Trigger AI analysis when moving to review step
  useEffect(() => {
    if (activeStep === 2) {
      getAiAnalysis();
    }
  }, [activeStep]);

  // Get confidence color
  const getConfidenceColor = (confidence) => {
    if (confidence >= 0.8) return '#10B981';
    if (confidence >= 0.6) return '#F59E0B';
    return '#EF4444';
  };

  // Get confidence label
  const getConfidenceLabel = (confidence) => {
    if (confidence >= 0.8) return 'High Confidence';
    if (confidence >= 0.6) return 'Medium Confidence';
    return 'Low Confidence';
  };

  // Helper function to render step content
  const renderStepContent = (step) => {
    switch (step) {
      case 0:
        return (
          <Stack spacing={3}>
            {/* Issue Title - Full Width */}
            <Box>
              <TextField
                fullWidth
                label="Issue Title *"
                placeholder="Brief summary of your issue (e.g., 'Cannot access company email')"
                value={formData.title}
                onChange={(e) => handleInputChange('title', e.target.value)}
                error={!!errors.title}
                helperText={errors.title || `${formData.title.length}/200 characters`}
                multiline
                rows={2}
                inputProps={{ maxLength: 200 }}
                sx={{
                  '& .MuiOutlinedInput-root': {
                    fontSize: '1.1rem',
                  }
                }}
                InputProps={{
                  endAdornment: aiLoading && formData.title && (
                    <CircularProgress size={20} sx={{ color: '#6366F1' }} />
                  )
                }}
              />
            </Box>

            {/* Description - Full Width */}
            <Box>
              <TextField
                fullWidth
                multiline
                rows={8}
                label="Detailed Description *"
                placeholder="Please provide detailed information:
• What happened?
• When did it start?
• Any error messages?
• Steps you've already tried?

More details help us resolve your issue faster!"
                value={formData.description}
                onChange={(e) => handleInputChange('description', e.target.value)}
                error={!!errors.description}
                helperText={errors.description}
                inputProps={{ maxLength: 2000 }}
                sx={{
                  '& .MuiOutlinedInput-root': {
                    fontSize: '1rem',
                  }
                }}
              />
              <Box sx={{ display: 'flex', justifyContent: 'space-between', mt: 1, px: 1 }}>
                <Typography variant="caption" sx={{ color: '#6366F1', display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  <SuggestionIcon sx={{ fontSize: 16 }} />
                  Tip: More details = Better AI suggestions & Faster resolution
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {formData.description.length}/2000
                </Typography>
              </Box>
            </Box>

            {/* AI Status Bar - Fixed Height Container */}
            <Box sx={{ minHeight: '70px' }}>
              <Collapse in={!!aiStatusMessage}>
                <Alert 
                  severity={aiStatusMessage.includes('✅') ? 'success' : 'info'}
                  icon={<BrainIcon />}
                  sx={{ 
                    borderRadius: 2,
                    backgroundColor: '#EEF2FF',
                    border: '2px solid #6366F1',
                    '& .MuiAlert-message': {
                      fontWeight: 500,
                      width: '100%'
                    }
                  }}
                >
                  {aiStatusMessage}
                </Alert>
              </Collapse>
            </Box>

            {/* AI Suggestions Panel - Collapsible */}
            <Collapse in={showAiSuggestions && aiSuggestions.length > 0}>
              <Paper 
                elevation={3}
                sx={{ 
                  p: 3,
                  background: 'linear-gradient(135deg, #667EEA 0%, #764BA2 100%)',
                  borderRadius: 3,
                  position: 'relative',
                  overflow: 'hidden'
                }}
              >
                {/* Background decoration */}
                <Box sx={{
                  position: 'absolute',
                  top: -50,
                  right: -50,
                  width: 200,
                  height: 200,
                  borderRadius: '50%',
                  background: 'rgba(255,255,255,0.1)',
                }} />
                
                <Box sx={{ position: 'relative', zIndex: 1 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                    <Box sx={{
                      background: 'white',
                      borderRadius: 2,
                      p: 1,
                      mr: 2,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center'
                    }}>
                      <AIIcon sx={{ color: '#6366F1', fontSize: 28 }} />
                    </Box>
                    <Box sx={{ flexGrow: 1 }}>
                      <Typography variant="h6" sx={{ color: 'white', fontWeight: 600 }}>
                        🤖 AI Assistant Suggestions
                      </Typography>
                      <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.9)' }}>
                        Smart categorization powered by artificial intelligence
                      </Typography>
                    </Box>
                  </Box>
                  
                  <Stack spacing={2}>
                    {aiSuggestions.map((suggestion, index) => {
                      const categoryData = getCategoryData(suggestion.category);
                      const isTop = index === 0;
                      
                      return (
                        <Paper
                          key={index}
                          elevation={isTop ? 8 : 2}
                          sx={{
                            p: 2.5,
                            cursor: 'pointer',
                            transition: 'all 0.3s',
                            background: 'white',
                            border: isTop ? '3px solid #10B981' : '2px solid transparent',
                            '&:hover': {
                              transform: 'translateY(-2px)',
                              boxShadow: 6
                            }
                          }}
                          onClick={() => applyAiSuggestion(suggestion)}
                        >
                          {isTop && (
                            <Chip
                              label="🏆 Best Match"
                              size="small"
                              sx={{
                                mb: 1,
                                background: '#10B981',
                                color: 'white',
                                fontWeight: 600
                              }}
                            />
                          )}
                          
                          <Box sx={{ display: 'flex', alignItems: 'center', mb: 1.5 }}>
                            <Typography sx={{ fontSize: '2rem', mr: 1.5 }}>
                              {categoryData.icon}
                            </Typography>
                            <Box sx={{ flexGrow: 1 }}>
                              <Typography variant="h6" sx={{ fontWeight: 600, fontSize: '1.1rem' }}>
                                {suggestion.category}
                              </Typography>
                            </Box>
                          </Box>
                          
                          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                            {suggestion.reason}
                          </Typography>
                          
                          <Box sx={{ mb: 2 }}>
                            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                              <Typography variant="caption" sx={{ fontWeight: 600, color: getConfidenceColor(suggestion.confidence) }}>
                                {getConfidenceLabel(suggestion.confidence)}
                              </Typography>
                              <Typography variant="caption" sx={{ fontWeight: 600, color: getConfidenceColor(suggestion.confidence) }}>
                                {Math.round(suggestion.confidence * 100)}%
                              </Typography>
                            </Box>
                            <LinearProgress 
                              variant="determinate" 
                              value={suggestion.confidence * 100}
                              sx={{
                                height: 8,
                                borderRadius: 4,
                                backgroundColor: '#E5E7EB',
                                '& .MuiLinearProgress-bar': {
                                  borderRadius: 4,
                                  background: `linear-gradient(90deg, ${getConfidenceColor(suggestion.confidence)} 0%, ${getConfidenceColor(suggestion.confidence)}dd 100%)`
                                }
                              }}
                            />
                          </Box>
                          
                          <Button
                            fullWidth
                            variant={isTop ? "contained" : "outlined"}
                            startIcon={<CheckIcon />}
                            onClick={(e) => {
                              e.stopPropagation();
                              applyAiSuggestion(suggestion);
                            }}
                            sx={{
                              fontWeight: 600,
                              ...(isTop && {
                                background: 'linear-gradient(90deg, #6366F1 0%, #8B5CF6 100%)',
                                '&:hover': {
                                  background: 'linear-gradient(90deg, #4F46E5 0%, #7C3AED 100%)',
                                }
                              })
                            }}
                          >
                            Apply This Category
                          </Button>
                        </Paper>
                      );
                    })}
                  </Stack>
                </Box>
              </Paper>
            </Collapse>

            {/* Category - Full Width */}
            <Box>
              <FormControl fullWidth error={!!errors.category}>
                <InputLabel 
                  sx={{ 
                    fontSize: '1rem',
                    '&.MuiInputLabel-shrink': {
                      fontSize: '0.875rem'
                    }
                  }}
                >
                  Issue Category *
                </InputLabel>
                <Select
                  value={formData.category}
                  onChange={(e) => handleInputChange('category', e.target.value)}
                  label="Issue Category *"
                  sx={{ 
                    fontSize: '1rem',
                    '& .MuiSelect-select': {
                      display: 'flex',
                      alignItems: 'center',
                      minHeight: '56px'
                    }
                  }}
                  MenuProps={{
                    PaperProps: {
                      sx: {
                        maxHeight: 400
                      }
                    }
                  }}
                >
                  {categories.map((category) => (
                    <MenuItem key={category.value} value={category.value}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography sx={{ fontSize: '1.5rem' }}>{category.icon}</Typography>
                        <Typography>{category.value}</Typography>
                      </Box>
                    </MenuItem>
                  ))}
                </Select>
                {errors.category && <FormHelperText>{errors.category}</FormHelperText>}
              </FormControl>
              
              {/* AI Category Suggestion - Fixed Height Container */}
              <Box sx={{ minHeight: 60, mt: 1 }}>
                <Collapse in={suggestedCategory && suggestedCategory !== formData.category}>
                  <Paper
                    elevation={1}
                    sx={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: 1,
                      p: 1.5,
                      backgroundColor: '#EEF2FF',
                      borderRadius: 2,
                      border: '2px solid #6366F1'
                    }}
                  >
                    <BrainIcon sx={{ fontSize: 20, color: '#6366F1' }} />
                    <Box sx={{ flexGrow: 1 }}>
                      <Typography variant="body2" sx={{ color: '#6366F1', fontWeight: 600 }}>
                        AI suggests: {suggestedCategory}
                      </Typography>
                      <Typography variant="caption" sx={{ color: '#6366F1' }}>
                        {Math.round(confidenceScore * 100)}% confidence
                      </Typography>
                    </Box>
                    <Button
                      size="small"
                      variant="contained"
                      onClick={() => applyAiSuggestion({ category: suggestedCategory })}
                      sx={{ 
                        minWidth: 'auto',
                        background: '#6366F1',
                        fontWeight: 600,
                        px: 2
                      }}
                    >
                      Apply
                    </Button>
                  </Paper>
                </Collapse>
              </Box>
            </Box>

            {/* Priority - Full Width */}
            <Box>
              <FormControl fullWidth>
                <InputLabel
                  sx={{ 
                    fontSize: '1rem',
                    '&.MuiInputLabel-shrink': {
                      fontSize: '0.875rem'
                    }
                  }}
                >
                  Priority Level *
                </InputLabel>
                <Select
                  value={formData.priority}
                  onChange={(e) => handleInputChange('priority', e.target.value)}
                  label="Priority Level *"
                  sx={{ 
                    fontSize: '1rem',
                    '& .MuiSelect-select': {
                      display: 'flex',
                      alignItems: 'center',
                      minHeight: '56px'
                    }
                  }}
                  MenuProps={{
                    PaperProps: {
                      sx: {
                        maxHeight: 400
                      }
                    }
                  }}
                >
                  {priorities.map((priority) => (
                    <MenuItem key={priority.value} value={priority.value}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, width: '100%' }}>
                        <Typography sx={{ fontSize: '1.5rem' }}>{priority.icon}</Typography>
                        <Typography sx={{ flexGrow: 1 }}>{priority.label}</Typography>
                        <Chip 
                          label={priority.label} 
                          color={priority.color} 
                          size="small"
                          variant="outlined"
                        />
                      </Box>
                    </MenuItem>
                  ))}
                </Select>
                <FormHelperText>
                  {getPriorityData(formData.priority).description}
                </FormHelperText>
              </FormControl>
            </Box>

            {/* Attachments - Full Width */}
            <Box>
              <Paper 
                variant="outlined" 
                sx={{ 
                  p: 3,
                  borderRadius: 2,
                  border: '2px dashed',
                  borderColor: 'primary.main',
                  backgroundColor: '#F9FAFB',
                  transition: 'all 0.3s',
                  '&:hover': {
                    backgroundColor: '#EEF2FF',
                    borderColor: '#6366F1'
                  }
                }}
              >
                <Box sx={{ textAlign: 'center', mb: 2 }}>
                  <UploadIcon sx={{ fontSize: 48, color: '#6366F1', mb: 1 }} />
                  <Typography variant="h6" sx={{ mb: 1, fontWeight: 600 }}>
                    📎 Attachments (Optional)
                  </Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    Screenshots and documents help us understand your issue better
                  </Typography>
                  
                  <input
                    accept="image/*,.pdf,.doc,.docx,.txt"
                    style={{ display: 'none' }}
                    id="file-upload"
                    multiple
                    type="file"
                    onChange={handleFileAttachment}
                  />
                  <label htmlFor="file-upload">
                    <Button
                      variant="contained"
                      component="span"
                      startIcon={<AttachFileIcon />}
                      size="large"
                      sx={{
                        background: 'linear-gradient(90deg, #6366F1 0%, #8B5CF6 100%)',
                        fontWeight: 600,
                        px: 4
                      }}
                    >
                      Choose Files
                    </Button>
                  </label>
                  
                  <Typography variant="caption" display="block" sx={{ mt: 1, color: 'text.secondary' }}>
                    Supported: Images, PDF, DOC, TXT (Max 10MB per file)
                  </Typography>
                </Box>

                {formData.attachments.length > 0 && (
                  <Box sx={{ mt: 3 }}>
                    <Divider sx={{ mb: 2 }} />
                    <Typography variant="subtitle2" sx={{ mb: 2, fontWeight: 600 }}>
                      📋 Attached Files ({formData.attachments.length}):
                    </Typography>
                    <Stack spacing={1}>
                      {formData.attachments.map((file, index) => (
                        <Paper
                          key={index}
                          variant="outlined"
                          sx={{
                            p: 1.5,
                            display: 'flex',
                            alignItems: 'center',
                            backgroundColor: 'white'
                          }}
                        >
                          <AttachFileIcon sx={{ mr: 1, color: 'text.secondary' }} />
                          <Typography variant="body2" sx={{ flexGrow: 1 }}>
                            {file}
                          </Typography>
                          <IconButton
                            size="small"
                            onClick={() => removeAttachment(index)}
                            sx={{ color: 'error.main' }}
                          >
                            <DeleteIcon fontSize="small" />
                          </IconButton>
                        </Paper>
                      ))}
                    </Stack>
                  </Box>
                )}
              </Paper>
            </Box>
          </Stack>
        );

      case 1:
        return (
          <Stack spacing={3}>
            {/* Header */}
            <Box sx={{ 
              display: 'flex', 
              alignItems: 'center', 
              p: 2,
              backgroundColor: '#EEF2FF',
              borderRadius: 2
            }}>
              <PersonIcon sx={{ mr: 2, color: '#6366F1', fontSize: 32 }} />
              <Box>
                <Typography variant="h6" sx={{ color: '#6366F1', fontWeight: 600 }}>
                  Your Contact Information
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  We'll use this to keep you updated on your ticket
                </Typography>
              </Box>
            </Box>

            {/* Full Name - Full Width */}
            <TextField
              fullWidth
              label="Full Name *"
              placeholder="Enter your full name"
              value={formData.user_name}
              onChange={(e) => handleInputChange('user_name', e.target.value)}
              error={!!errors.user_name}
              helperText={errors.user_name}
              inputProps={{ maxLength: 100 }}
              sx={{
                '& .MuiOutlinedInput-root': {
                  fontSize: '1rem',
                  minHeight: 56
                }
              }}
            />

            {/* Email - Full Width */}
            <TextField
              fullWidth
              type="email"
              label="Email Address *"
              placeholder="your.email@company.com"
              value={formData.user_email}
              onChange={(e) => handleInputChange('user_email', e.target.value)}
              error={!!errors.user_email}
              helperText={errors.user_email}
              sx={{
                '& .MuiOutlinedInput-root': {
                  fontSize: '1rem',
                  minHeight: 56
                }
              }}
            />

            {/* Department - Full Width */}
            <FormControl fullWidth>
              <InputLabel
                sx={{ 
                  fontSize: '1rem',
                  '&.MuiInputLabel-shrink': {
                    fontSize: '0.875rem'
                  }
                }}
              >
                Department
              </InputLabel>
              <Select
                value={formData.department}
                onChange={(e) => handleInputChange('department', e.target.value)}
                label="Department"
                sx={{ 
                  fontSize: '1rem',
                  '& .MuiSelect-select': {
                    display: 'flex',
                    alignItems: 'center',
                    minHeight: '56px'
                  }
                }}
                MenuProps={{
                  PaperProps: {
                    sx: {
                      maxHeight: 400
                    }
                  }
                }}
              >
                <MenuItem value="">
                  <em>Select your department</em>
                </MenuItem>
                {departments.map((dept) => (
                  <MenuItem key={dept} value={dept}>
                    {dept}
                  </MenuItem>
                ))}
              </Select>
              <FormHelperText>
                💡 This helps us route your ticket to the right team
              </FormHelperText>
            </FormControl>

            {/* Privacy Note */}
            <Alert severity="info" sx={{ borderRadius: 2 }}>
              <Typography variant="body2">
                <strong>Privacy Note:</strong> Your contact information is only used for support purposes 
                and will not be shared with third parties.
              </Typography>
            </Alert>
          </Stack>
        );

      case 2:
        return (
          <Grid container spacing={3}>
            {/* Header */}
            <Grid item xs={12}>
              <Box sx={{ 
                display: 'flex', 
                alignItems: 'center', 
                p: 2,
                backgroundColor: '#EEF2FF',
                borderRadius: 2
              }}>
                <InfoIcon sx={{ mr: 2, color: '#6366F1', fontSize: 32 }} />
                <Box>
                  <Typography variant="h6" sx={{ color: '#6366F1', fontWeight: 600 }}>
                    Review Your Ticket & AI Analysis
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Please verify all information before submitting
                  </Typography>
                </Box>
              </Box>
            </Grid>

            {/* Ticket Summary */}
            <Grid item xs={12} md={7}>
              <Paper 
                elevation={2}
                sx={{ 
                  p: 3, 
                  borderRadius: 2,
                  border: '2px solid',
                  borderColor: '#E5E7EB'
                }}
              >
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 3, color: '#6366F1', display: 'flex', alignItems: 'center' }}>
                  <DescriptionIcon sx={{ mr: 1 }} />
                  Your Ticket Summary
                </Typography>
                
                <Box sx={{ mb: 3 }}>
                  <Typography variant="caption" color="text.secondary" sx={{ textTransform: 'uppercase', fontWeight: 600 }}>
                    Title
                  </Typography>
                  <Typography variant="h6" sx={{ mt: 0.5, fontWeight: 500 }}>
                    {formData.title || 'Not specified'}
                  </Typography>
                </Box>
                
                <Box sx={{ display: 'flex', gap: 3, mb: 3 }}>
                  <Box>
                    <Typography variant="caption" color="text.secondary" sx={{ textTransform: 'uppercase', fontWeight: 600 }}>
                      Category
                    </Typography>
                    <Box sx={{ mt: 0.5 }}>
                      <Chip 
                        label={formData.category || 'Not selected'} 
                        icon={<Typography>{getCategoryData(formData.category).icon}</Typography>}
                        variant="outlined"
                        sx={{ fontWeight: 600 }}
                      />
                    </Box>
                  </Box>
                  
                  <Box>
                    <Typography variant="caption" color="text.secondary" sx={{ textTransform: 'uppercase', fontWeight: 600 }}>
                      Priority
                    </Typography>
                    <Box sx={{ mt: 0.5 }}>
                      <Chip 
                        label={getPriorityData(formData.priority).label}
                        icon={<Typography>{getPriorityData(formData.priority).icon}</Typography>}
                        color={getPriorityData(formData.priority).color}
                        sx={{ fontWeight: 600 }}
                      />
                    </Box>
                  </Box>
                </Box>
                
                <Box sx={{ mb: 3 }}>
                  <Typography variant="caption" color="text.secondary" sx={{ textTransform: 'uppercase', fontWeight: 600 }}>
                    Description
                  </Typography>
                  <Paper 
                    variant="outlined" 
                    sx={{ 
                      mt: 0.5,
                      p: 2, 
                      backgroundColor: '#F9FAFB',
                      maxHeight: 150,
                      overflow: 'auto',
                      borderRadius: 1
                    }}
                  >
                    <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                      {formData.description || 'Not provided'}
                    </Typography>
                  </Paper>
                </Box>
                
                <Divider sx={{ my: 2 }} />
                
                <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 2, color: '#6366F1' }}>
                  Contact Details
                </Typography>
                <Grid container spacing={2}>
                  <Grid item xs={12} sm={6}>
                    <Typography variant="body2" color="text.secondary">
                      <strong>Name:</strong> {formData.user_name || 'Not provided'}
                    </Typography>
                  </Grid>
                  <Grid item xs={12} sm={6}>
                    <Typography variant="body2" color="text.secondary">
                      <strong>Email:</strong> {formData.user_email || 'Not provided'}
                    </Typography>
                  </Grid>
                  <Grid item xs={12} sm={6}>
                    <Typography variant="body2" color="text.secondary">
                      <strong>Department:</strong> {formData.department || 'Not specified'}
                    </Typography>
                  </Grid>
                  {formData.attachments.length > 0 && (
                    <Grid item xs={12} sm={6}>
                      <Typography variant="body2" color="text.secondary">
                        <strong>Attachments:</strong> {formData.attachments.length} file(s)
                      </Typography>
                    </Grid>
                  )}
                </Grid>
              </Paper>
            </Grid>

            {/* AI Analysis Panel */}
            <Grid item xs={12} md={5}>
              <Paper 
                elevation={3}
                sx={{ 
                  p: 3, 
                  borderRadius: 2,
                  background: 'linear-gradient(135deg, #667EEA 0%, #764BA2 100%)',
                  color: 'white'
                }}
              >
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 3, display: 'flex', alignItems: 'center' }}>
                  <BrainIcon sx={{ mr: 1 }} />
                  🤖 AI Insights
                </Typography>
                
                {aiLoading ? (
                  <Box sx={{ textAlign: 'center', py: 4 }}>
                    <CircularProgress sx={{ color: 'white', mb: 2 }} />
                    <Typography variant="body2">
                      Analyzing your ticket...
                    </Typography>
                  </Box>
                ) : aiAnalysis ? (
                  <Stack spacing={2.5}>
                    <Box>
                      <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                        <TimeIcon sx={{ mr: 1, fontSize: 20 }} />
                        <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                          Estimated Resolution Time
                        </Typography>
                      </Box>
                      <Paper sx={{ p: 1.5, backgroundColor: 'rgba(255,255,255,0.9)' }}>
                        <Typography variant="h6" sx={{ color: '#6366F1', fontWeight: 700 }}>
                          ⏱️ {aiAnalysis.estimatedResolutionTime}
                        </Typography>
                      </Paper>
                    </Box>
                    
                    <Box>
                      <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                        <ChartIcon sx={{ mr: 1, fontSize: 20 }} />
                        <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                          Similar Resolved Issues
                        </Typography>
                      </Box>
                      <Paper sx={{ p: 1.5, backgroundColor: 'rgba(255,255,255,0.9)' }}>
                        <Typography variant="h6" sx={{ color: '#10B981', fontWeight: 700 }}>
                          📊 Found {aiAnalysis.similarTickets} similar cases
                        </Typography>
                      </Paper>
                    </Box>
                    
                    <Box>
                      <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                        <TeamIcon sx={{ mr: 1, fontSize: 20 }} />
                        <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                          Suggested Agent
                        </Typography>
                      </Box>
                      <Paper sx={{ p: 1.5, backgroundColor: 'rgba(255,255,255,0.9)' }}>
                        <Typography variant="body1" sx={{ color: '#1F2937', fontWeight: 600 }}>
                          👤 {aiAnalysis.suggestedAgent}
                        </Typography>
                        <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                          Specialist in {formData.category}
                        </Typography>
                      </Paper>
                    </Box>
                    
                    <Box>
                      <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                        <ConfidenceIcon sx={{ mr: 1, fontSize: 20 }} />
                        <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                          AI Confidence Score
                        </Typography>
                      </Box>
                      <Paper sx={{ p: 1.5, backgroundColor: 'rgba(255,255,255,0.9)' }}>
                        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                          <Typography variant="caption" sx={{ color: getConfidenceColor(aiAnalysis.confidence), fontWeight: 600 }}>
                            {getConfidenceLabel(aiAnalysis.confidence)}
                          </Typography>
                          <Typography variant="caption" sx={{ color: getConfidenceColor(aiAnalysis.confidence), fontWeight: 700 }}>
                            {Math.round(aiAnalysis.confidence * 100)}%
                          </Typography>
                        </Box>
                        <LinearProgress 
                          variant="determinate" 
                          value={aiAnalysis.confidence * 100}
                          sx={{
                            height: 10,
                            borderRadius: 5,
                            backgroundColor: '#E5E7EB',
                            '& .MuiLinearProgress-bar': {
                              borderRadius: 5,
                              background: `linear-gradient(90deg, ${getConfidenceColor(aiAnalysis.confidence)} 0%, ${getConfidenceColor(aiAnalysis.confidence)}dd 100%)`
                            }
                          }}
                        />
                      </Paper>
                    </Box>
                  </Stack>
                ) : (
                  <Alert severity="info" sx={{ backgroundColor: 'rgba(255,255,255,0.9)' }}>
                    <Typography variant="body2">
                      AI analysis will be generated when you reach this step.
                    </Typography>
                  </Alert>
                )}
              </Paper>
            </Grid>
          </Grid>
        );

      default:
        return null;
    }
  };

  return (
    <Container maxWidth="lg" className="fade-in">
      {/* AI-Powered Header */}
      <Paper 
        elevation={3}
        sx={{ 
          mb: 4, 
          p: 3,
          background: 'linear-gradient(135deg, #667EEA 0%, #764BA2 100%)',
          color: 'white',
          borderRadius: 3,
          position: 'relative',
          overflow: 'hidden'
        }}
      >
        <Box sx={{
          position: 'absolute',
          top: -30,
          right: -30,
          width: 150,
          height: 150,
          borderRadius: '50%',
          background: 'rgba(255,255,255,0.1)',
        }} />
        
        <Box sx={{ position: 'relative', zIndex: 1 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 2 }}>
            <Box>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                <ContactIcon sx={{ mr: 2, fontSize: isSmallScreen ? 28 : 36 }} />
                <Typography variant={isSmallScreen ? "h5" : "h4"} sx={{ fontWeight: 700 }}>
                  Create Support Ticket
                </Typography>
              </Box>
              <Typography variant="body1" sx={{ opacity: 0.95, mb: 1 }}>
                Our AI assistant will help categorize and prioritize your issue automatically
              </Typography>
              <Chip 
                icon={<AIIcon />}
                label="✨ Powered by Artificial Intelligence"
                sx={{ 
                  backgroundColor: 'rgba(255,255,255,0.2)',
                  color: 'white',
                  fontWeight: 600,
                  '& .MuiChip-icon': {
                    color: 'white'
                  }
                }}
              />
            </Box>
            
            <Box sx={{ textAlign: isSmallScreen ? 'left' : 'right' }}>
              <Typography variant="caption" sx={{ display: 'block', opacity: 0.9 }}>
                Average Response Time
              </Typography>
              <Typography variant="h5" sx={{ fontWeight: 700 }}>
                ⏱️ 2-4 Hours
              </Typography>
            </Box>
          </Box>
        </Box>
      </Paper>

      {/* AI Introduction Banner */}
      <Collapse in={showAiIntro}>
        <Alert 
          severity="info"
          onClose={() => setShowAiIntro(false)}
          icon={<BrainIcon />}
          sx={{ 
            mb: 3,
            borderRadius: 2,
            backgroundColor: '#EEF2FF',
            border: '2px solid #6366F1',
            '& .MuiAlert-message': {
              width: '100%'
            }
          }}
        >
          <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
            💡 Smart Features You'll Love
          </Typography>
          <Grid container spacing={1}>
            <Grid item xs={12} sm={6}>
              <Typography variant="body2">
                ✨ <strong>Auto-categorization:</strong> AI suggests the best category
              </Typography>
            </Grid>
            <Grid item xs={12} sm={6}>
              <Typography variant="body2">
                🎯 <strong>Smart routing:</strong> Assigned to the best agent
              </Typography>
            </Grid>
            <Grid item xs={12} sm={6}>
              <Typography variant="body2">
                📊 <strong>Similar issues:</strong> Learn from past resolutions
              </Typography>
            </Grid>
            <Grid item xs={12} sm={6}>
              <Typography variant="body2">
                ⏱️ <strong>Time estimates:</strong> Know when to expect resolution
              </Typography>
            </Grid>
          </Grid>
        </Alert>
      </Collapse>

      {/* Progress Stepper */}
      <Card sx={{ mb: 4 }} elevation={2}>
        <CardContent sx={{ py: 3 }}>
          <Stepper activeStep={activeStep} alternativeLabel={!isSmallScreen}>
            {steps.map((label, index) => (
              <Step key={label}>
                <StepLabel
                  StepIconProps={{
                    sx: {
                      '&.Mui-completed': {
                        color: '#10B981'
                      },
                      '&.Mui-active': {
                        color: '#6366F1'
                      }
                    }
                  }}
                >
                  {!isSmallScreen && label}
                </StepLabel>
              </Step>
            ))}
          </Stepper>
        </CardContent>
      </Card>

      {/* Form Card */}
      <Card sx={{ mb: 4 }} elevation={3}>
        <CardContent sx={{ p: isSmallScreen ? 3 : 4 }}>
          <form onSubmit={handleSubmit}>
            {renderStepContent(activeStep)}

            {/* Navigation Buttons */}
            <Box sx={{ 
              display: 'flex', 
              justifyContent: 'space-between', 
              mt: 4, 
              pt: 3, 
              borderTop: 2, 
              borderColor: '#E5E7EB',
              flexDirection: isSmallScreen ? 'column' : 'row',
              gap: 2
            }}>
              <Box sx={{ display: 'flex', gap: 2, flexDirection: isSmallScreen ? 'column' : 'row' }}>
                {activeStep > 0 && (
                  <Button
                    onClick={() => setActiveStep(activeStep - 1)}
                    variant="outlined"
                    size="large"
                    fullWidth={isSmallScreen}
                    sx={{ minWidth: 120 }}
                  >
                    ← Back
                  </Button>
                )}
                <Button
                  variant="outlined"
                  onClick={handleClear}
                  startIcon={<ClearIcon />}
                  disabled={loading}
                  size="large"
                  fullWidth={isSmallScreen}
                  color="error"
                  sx={{ minWidth: 120 }}
                >
                  Clear Form
                </Button>
              </Box>

              <Box sx={{ display: 'flex', gap: 2, flexDirection: isSmallScreen ? 'column' : 'row' }}>
                {activeStep < steps.length - 1 ? (
                  <Button
                    variant="contained"
                    size="large"
                    onClick={() => {
                      if (activeStep === 0 && (!formData.title.trim() || !formData.description.trim() || !formData.category)) {
                        validateForm();
                        enqueueSnackbar('Please fill in all required fields', { variant: 'warning' });
                        return;
                      }
                      if (activeStep === 1 && (!formData.user_name.trim() || !formData.user_email.trim())) {
                        validateForm();
                        enqueueSnackbar('Please fill in all required fields', { variant: 'warning' });
                        return;
                      }
                      setActiveStep(activeStep + 1);
                    }}
                    fullWidth={isSmallScreen}
                    sx={{
                      minWidth: 160,
                      height: 56,
                      background: 'linear-gradient(90deg, #6366F1 0%, #8B5CF6 100%)',
                      fontWeight: 600,
                      fontSize: '1.1rem'
                    }}
                  >
                    Continue →
                  </Button>
                ) : (
                  <Button
                    type="submit"
                    variant="contained"
                    size="large"
                    startIcon={loading ? <CircularProgress size={24} color="inherit" /> : <SendIcon />}
                    disabled={loading}
                    fullWidth={isSmallScreen}
                    sx={{
                      minWidth: 200,
                      height: 56,
                      background: loading ? undefined : 'linear-gradient(90deg, #10B981 0%, #059669 100%)',
                      fontWeight: 700,
                      fontSize: '1.1rem',
                      '&:hover': {
                        background: loading ? undefined : 'linear-gradient(90deg, #059669 0%, #047857 100%)',
                      }
                    }}
                  >
                    {loading ? 'Creating Ticket...' : '🚀 Submit with AI Assistance'}
                  </Button>
                )}
              </Box>
            </Box>

            {/* AI Benefits Footer */}
            {activeStep === 2 && (
              <Paper 
                variant="outlined" 
                sx={{ 
                  mt: 3, 
                  p: 2, 
                  backgroundColor: '#F0FDF4',
                  border: '2px solid #10B981',
                  borderRadius: 2
                }}
              >
                <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1, color: '#047857' }}>
                  ✨ What happens after you submit:
                </Typography>
                <Grid container spacing={1}>
                  <Grid item xs={12} sm={4}>
                    <Typography variant="body2" sx={{ color: '#065F46' }}>
                      ✅ Auto-categorized by AI
                    </Typography>
                  </Grid>
                  <Grid item xs={12} sm={4}>
                    <Typography variant="body2" sx={{ color: '#065F46' }}>
                      ✅ Prioritized intelligently
                    </Typography>
                  </Grid>
                  <Grid item xs={12} sm={4}>
                    <Typography variant="body2" sx={{ color: '#065F46' }}>
                      ✅ Routed to best agent
                    </Typography>
                  </Grid>
                </Grid>
              </Paper>
            )}
          </form>
        </CardContent>
      </Card>

      {/* Help Section */}
      <Card elevation={2}>
        <CardContent sx={{ p: isSmallScreen ? 2 : 3 }}>
          <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center', fontWeight: 600 }}>
            <InfoIcon sx={{ mr: 1, color: '#6366F1' }} />
            Need Immediate Help?
          </Typography>
          
          <Grid container spacing={2}>
            <Grid item xs={12} md={8}>
              <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 0.5 }}>
                  🆘 Emergency Support: +1 (555) 123-4567
                </Typography>
                <Typography variant="body2">
                  Available 24/7 for critical system issues
                </Typography>
              </Alert>
            </Grid>
            <Grid item xs={12} md={4}>
              <Paper 
                variant="outlined" 
                sx={{ 
                  p: 2, 
                  textAlign: 'center',
                  backgroundColor: '#EEF2FF',
                  border: '2px solid #6366F1'
                }}
              >
                <Typography variant="caption" color="text.secondary">
                  Tickets Resolved Today
                </Typography>
                <Typography variant="h5" sx={{ color: '#6366F1', fontWeight: 700 }}>
                  127 ✓
                </Typography>
              </Paper>
            </Grid>
          </Grid>

          <Box sx={{ mt: 3, p: 2, backgroundColor: '#F9FAFB', borderRadius: 2 }}>
            <Typography variant="body2" sx={{ fontWeight: 600, mb: 1 }}>
              💡 Tips for faster resolution:
            </Typography>
            <Grid container spacing={1}>
              <Grid item xs={12} sm={6}>
                <Typography variant="body2" color="text.secondary">
                  • Include screenshots or error messages
                </Typography>
              </Grid>
              <Grid item xs={12} sm={6}>
                <Typography variant="body2" color="text.secondary">
                  • Describe what you were doing when it occurred
                </Typography>
              </Grid>
              <Grid item xs={12} sm={6}>
                <Typography variant="body2" color="text.secondary">
                  • Mention troubleshooting steps you've tried
                </Typography>
              </Grid>
              <Grid item xs={12} sm={6}>
                <Typography variant="body2" color="text.secondary">
                  • Provide specific times/dates when possible
                </Typography>
              </Grid>
            </Grid>
          </Box>
        </CardContent>
      </Card>
    </Container>
  );
};

export default CreateTicket;

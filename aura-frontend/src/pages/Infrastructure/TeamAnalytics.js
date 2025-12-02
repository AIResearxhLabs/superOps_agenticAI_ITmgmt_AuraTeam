import React from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Button,
  useTheme,
} from '@mui/material';
import {
  Timeline as TimelineIcon,
  Construction as ConstructionIcon,
} from '@mui/icons-material';

const TeamAnalytics = () => {
  const theme = useTheme();

  return (
    <Box className="fade-in">
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>
            Team Analytics
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Advanced analytics and insights for team performance
          </Typography>
        </Box>
      </Box>

      <Card>
        <CardContent sx={{ textAlign: 'center', py: 8 }}>
          <ConstructionIcon sx={{ fontSize: 80, color: theme.palette.grey[400], mb: 2 }} />
          <Typography variant="h5" sx={{ fontWeight: 600, mb: 2 }}>
            Coming Soon
          </Typography>
          <Typography variant="body1" color="text.secondary" sx={{ mb: 3, maxWidth: 600, mx: 'auto' }}>
            Team Analytics will provide advanced insights including trend analysis, 
            comparative performance metrics, skill gap identification, and predictive forecasting.
          </Typography>
          <Button 
            variant="outlined" 
            startIcon={<TimelineIcon />}
            onClick={() => window.history.back()}
          >
            Go Back
          </Button>
        </CardContent>
      </Card>
    </Box>
  );
};

export default TeamAnalytics;

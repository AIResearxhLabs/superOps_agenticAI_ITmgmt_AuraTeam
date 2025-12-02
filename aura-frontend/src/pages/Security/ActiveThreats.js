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
  Warning as WarningIcon,
  Construction as ConstructionIcon,
} from '@mui/icons-material';

const ActiveThreats = () => {
  const theme = useTheme();

  return (
    <Box className="fade-in">
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>
            Active Threats
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Real-time threat monitoring and detailed threat intelligence
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
            Active Threats will provide real-time monitoring of ongoing security threats, 
            including detailed threat intelligence, attack vectors, affected assets, 
            and recommended mitigation strategies.
          </Typography>
          <Button 
            variant="outlined" 
            startIcon={<WarningIcon />}
            onClick={() => window.history.back()}
          >
            Go Back
          </Button>
        </CardContent>
      </Card>
    </Box>
  );
};

export default ActiveThreats;

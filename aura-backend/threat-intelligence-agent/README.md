# Threat Intelligence Agent

AI-powered threat intelligence aggregation and analysis system for the Aura Security Dashboard.

## Overview

The Threat Intelligence Agent crawls external cybersecurity sources, aggregates threat data, and uses AI to provide actionable insights for security teams. It integrates seamlessly with the Aura platform to enhance the Security Dashboard with real-time threat intelligence.

## Features

### 1. **Multi-Source Threat Aggregation**
- **CISA (Cybersecurity & Infrastructure Security Agency)**: Government cybersecurity alerts
- **CERT-IN (Indian Computer Emergency Response Team)**: Regional threat intelligence
- **FBI Cyber Division**: Federal law enforcement cyber alerts
- **BleepingComputer**: Tech news and security updates

### 2. **AI-Powered Analysis**
- Automatic threat categorization and severity assessment
- Quick summary generation for rapid review
- Indicators of Compromise (IoC) extraction
- Affected systems identification
- Actionable security recommendations

### 3. **Intelligent Caching**
- 1-hour cache duration to reduce external API calls
- Automatic cache invalidation and refresh
- Force refresh capability for critical situations

### 4. **Search & Filter**
- Search by keywords across threat titles, content, and tags
- Filter by severity (critical, high, medium, low)
- Filter by source
- Sort by published date (most recent first)

## Architecture

```
threat-intelligence-agent/
├── scrapers/              # Web scrapers for each source
│   ├── cisa_scraper.py
│   ├── certin_scraper.py
│   ├── fbi_scraper.py
│   └── bleeping_scraper.py
├── processors/            # AI processing pipeline
│   └── ai_processor.py
├── threat_manager.py      # Main orchestration
├── requirements.txt       # Python dependencies
└── cache/                 # Temporary threat cache
```

## Installation

### Prerequisites

- Python 3.8+
- OpenAI API key (for AI features)
- Internet connection (for external source scraping)

### Dependencies

```bash
pip install -r requirements.txt
```

**Core Dependencies:**
- `requests`: HTTP requests for web scraping
- `beautifulsoup4`: HTML parsing
- `feedparser`: RSS feed parsing
- `openai`: AI analysis
- `python-dotenv`: Environment configuration

## Configuration

Set the following environment variable:

```bash
OPENAI_API_KEY=your_openai_api_key_here
```

## Usage

### Integration with Backend API

The threat intelligence agent is integrated into the Service Desk Host backend:

```python
# Backend automatically initializes the threat manager
from threat_manager import get_threat_manager

manager = get_threat_manager(openai_api_key)
```

### API Endpoints

#### 1. Get Threat Intelligence Feeds

```
GET /api/v1/security/threat-intel/feeds
```

**Query Parameters:**
- `source` (optional): Filter by source (CISA, CERT-IN, FBI, BleepingComputer)
- `severity` (optional): Filter by severity (critical, high, medium, low)
- `limit` (default: 50): Maximum number of threats
- `use_ai` (default: true): Enable AI-powered summaries

**Response:**
```json
{
  "success": true,
  "threats": [
    {
      "feed_id": "cisa_2024_001",
      "source": "CISA",
      "source_url": "https://www.cisa.gov/alerts/...",
      "title": "Critical Vulnerability in X Software",
      "severity": "critical",
      "published_date": "2024-01-15T10:00:00Z",
      "fetched_date": "2024-01-15T14:30:00Z",
      "full_content": "...",
      "tags": ["vulnerability", "rce", "patch"],
      "quick_summary": "AI-generated 2-3 sentence summary",
      "iocs": ["CVE-2024-1234", "192.168.1.100"],
      "affected_systems": ["Windows 10", "Windows Server 2019"],
      "recommendations": [
        "Apply security patch immediately",
        "Monitor logs for exploitation attempts"
      ]
    }
  ],
  "total": 20,
  "filters": {
    "source": null,
    "severity": null,
    "use_ai": true
  }
}
```

#### 2. Get Threat Feed Detail

```
GET /api/v1/security/threat-intel/feed/{feed_id}
```

**Response:**
```json
{
  "success": true,
  "threat": { /* Full threat object with AI analysis */ }
}
```

#### 3. Get Threat Intelligence Summary

```
GET /api/v1/security/threat-intel/summary
```

**Response:**
```json
{
  "success": true,
  "summary": {
    "total_threats": 45,
    "severity_breakdown": {
      "critical": 3,
      "high": 12,
      "medium": 20,
      "low": 10
    },
    "source_breakdown": {
      "CISA": 15,
      "CERT-IN": 10,
      "FBI": 8,
      "BleepingComputer": 12
    },
    "recent_24h": 8,
    "last_updated": "2024-01-15T14:30:00Z",
    "cache_expires_in_minutes": 45
  }
}
```

#### 4. Refresh Threat Intelligence

```
POST /api/v1/security/threat-intel/refresh?use_ai=true
```

**Response:**
```json
{
  "success": true,
  "message": "Threat intelligence refreshed successfully",
  "total_threats": 48
}
```

#### 5. Search Threat Intelligence

```
GET /api/v1/security/threat-intel/search?query=ransomware&severity=high
```

**Response:**
```json
{
  "success": true,
  "query": "ransomware",
  "results": [ /* Matching threats */ ],
  "total": 5
}
```

## Frontend Integration

### React Component Example

```javascript
import { securityAPI } from '../services/api';

// Fetch threat intelligence feeds
const fetchThreats = async () => {
  try {
    const data = await securityAPI.getThreatIntelFeeds(
      null,      // source
      'high',    // severity
      20,        // limit
      true       // use AI
    );
    console.log('Threats:', data.threats);
  } catch (error) {
    console.error('Error fetching threats:', error);
  }
};

// Get threat summary
const fetchSummary = async () => {
  try {
    const data = await securityAPI.getThreatIntelSummary();
    console.log('Summary:', data.summary);
  } catch (error) {
    console.error('Error fetching summary:', error);
  }
};

// Search threats
const searchThreats = async (query) => {
  try {
    const data = await securityAPI.searchThreatIntel(query);
    console.log('Search results:', data.results);
  } catch (error) {
    console.error('Error searching:', error);
  }
};
```

## AI Processing Pipeline

The AI processor enriches threats with:

1. **Quick Summary**: 2-3 sentence executive summary
2. **IoC Extraction**: CVEs, hashes, IPs, domains, malware names
3. **Affected Systems**: Identifies vulnerable software/platforms
4. **Recommendations**: 3-5 actionable security steps

### Fallback Mode

If OpenAI API is unavailable, the system uses rule-based fallbacks:
- Pattern matching for CVEs and keywords
- Severity determination based on keyword analysis
- Generic recommendations based on threat category

## Scraper Details

### CISA Scraper
- **Target**: CISA cybersecurity advisories
- **Method**: RSS feed parsing + web scraping
- **Update Frequency**: Real-time (on-demand)
- **Fallback**: Mock government alerts

### CERT-IN Scraper
- **Target**: Indian CERT advisories
- **Method**: RSS feed parsing
- **Focus**: Regional threats and advisories
- **Fallback**: Mock regional alerts

### FBI Scraper
- **Target**: FBI Cyber Division alerts
- **Method**: Web scraping + RSS
- **Focus**: Law enforcement perspective
- **Fallback**: Mock FBI alerts

### BleepingComputer Scraper
- **Target**: Security news and analysis
- **Method**: RSS feed with filtering
- **Focus**: Timely security news
- **Fallback**: Mock news articles

## Performance Considerations

- **Caching**: 1-hour cache reduces API calls by 95%
- **Concurrent Scraping**: All sources scraped in parallel
- **Rate Limiting**: Respects source rate limits
- **Timeouts**: 30-second timeout per source
- **Error Handling**: Graceful degradation with fallbacks

## Testing

### Manual Testing

```bash
# Test individual scrapers
python -c "from scrapers import CISAScraper; print(CISAScraper().fetch_threats(5))"

# Test AI processor
python -c "from processors import AIThreatProcessor; import asyncio; processor = AIThreatProcessor(); asyncio.run(processor.generate_quick_summary({'title': 'Test', 'content': 'Test threat'}))"

# Test threat manager
python -c "from threat_manager import get_threat_manager; import asyncio; manager = get_threat_manager(); asyncio.run(manager.fetch_all_threats(limit_per_source=2))"
```

### Backend Integration Testing

```bash
# Start the backend
cd aura-backend/service-desk-host
python main.py

# Test endpoints
curl http://localhost:8001/api/v1/security/threat-intel/feeds?limit=5
curl http://localhost:8001/api/v1/security/threat-intel/summary
curl http://localhost:8001/api/v1/security/threat-intel/search?query=vulnerability
```

## Troubleshooting

### Common Issues

**Issue**: `ImportError: No module named 'threat_manager'`
- **Solution**: Ensure the path is added to Python path in backend initialization

**Issue**: Threats not updating
- **Solution**: Check cache expiry time or use force refresh endpoint

**Issue**: AI summaries not generating
- **Solution**: Verify `OPENAI_API_KEY` is set and valid

**Issue**: Scraper timeouts
- **Solution**: Check internet connectivity and firewall settings

### Debug Mode

Enable debug logging:

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## Security Considerations

1. **Rate Limiting**: Implement rate limiting on API endpoints
2. **Input Validation**: All search queries are sanitized
3. **API Key Security**: Store OpenAI API key securely
4. **HTTPS Only**: External sources accessed via HTTPS
5. **Content Filtering**: Threat content is sanitized before display

## Future Enhancements

- [ ] Additional threat sources (CVE databases, vendor advisories)
- [ ] Threat correlation and deduplication
- [ ] Custom alert rules and notifications
- [ ] Historical threat analysis and trends
- [ ] Integration with SIEM systems
- [ ] Automated threat response workflows
- [ ] Machine learning for threat prioritization

## Support

For issues or feature requests, please contact the development team or create an issue in the project repository.

## License

Copyright © 2024 Aura IT Management Platform. All rights reserved.

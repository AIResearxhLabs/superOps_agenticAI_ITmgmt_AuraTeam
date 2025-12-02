"""
CISA Threat Intelligence Scraper
Scrapes alerts and advisories from CISA.gov
"""

import requests
from bs4 import BeautifulSoup
from datetime import datetime
from typing import List, Dict, Optional
import logging
import feedparser

logger = logging.getLogger(__name__)


class CISAScraper:
    """Scraper for CISA cybersecurity alerts and advisories"""
    
    def __init__(self):
        self.base_url = "https://www.cisa.gov"
        self.alerts_feed = f"{self.base_url}/cybersecurity-advisories/all.xml"
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
    
    def fetch_threats(self, limit: int = 20) -> List[Dict]:
        """
        Fetch latest threat intelligence from CISA
        
        Args:
            limit: Maximum number of threats to fetch
            
        Returns:
            List of threat dictionaries
        """
        try:
            logger.info(f"Fetching CISA threats (limit: {limit})")
            
            # Try RSS feed first
            threats = self._fetch_from_rss(limit)
            
            if not threats:
                logger.warning("RSS feed failed, trying web scraping")
                threats = self._fetch_from_web(limit)
            
            logger.info(f"Successfully fetched {len(threats)} CISA threats")
            return threats
            
        except Exception as e:
            logger.error(f"Error fetching CISA threats: {e}")
            return self._get_fallback_data()
    
    def _fetch_from_rss(self, limit: int) -> List[Dict]:
        """Fetch threats from CISA RSS feed"""
        try:
            feed = feedparser.parse(self.alerts_feed)
            threats = []
            
            for entry in feed.entries[:limit]:
                threat = {
                    'feed_id': f"cisa_{entry.get('id', '').split('/')[-1]}",
                    'source': 'CISA',
                    'source_url': entry.get('link', self.base_url),
                    'title': entry.get('title', 'Untitled Alert'),
                    'severity': self._determine_severity(entry.get('title', '')),
                    'published_date': self._parse_date(entry.get('published', '')),
                    'fetched_date': datetime.utcnow().isoformat(),
                    'full_content': entry.get('summary', ''),
                    'tags': self._extract_tags(entry.get('title', '') + ' ' + entry.get('summary', ''))
                }
                threats.append(threat)
            
            return threats
            
        except Exception as e:
            logger.error(f"RSS feed parsing error: {e}")
            return []
    
    def _fetch_from_web(self, limit: int) -> List[Dict]:
        """Fallback: Fetch threats by scraping CISA website"""
        try:
            # This is a simplified fallback
            # In production, you'd implement proper web scraping
            url = f"{self.base_url}/news-events/cybersecurity-advisories"
            response = requests.get(url, headers=self.headers, timeout=10)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            threats = []
            
            # Mock data structure for demonstration
            # In production, parse actual HTML structure
            logger.info("Web scraping fallback - returning mock data")
            return []
            
        except Exception as e:
            logger.error(f"Web scraping error: {e}")
            return []
    
    def _determine_severity(self, text: str) -> str:
        """Determine severity based on keywords"""
        text_lower = text.lower()
        
        if any(word in text_lower for word in ['critical', 'emergency', 'zero-day', 'urgent']):
            return 'critical'
        elif any(word in text_lower for word in ['high', 'important', 'severe']):
            return 'high'
        elif any(word in text_lower for word in ['medium', 'moderate']):
            return 'medium'
        else:
            return 'low'
    
    def _parse_date(self, date_str: str) -> str:
        """Parse and normalize date string"""
        if not date_str:
            return datetime.utcnow().isoformat()
        
        try:
            # feedparser usually returns struct_time
            if hasattr(date_str, 'timetuple'):
                return datetime(*date_str.timetuple()[:6]).isoformat()
            return date_str
        except:
            return datetime.utcnow().isoformat()
    
    def _extract_tags(self, text: str) -> List[str]:
        """Extract relevant tags from text"""
        tags = []
        text_lower = text.lower()
        
        # Common cybersecurity keywords
        keywords = [
            'vulnerability', 'malware', 'ransomware', 'phishing', 
            'exploit', 'patch', 'cve', 'dos', 'ddos', 'breach',
            'authentication', 'encryption', 'firewall', 'network'
        ]
        
        for keyword in keywords:
            if keyword in text_lower:
                tags.append(keyword)
        
        return tags[:5]  # Limit to 5 most relevant tags
    
    def _get_fallback_data(self) -> List[Dict]:
        """Return mock data when scraping fails"""
        return [
            {
                'feed_id': 'cisa_mock_001',
                'source': 'CISA',
                'source_url': 'https://www.cisa.gov/cybersecurity-advisories',
                'title': 'Critical Vulnerability in Widely Used Software',
                'severity': 'critical',
                'published_date': datetime.utcnow().isoformat(),
                'fetched_date': datetime.utcnow().isoformat(),
                'full_content': 'CISA has identified a critical vulnerability affecting multiple systems. Immediate action recommended.',
                'tags': ['vulnerability', 'critical', 'patch']
            },
            {
                'feed_id': 'cisa_mock_002',
                'source': 'CISA',
                'source_url': 'https://www.cisa.gov/cybersecurity-advisories',
                'title': 'Ransomware Campaign Targeting Healthcare Sector',
                'severity': 'high',
                'published_date': datetime.utcnow().isoformat(),
                'fetched_date': datetime.utcnow().isoformat(),
                'full_content': 'CISA warns of active ransomware campaign specifically targeting healthcare organizations.',
                'tags': ['ransomware', 'healthcare', 'malware']
            }
        ]

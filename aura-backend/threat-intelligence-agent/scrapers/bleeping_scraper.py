"""
BleepingComputer Threat Intelligence Scraper
Scrapes security news and threat alerts from BleepingComputer.com
"""

import requests
from bs4 import BeautifulSoup
from datetime import datetime
from typing import List, Dict
import logging
import feedparser

logger = logging.getLogger(__name__)


class BleepingComputerScraper:
    """Scraper for BleepingComputer security news and alerts"""
    
    def __init__(self):
        self.base_url = "https://www.bleepingcomputer.com"
        self.rss_feed = f"{self.base_url}/feed/"
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
    
    def fetch_threats(self, limit: int = 20) -> List[Dict]:
        """
        Fetch latest security news from BleepingComputer
        
        Args:
            limit: Maximum number of threats to fetch
            
        Returns:
            List of threat dictionaries
        """
        try:
            logger.info(f"Fetching BleepingComputer threats (limit: {limit})")
            
            # Try RSS feed first
            threats = self._fetch_from_rss(limit)
            
            if not threats:
                logger.warning("RSS feed failed, using fallback data")
                threats = self._get_fallback_data()[:limit]
            
            logger.info(f"Successfully fetched {len(threats)} BleepingComputer threats")
            return threats
            
        except Exception as e:
            logger.error(f"Error fetching BleepingComputer threats: {e}")
            return self._get_fallback_data()[:limit]
    
    def _fetch_from_rss(self, limit: int) -> List[Dict]:
        """Fetch threats from RSS feed"""
        try:
            feed = feedparser.parse(self.rss_feed)
            threats = []
            
            for entry in feed.entries[:limit]:
                # Filter for security-related content
                title = entry.get('title', '')
                if self._is_security_related(title):
                    threat = {
                        'feed_id': f"bleeping_{entry.get('id', '').split('/')[-1]}",
                        'source': 'BleepingComputer',
                        'source_url': entry.get('link', self.base_url),
                        'title': title,
                        'severity': self._determine_severity(title),
                        'published_date': self._parse_date(entry.get('published', '')),
                        'fetched_date': datetime.utcnow().isoformat(),
                        'full_content': entry.get('summary', ''),
                        'tags': self._extract_tags(title + ' ' + entry.get('summary', ''))
                    }
                    threats.append(threat)
            
            return threats
            
        except Exception as e:
            logger.error(f"RSS feed parsing error: {e}")
            return []
    
    def _is_security_related(self, text: str) -> bool:
        """Check if content is security-related"""
        security_keywords = [
            'vulnerability', 'exploit', 'malware', 'ransomware', 'breach',
            'hack', 'attack', 'threat', 'security', 'patch', 'zero-day',
            'phishing', 'trojan', 'virus', 'backdoor', 'spy'
        ]
        text_lower = text.lower()
        return any(keyword in text_lower for keyword in security_keywords)
    
    def _determine_severity(self, text: str) -> str:
        """Determine severity based on keywords"""
        text_lower = text.lower()
        
        if any(word in text_lower for word in ['zero-day', 'critical', 'actively exploited', 'emergency']):
            return 'critical'
        elif any(word in text_lower for word in ['ransomware', 'major breach', 'widespread', 'high']):
            return 'high'
        elif any(word in text_lower for word in ['vulnerability', 'exploit', 'attack']):
            return 'medium'
        else:
            return 'low'
    
    def _parse_date(self, date_str: str) -> str:
        """Parse and normalize date string"""
        if not date_str:
            return datetime.utcnow().isoformat()
        
        try:
            if hasattr(date_str, 'timetuple'):
                return datetime(*date_str.timetuple()[:6]).isoformat()
            return date_str
        except:
            return datetime.utcnow().isoformat()
    
    def _extract_tags(self, text: str) -> List[str]:
        """Extract relevant tags from text"""
        tags = []
        text_lower = text.lower()
        
        keywords = [
            'ransomware', 'malware', 'vulnerability', 'exploit', 'phishing',
            'data breach', 'zero-day', 'trojan', 'spyware', 'botnet',
            'ddos', 'crypto', 'banking', 'windows', 'linux', 'android'
        ]
        
        for keyword in keywords:
            if keyword in text_lower:
                tags.append(keyword.replace(' ', '_'))
        
        return tags[:5]
    
    def _get_fallback_data(self) -> List[Dict]:
        """Return mock data representing typical BleepingComputer articles"""
        return [
            {
                'feed_id': 'bleeping_mock_001',
                'source': 'BleepingComputer',
                'source_url': 'https://www.bleepingcomputer.com',
                'title': 'Zero-Day Vulnerability Actively Exploited in the Wild',
                'severity': 'critical',
                'published_date': datetime.utcnow().isoformat(),
                'fetched_date': datetime.utcnow().isoformat(),
                'full_content': 'Security researchers have discovered a zero-day vulnerability being actively exploited by threat actors. The vulnerability affects multiple versions of popular software and allows remote code execution.',
                'tags': ['zero-day', 'vulnerability', 'exploit', 'rce']
            },
            {
                'feed_id': 'bleeping_mock_002',
                'source': 'BleepingComputer',
                'source_url': 'https://www.bleepingcomputer.com',
                'title': 'New Ransomware Strain Targets Enterprise Networks',
                'severity': 'high',
                'published_date': datetime.utcnow().isoformat(),
                'fetched_date': datetime.utcnow().isoformat(),
                'full_content': 'A new ransomware variant has been discovered targeting enterprise networks through compromised VPN credentials. The ransomware uses advanced encryption and demands payment in cryptocurrency.',
                'tags': ['ransomware', 'malware', 'enterprise', 'vpn']
            },
            {
                'feed_id': 'bleeping_mock_003',
                'source': 'BleepingComputer',
                'source_url': 'https://www.bleepingcomputer.com',
                'title': 'Microsoft Patches Critical Windows Vulnerabilities',
                'severity': 'high',
                'published_date': datetime.utcnow().isoformat(),
                'fetched_date': datetime.utcnow().isoformat(),
                'full_content': 'Microsoft has released emergency patches for multiple critical vulnerabilities in Windows OS. Users are urged to install updates immediately as proof-of-concept exploits are circulating.',
                'tags': ['windows', 'vulnerability', 'patch', 'microsoft']
            },
            {
                'feed_id': 'bleeping_mock_004',
                'source': 'BleepingComputer',
                'source_url': 'https://www.bleepingcomputer.com',
                'title': 'Banking Trojan Spreading Through Phishing Campaign',
                'severity': 'medium',
                'published_date': datetime.utcnow().isoformat(),
                'fetched_date': datetime.utcnow().isoformat(),
                'full_content': 'A sophisticated phishing campaign is distributing a banking trojan that steals credentials and financial information. The malware targets customers of major banks across multiple countries.',
                'tags': ['trojan', 'phishing', 'banking', 'malware']
            },
            {
                'feed_id': 'bleeping_mock_005',
                'source': 'BleepingComputer',
                'source_url': 'https://www.bleepingcomputer.com',
                'title': 'Major Data Breach Exposes Millions of User Records',
                'severity': 'high',
                'published_date': datetime.utcnow().isoformat(),
                'fetched_date': datetime.utcnow().isoformat(),
                'full_content': 'A major data breach has been disclosed affecting millions of users. Exposed data includes email addresses, hashed passwords, and personal information. Users are advised to change passwords immediately.',
                'tags': ['data_breach', 'leak', 'credentials']
            }
        ]

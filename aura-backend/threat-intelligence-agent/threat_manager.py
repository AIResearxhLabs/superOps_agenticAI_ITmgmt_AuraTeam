"""
Threat Intelligence Manager
Coordinates scraping, processing, and caching of threat intelligence feeds
"""

import asyncio
import logging
from datetime import datetime, timedelta
from typing import List, Dict, Optional
import json

from scrapers import CISAScraper, CERTINScraper, FBIScraper, BleepingComputerScraper
from processors import AIThreatProcessor

logger = logging.getLogger(__name__)


class ThreatIntelligenceManager:
    """Manages threat intelligence collection and processing"""
    
    def __init__(self, openai_api_key: Optional[str] = None):
        """
        Initialize threat intelligence manager
        
        Args:
            openai_api_key: OpenAI API key for AI processing
        """
        # Initialize scrapers
        self.scrapers = {
            'CISA': CISAScraper(),
            'CERT-IN': CERTINScraper(),
            'FBI': FBIScraper(),
            'BleepingComputer': BleepingComputerScraper()
        }
        
        # Initialize AI processor
        self.ai_processor = AIThreatProcessor(openai_api_key)
        
        # Cache for threats
        self.threat_cache = []
        self.last_fetch_time = None
        self.cache_duration = timedelta(hours=1)  # Refresh every hour
        
        logger.info("Threat Intelligence Manager initialized")
    
    async def fetch_all_threats(self, limit_per_source: int = 10, use_ai: bool = True) -> List[Dict]:
        """
        Fetch threats from all sources
        
        Args:
            limit_per_source: Maximum threats to fetch from each source
            use_ai: Whether to enrich threats with AI processing
            
        Returns:
            List of threat dictionaries
        """
        try:
            logger.info(f"Fetching threats from all sources (limit: {limit_per_source}/source)")
            
            # Check cache first
            if self._is_cache_valid():
                logger.info(f"Returning {len(self.threat_cache)} cached threats")
                return self.threat_cache
            
            all_threats = []
            
            # Fetch from each source
            for source_name, scraper in self.scrapers.items():
                try:
                    logger.info(f"Fetching from {source_name}...")
                    threats = scraper.fetch_threats(limit=limit_per_source)
                    
                    # Enrich with AI if enabled
                    if use_ai and threats:
                        logger.info(f"AI processing {len(threats)} threats from {source_name}")
                        enriched_threats = []
                        for threat in threats:
                            try:
                                enriched = await self.ai_processor.enrich_threat(threat)
                                enriched_threats.append(enriched)
                            except Exception as e:
                                logger.error(f"Failed to enrich threat {threat.get('feed_id')}: {e}")
                                enriched_threats.append(threat)  # Use original if enrichment fails
                        
                        all_threats.extend(enriched_threats)
                    else:
                        all_threats.extend(threats)
                    
                    logger.info(f"✓ Fetched {len(threats)} threats from {source_name}")
                    
                except Exception as e:
                    logger.error(f"✗ Failed to fetch from {source_name}: {e}")
                    continue
            
            # Sort by published date (most recent first)
            all_threats.sort(
                key=lambda x: x.get('published_date', ''),
                reverse=True
            )
            
            # Update cache
            self.threat_cache = all_threats
            self.last_fetch_time = datetime.utcnow()
            
            logger.info(f"Successfully fetched {len(all_threats)} total threats")
            return all_threats
            
        except Exception as e:
            logger.error(f"Error fetching threats: {e}")
            return self.threat_cache if self.threat_cache else []
    
    async def fetch_threats_by_source(self, source: str, limit: int = 20, use_ai: bool = True) -> List[Dict]:
        """
        Fetch threats from a specific source
        
        Args:
            source: Source name (CISA, CERT-IN, FBI, BleepingComputer)
            limit: Maximum threats to fetch
            use_ai: Whether to enrich with AI
            
        Returns:
            List of threat dictionaries
        """
        try:
            scraper = self.scrapers.get(source)
            if not scraper:
                logger.error(f"Unknown source: {source}")
                return []
            
            logger.info(f"Fetching {limit} threats from {source}")
            threats = scraper.fetch_threats(limit=limit)
            
            if use_ai and threats:
                enriched_threats = []
                for threat in threats:
                    try:
                        enriched = await self.ai_processor.enrich_threat(threat)
                        enriched_threats.append(enriched)
                    except Exception as e:
                        logger.error(f"Failed to enrich threat: {e}")
                        enriched_threats.append(threat)
                return enriched_threats
            
            return threats
            
        except Exception as e:
            logger.error(f"Error fetching threats from {source}: {e}")
            return []
    
    async def search_threats(self, query: str, severity: Optional[str] = None) -> List[Dict]:
        """
        Search threats by keyword and optionally filter by severity
        
        Args:
            query: Search query
            severity: Optional severity filter (critical, high, medium, low)
            
        Returns:
            Filtered list of threats
        """
        try:
            # Ensure we have cached threats
            if not self.threat_cache:
                await self.fetch_all_threats()
            
            query_lower = query.lower()
            results = []
            
            for threat in self.threat_cache:
                # Search in title, content, and tags
                title = threat.get('title', '').lower()
                content = threat.get('full_content', '').lower()
                tags = ' '.join(threat.get('tags', [])).lower()
                
                if query_lower in title or query_lower in content or query_lower in tags:
                    # Apply severity filter if provided
                    if severity:
                        if threat.get('severity', '').lower() == severity.lower():
                            results.append(threat)
                    else:
                        results.append(threat)
            
            logger.info(f"Search for '{query}' returned {len(results)} results")
            return results
            
        except Exception as e:
            logger.error(f"Error searching threats: {e}")
            return []
    
    async def get_threat_summary(self) -> Dict:
        """
        Get summary statistics of current threats
        
        Returns:
            Dictionary with threat summary data
        """
        try:
            if not self.threat_cache:
                await self.fetch_all_threats()
            
            # Count by severity
            severity_counts = {
                'critical': 0,
                'high': 0,
                'medium': 0,
                'low': 0
            }
            
            # Count by source
            source_counts = {}
            
            # Recent threats (last 24 hours)
            recent_threshold = datetime.utcnow() - timedelta(hours=24)
            recent_count = 0
            
            for threat in self.threat_cache:
                # Count severity
                severity = threat.get('severity', 'low').lower()
                if severity in severity_counts:
                    severity_counts[severity] += 1
                
                # Count source
                source = threat.get('source', 'Unknown')
                source_counts[source] = source_counts.get(source, 0) + 1
                
                # Count recent
                try:
                    pub_date = datetime.fromisoformat(threat.get('published_date', '').replace('Z', '+00:00'))
                    if pub_date > recent_threshold:
                        recent_count += 1
                except:
                    pass
            
            summary = {
                'total_threats': len(self.threat_cache),
                'severity_breakdown': severity_counts,
                'source_breakdown': source_counts,
                'recent_24h': recent_count,
                'last_updated': self.last_fetch_time.isoformat() if self.last_fetch_time else None,
                'cache_expires_in_minutes': self._get_cache_expiry_minutes()
            }
            
            return summary
            
        except Exception as e:
            logger.error(f"Error generating threat summary: {e}")
            return {
                'total_threats': 0,
                'severity_breakdown': {},
                'source_breakdown': {},
                'recent_24h': 0,
                'last_updated': None
            }
    
    def _is_cache_valid(self) -> bool:
        """Check if cache is still valid"""
        if not self.threat_cache or not self.last_fetch_time:
            return False
        
        age = datetime.utcnow() - self.last_fetch_time
        return age < self.cache_duration
    
    def _get_cache_expiry_minutes(self) -> int:
        """Get minutes until cache expires"""
        if not self.last_fetch_time:
            return 0
        
        age = datetime.utcnow() - self.last_fetch_time
        remaining = self.cache_duration - age
        return max(0, int(remaining.total_seconds() / 60))
    
    async def force_refresh(self, use_ai: bool = True) -> List[Dict]:
        """
        Force refresh of threat cache
        
        Args:
            use_ai: Whether to use AI enrichment
            
        Returns:
            Fresh list of threats
        """
        logger.info("Force refreshing threat cache")
        self.threat_cache = []
        self.last_fetch_time = None
        return await self.fetch_all_threats(use_ai=use_ai)


# Singleton instance
_threat_manager_instance = None


def get_threat_manager(openai_api_key: Optional[str] = None) -> ThreatIntelligenceManager:
    """Get or create threat manager singleton"""
    global _threat_manager_instance
    
    if _threat_manager_instance is None:
        _threat_manager_instance = ThreatIntelligenceManager(openai_api_key)
    
    return _threat_manager_instance

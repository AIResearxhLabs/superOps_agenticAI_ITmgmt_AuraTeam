"""
AI-Powered Threat Intelligence Processor
Uses OpenAI to generate summaries and analyze threat data
"""

import os
from typing import Dict, List, Optional
import logging
from openai import OpenAI

logger = logging.getLogger(__name__)


class AIThreatProcessor:
    """Process threat intelligence using AI"""
    
    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize AI processor
        
        Args:
            api_key: OpenAI API key (defaults to environment variable)
        """
        self.api_key = api_key or os.getenv('OPENAI_API_KEY')
        self.client = None
        
        if self.api_key:
            try:
                self.client = OpenAI(api_key=self.api_key)
                logger.info("AI processor initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize OpenAI client: {e}")
        else:
            logger.warning("No OpenAI API key provided - AI features will use fallbacks")
    
    async def generate_quick_summary(self, threat: Dict) -> str:
        """
        Generate a concise 2-3 sentence summary of a threat
        
        Args:
            threat: Threat dictionary with title and content
            
        Returns:
            AI-generated summary
        """
        try:
            if not self.client:
                return self._fallback_summary(threat)
            
            prompt = f"""Analyze this cybersecurity threat and provide a concise 2-3 sentence summary 
suitable for security experts:

Title: {threat.get('title', 'Unknown')}
Source: {threat.get('source', 'Unknown')}
Content: {threat.get('full_content', '')[:500]}

Provide only the summary, no additional commentary."""

            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a cybersecurity analyst providing concise threat summaries."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=150,
                temperature=0.3
            )
            
            summary = response.choices[0].message.content.strip()
            logger.info(f"Generated AI summary for threat: {threat.get('feed_id')}")
            return summary
            
        except Exception as e:
            logger.error(f"Error generating AI summary: {e}")
            return self._fallback_summary(threat)
    
    async def extract_iocs(self, threat: Dict) -> List[str]:
        """
        Extract Indicators of Compromise (IoCs) from threat content
        
        Args:
            threat: Threat dictionary
            
        Returns:
            List of IoCs (CVEs, hashes, IPs, domains, etc.)
        """
        try:
            if not self.client:
                return self._fallback_iocs(threat)
            
            prompt = f"""Extract all Indicators of Compromise (IoCs) from this threat intelligence:

Title: {threat.get('title', '')}
Content: {threat.get('full_content', '')[:800]}

List ONLY the IoCs found (CVEs, file hashes, IP addresses, domains, malware names).
Format as a simple list, one per line. If none found, respond with "None"."""

            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a cybersecurity analyst extracting IoCs from threat intelligence."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=200,
                temperature=0.1
            )
            
            iocs_text = response.choices[0].message.content.strip()
            
            if iocs_text.lower() == "none":
                return []
            
            iocs = [ioc.strip() for ioc in iocs_text.split('\n') if ioc.strip()]
            logger.info(f"Extracted {len(iocs)} IoCs from threat: {threat.get('feed_id')}")
            return iocs[:10]  # Limit to top 10
            
        except Exception as e:
            logger.error(f"Error extracting IoCs: {e}")
            return self._fallback_iocs(threat)
    
    async def identify_affected_systems(self, threat: Dict) -> List[str]:
        """
        Identify systems/software affected by the threat
        
        Args:
            threat: Threat dictionary
            
        Returns:
            List of affected systems
        """
        try:
            if not self.client:
                return self._fallback_affected_systems(threat)
            
            prompt = f"""Identify which systems, software, or platforms are affected by this cybersecurity threat:

Title: {threat.get('title', '')}
Content: {threat.get('full_content', '')[:600]}

List ONLY the affected systems/software (e.g., "Windows 10", "Apache HTTP Server 2.4", "iOS 17").
One per line. If unclear, respond with "Not specified"."""

            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a cybersecurity analyst identifying affected systems."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=150,
                temperature=0.2
            )
            
            systems_text = response.choices[0].message.content.strip()
            
            if systems_text.lower() == "not specified":
                return ["Not specified in alert"]
            
            systems = [sys.strip() for sys in systems_text.split('\n') if sys.strip()]
            logger.info(f"Identified {len(systems)} affected systems: {threat.get('feed_id')}")
            return systems[:5]  # Limit to top 5
            
        except Exception as e:
            logger.error(f"Error identifying affected systems: {e}")
            return self._fallback_affected_systems(threat)
    
    async def generate_recommendations(self, threat: Dict) -> List[str]:
        """
        Generate actionable security recommendations
        
        Args:
            threat: Threat dictionary
            
        Returns:
            List of recommendations
        """
        try:
            if not self.client:
                return self._fallback_recommendations(threat)
            
            prompt = f"""Based on this cybersecurity threat, provide 3-5 actionable security recommendations:

Title: {threat.get('title', '')}
Severity: {threat.get('severity', '')}
Content: {threat.get('full_content', '')[:600]}

Provide only the recommendations as a numbered list. Be specific and actionable."""

            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a cybersecurity advisor providing actionable recommendations."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=250,
                temperature=0.4
            )
            
            recs_text = response.choices[0].message.content.strip()
            
            # Parse numbered list
            recommendations = []
            for line in recs_text.split('\n'):
                line = line.strip()
                if line and (line[0].isdigit() or line.startswith('-') or line.startswith('•')):
                    # Remove numbering/bullets
                    rec = line.lstrip('0123456789.-•').strip()
                    if rec:
                        recommendations.append(rec)
            
            logger.info(f"Generated {len(recommendations)} recommendations: {threat.get('feed_id')}")
            return recommendations[:5]
            
        except Exception as e:
            logger.error(f"Error generating recommendations: {e}")
            return self._fallback_recommendations(threat)
    
    async def enrich_threat(self, threat: Dict) -> Dict:
        """
        Enrich threat data with AI-generated insights
        
        Args:
            threat: Original threat dictionary
            
        Returns:
            Enriched threat dictionary
        """
        try:
            enriched = threat.copy()
            
            # Generate all AI insights
            enriched['quick_summary'] = await self.generate_quick_summary(threat)
            enriched['iocs'] = await self.extract_iocs(threat)
            enriched['affected_systems'] = await self.identify_affected_systems(threat)
            enriched['recommendations'] = await self.generate_recommendations(threat)
            
            logger.info(f"Successfully enriched threat: {threat.get('feed_id')}")
            return enriched
            
        except Exception as e:
            logger.error(f"Error enriching threat: {e}")
            return threat
    
    # Fallback methods when AI is unavailable
    
    def _fallback_summary(self, threat: Dict) -> str:
        """Generate basic summary without AI"""
        title = threat.get('title', 'Unknown threat')
        source = threat.get('source', 'Unknown source')
        severity = threat.get('severity', 'unknown')
        
        return f"{source} reports a {severity} severity threat: {title}. Immediate review recommended for security teams."
    
    def _fallback_iocs(self, threat: Dict) -> List[str]:
        """Extract basic IoCs without AI"""
        content = threat.get('full_content', '') + ' ' + threat.get('title', '')
        iocs = []
        
        # Simple CVE extraction
        import re
        cves = re.findall(r'CVE-\d{4}-\d{4,7}', content, re.IGNORECASE)
        iocs.extend(cves)
        
        return list(set(iocs))[:5]
    
    def _fallback_affected_systems(self, threat: Dict) -> List[str]:
        """Identify basic affected systems without AI"""
        content = (threat.get('title', '') + ' ' + threat.get('full_content', '')).lower()
        
        systems = []
        common_systems = [
            'Windows', 'Linux', 'macOS', 'iOS', 'Android',
            'Chrome', 'Firefox', 'Safari', 'Edge',
            'Apache', 'nginx', 'IIS', 'MySQL', 'PostgreSQL'
        ]
        
        for system in common_systems:
            if system.lower() in content:
                systems.append(system)
        
        return systems[:5] if systems else ["Multiple systems potentially affected"]
    
    def _fallback_recommendations(self, threat: Dict) -> List[str]:
        """Generate basic recommendations without AI"""
        severity = threat.get('severity', 'medium')
        
        base_recs = [
            "Review security logs for signs of compromise",
            "Ensure all systems are patched to the latest versions",
            "Monitor network traffic for suspicious activity"
        ]
        
        if severity in ['critical', 'high']:
            base_recs.insert(0, "Implement emergency security measures immediately")
            base_recs.append("Consider temporary isolation of affected systems")
        
        return base_recs[:5]

"""
AI Service utilities for OpenAI integration and prompt management
"""

import os
import time
import json
import logging
from typing import Dict, Any, Optional, List
from openai import AsyncOpenAI
from shared.models.base import AIRequest, AIResponse

logger = logging.getLogger(__name__)


class AIService:
    """OpenAI API service for AI-powered features"""
    
    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        if not self.api_key or self.api_key == "your_openai_api_key_here":
            logger.warning("OpenAI API key not provided or is placeholder. AI features will use fallback mode.")
            self.client = None
        else:
            try:
                self.client = AsyncOpenAI(api_key=self.api_key)
                logger.info("OpenAI client initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize OpenAI client: {e}")
                self.client = None
    
    async def generate_completion(
        self,
        prompt: str,
        model: str = "gpt-3.5-turbo",
        temperature: float = 0.7,
        max_tokens: int = 1000,
        context: Optional[Dict[str, Any]] = None
    ) -> AIResponse:
        """Generate AI completion using OpenAI API"""
        
        if not self.client:
            logger.error("OpenAI client not initialized")
            return AIResponse(
                response="AI service unavailable",
                model=model,
                confidence=0.0
            )
        
        try:
            start_time = time.time()
            
            # Prepare messages
            messages = [{"role": "user", "content": prompt}]
            
            # Add context if provided
            if context:
                context_str = json.dumps(context, indent=2)
                messages.insert(0, {
                    "role": "system",
                    "content": f"Context information:\n{context_str}"
                })
            
            # Make API call
            response = await self.client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens
            )
            
            processing_time = time.time() - start_time
            
            # Extract response
            ai_response = response.choices[0].message.content
            tokens_used = response.usage.total_tokens if response.usage else None
            
            logger.info(f"AI completion generated in {processing_time:.3f}s using {tokens_used} tokens")
            
            return AIResponse(
                response=ai_response,
                model=model,
                tokens_used=tokens_used,
                processing_time=processing_time,
                confidence=0.8  # Default confidence score
            )
            
        except Exception as e:
            logger.error(f"Error generating AI completion: {e}")
            return AIResponse(
                response=f"Error generating AI response: {str(e)}",
                model=model,
                confidence=0.0
            )
    
    async def classify_text(
        self,
        text: str,
        categories: List[str],
        context: Optional[str] = None
    ) -> Dict[str, Any]:
        """Classify text into predefined categories"""
        
        if not self.client:
            return self._fallback_classify_text(text, categories)
        
        categories_str = ", ".join(categories)
        prompt = f"""
        Classify the following text into one of these categories: {categories_str}
        
        Text to classify: "{text}"
        
        {f"Additional context: {context}" if context else ""}
        
        Respond with ONLY the category name and a confidence score (0-1) in this JSON format:
        {{"category": "category_name", "confidence": 0.95}}
        """
        
        try:
            response = await self.generate_completion(
                prompt=prompt,
                temperature=0.3,  # Lower temperature for classification
                max_tokens=100
            )
            
            # Parse JSON response
            result = json.loads(response.response.strip())
            
            return {
                "category": result.get("category"),
                "confidence": result.get("confidence", 0.0),
                "all_categories": categories
            }
            
        except json.JSONDecodeError:
            logger.error("Failed to parse classification response as JSON")
            # Use fallback classification
            return self._fallback_classify_text(text, categories)
        except Exception as e:
            logger.error(f"Error in text classification: {e}")
            # Use fallback classification
            return self._fallback_classify_text(text, categories)
    
    def _fallback_classify_text(self, text: str, categories: List[str]) -> Dict[str, Any]:
        """Fallback classification based on keywords when AI service is unavailable"""
        text_lower = text.lower()
        category_scores = {}
        
        # Simple keyword matching for common categories
        keyword_map = {
            "Hardware": ["hardware", "computer", "laptop", "desktop", "monitor", "keyboard", "mouse", "printer", "device"],
            "Software": ["software", "application", "app", "program", "install", "update", "windows", "microsoft", "adobe"],
            "Network": ["network", "internet", "wifi", "connection", "vpn", "ethernet", "router", "slow"],
            "Email": ["email", "outlook", "gmail", "mail", "inbox", "send", "receive"],
            "Access": ["access", "login", "password", "account", "permission", "locked", "authentication"],
            "Security": ["security", "virus", "malware", "antivirus", "firewall", "breach", "hack"],
            "Other": []
        }
        
        for category, keywords in keyword_map.items():
            if category in categories:
                score = sum(1 for keyword in keywords if keyword in text_lower)
                category_scores[category] = score
        
        # Find best match
        if category_scores:
            best_category = max(category_scores.keys(), key=lambda k: category_scores[k])
            confidence = min(0.9, category_scores[best_category] * 0.2 + 0.3)
        else:
            best_category = categories[0] if categories else "Other"
            confidence = 0.5
        
        return {
            "category": best_category,
            "confidence": confidence,
            "all_categories": categories
        }

    async def extract_intent(self, text: str) -> Dict[str, Any]:
        """Extract intent and entities from text"""
        
        prompt = f"""
        Analyze the following text and extract:
        1. The main intent/purpose
        2. Key entities (people, places, things, dates, etc.)
        3. Sentiment (positive, negative, neutral)
        4. Urgency level (low, medium, high, critical)
        
        Text: "{text}"
        
        Respond in JSON format:
        {{
            "intent": "brief description of intent",
            "entities": ["entity1", "entity2"],
            "sentiment": "positive/negative/neutral",
            "urgency": "low/medium/high/critical",
            "confidence": 0.85
        }}
        """
        
        try:
            response = await self.generate_completion(
                prompt=prompt,
                temperature=0.4,
                max_tokens=300
            )
            
            result = json.loads(response.response.strip())
            return result
            
        except json.JSONDecodeError:
            logger.error("Failed to parse intent extraction response as JSON")
            return {
                "intent": "unknown",
                "entities": [],
                "sentiment": "neutral",
                "urgency": "medium",
                "confidence": 0.0
            }
        except Exception as e:
            logger.error(f"Error in intent extraction: {e}")
            return {
                "intent": "unknown",
                "entities": [],
                "sentiment": "neutral", 
                "urgency": "medium",
                "confidence": 0.0
            }
    
    async def generate_response(
        self,
        user_message: str,
        context: Optional[Dict[str, Any]] = None,
        persona: str = "helpful IT assistant"
    ) -> str:
        """Generate conversational response"""
        
        system_prompt = f"""
        You are a {persona}. Respond to user messages in a helpful, professional, and friendly manner.
        Keep responses concise but informative.
        """
        
        if context:
            system_prompt += f"\n\nContext: {json.dumps(context, indent=2)}"
        
        prompt = f"{system_prompt}\n\nUser: {user_message}\n\nAssistant:"
        
        try:
            response = await self.generate_completion(
                prompt=prompt,
                temperature=0.7,
                max_tokens=500
            )
            
            return response.response
            
        except Exception as e:
            logger.error(f"Error generating conversational response: {e}")
            return "I apologize, but I'm having trouble processing your request right now. Please try again later."
    
    async def summarize_text(self, text: str, max_length: int = 200) -> str:
        """Summarize long text"""
        
        prompt = f"""
        Summarize the following text in {max_length} characters or less.
        Focus on the key points and main ideas.
        
        Text: "{text}"
        
        Summary:
        """
        
        try:
            response = await self.generate_completion(
                prompt=prompt,
                temperature=0.5,
                max_tokens=max_length // 2  # Rough token estimate
            )
            
            return response.response.strip()
            
        except Exception as e:
            logger.error(f"Error summarizing text: {e}")
            return text[:max_length] + "..." if len(text) > max_length else text


class PromptTemplate:
    """Template system for AI prompts"""
    
    def __init__(self, template: str, variables: List[str]):
        self.template = template
        self.variables = variables
    
    def render(self, **kwargs) -> str:
        """Render template with provided variables"""
        try:
            return self.template.format(**kwargs)
        except KeyError as e:
            raise ValueError(f"Missing required variable: {e}")
    
    def validate_variables(self, **kwargs) -> bool:
        """Validate that all required variables are provided"""
        missing = [var for var in self.variables if var not in kwargs]
        if missing:
            raise ValueError(f"Missing required variables: {missing}")
        return True


class PromptManager:
    """Manager for AI prompt templates"""
    
    def __init__(self):
        self.templates = {}
        self._load_default_templates()
    
    def _load_default_templates(self):
        """Load default prompt templates"""
        
        # Ticket categorization template
        self.templates["ticket_categorization"] = PromptTemplate(
            template="""
            Categorize the following IT support ticket into one of these categories:
            {categories}
            
            Ticket Title: {title}
            Ticket Description: {description}
            
            Consider:
            - Technical keywords and terminology
            - Problem domain and scope
            - Urgency indicators
            
            Respond with ONLY the category name and confidence score in JSON format:
            {{"category": "category_name", "confidence": 0.95}}
            """,
            variables=["categories", "title", "description"]
        )
        
        # Knowledge base search template
        self.templates["kb_search"] = PromptTemplate(
            template="""
            Based on the user's question, suggest the most relevant knowledge base articles:
            
            Question: {question}
            Available Articles: {articles}
            
            Rank the articles by relevance and provide the top {max_results} results.
            Consider keyword matching, topic relevance, and solution applicability.
            
            Respond in JSON format:
            {{
                "recommended_articles": [
                    {{"title": "article_title", "relevance_score": 0.95, "reason": "why this is relevant"}},
                    ...
                ]
            }}
            """,
            variables=["question", "articles", "max_results"]
        )
        
        # Chatbot response template
        self.templates["chatbot_response"] = PromptTemplate(
            template="""
            You are an AI IT support assistant. Help the user with their IT-related question or issue.
            
            User Message: {user_message}
            {context_info}
            
            Guidelines:
            - Be helpful and professional
            - Provide step-by-step solutions when possible
            - Ask clarifying questions if needed
            - Escalate to human agent if issue is complex
            
            Response:
            """,
            variables=["user_message", "context_info"]
        )
        
        # Security analysis template
        self.templates["security_analysis"] = PromptTemplate(
            template="""
            Analyze the following security event and determine:
            1. Threat level (low, medium, high, critical)
            2. Threat type and category
            3. Recommended actions
            4. Risk assessment
            
            Event Details: {event_details}
            Context: {context}
            
            Respond in JSON format:
            {{
                "threat_level": "high",
                "threat_type": "malware",
                "category": "security_incident",
                "recommended_actions": ["action1", "action2"],
                "risk_score": 0.85,
                "confidence": 0.90
            }}
            """,
            variables=["event_details", "context"]
        )
    
    def get_template(self, name: str) -> PromptTemplate:
        """Get template by name"""
        if name not in self.templates:
            raise ValueError(f"Template '{name}' not found")
        return self.templates[name]
    
    def add_template(self, name: str, template: PromptTemplate):
        """Add custom template"""
        self.templates[name] = template
    
    def render_template(self, name: str, **kwargs) -> str:
        """Render template with variables"""
        template = self.get_template(name)
        template.validate_variables(**kwargs)
        return template.render(**kwargs)


# Global instances
ai_service = AIService()
prompt_manager = PromptManager()


async def initialize_ai_service(api_key: str = None):
    """Initialize AI service with API key"""
    global ai_service
    ai_service = AIService(api_key)
    logger.info("AI service initialized")


def get_ai_service() -> AIService:
    """Get global AI service instance"""
    return ai_service


def get_prompt_manager() -> PromptManager:
    """Get global prompt manager instance"""
    return prompt_manager

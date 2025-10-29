"""
Aura Service Desk Host - Ticket Management, Knowledge Base, and AI Chatbot
"""

import os
import logging
from contextlib import asynccontextmanager
from typing import List, Optional, Dict, Any
from datetime import datetime
from fastapi import FastAPI, HTTPException, Depends, Query, Path
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv(dotenv_path="../.env")

from shared.models.base import (
    HealthCheckResponse, BaseResponse, PaginationParams, PaginatedResponse,
    Priority, Status, BaseDBModel
)
from shared.utils.database import (
    init_database_connections, check_database_health, db_manager,
    RedisCache, MongoRepository
)
from shared.utils.ai_service import get_ai_service, get_prompt_manager
from shared.middleware.common import (
    RequestLoggingMiddleware, ErrorHandlingMiddleware,
    RateLimitingMiddleware, SecurityHeadersMiddleware
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# Pydantic Models
class TicketCreate(BaseModel):
    """Create ticket request model"""
    title: str
    description: str
    category: Optional[str] = None
    priority: Priority = Priority.MEDIUM
    user_id: str
    user_email: str
    user_name: str
    department: Optional[str] = None
    attachments: List[str] = []


class TicketUpdate(BaseModel):
    """Update ticket request model"""
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    priority: Optional[Priority] = None
    status: Optional[Status] = None
    assigned_to: Optional[str] = None
    resolution: Optional[str] = None


class Ticket(BaseDBModel):
    """Ticket model"""
    title: str
    description: str
    category: str
    priority: Priority
    status: Status = Status.OPEN
    user_id: str
    user_email: str
    user_name: str
    department: Optional[str] = None
    assigned_to: Optional[str] = None
    resolution: Optional[str] = None
    attachments: List[str] = []
    ai_suggestions: List[Dict[str, Any]] = []


class KBArticleCreate(BaseModel):
    """Create knowledge base article request"""
    title: str
    content: str
    category: str
    tags: List[str] = []
    author: str


class KBArticle(BaseDBModel):
    """Knowledge base article model"""
    title: str
    content: str
    category: str
    tags: List[str] = []
    author: str
    views: int = 0
    helpful_votes: int = 0
    unhelpful_votes: int = 0


class ChatMessage(BaseModel):
    """Chat message model"""
    message: str
    user_id: Optional[str] = None
    context: Optional[Dict[str, Any]] = None


class ChatResponse(BaseModel):
    """Chat response model"""
    response: str
    suggestions: List[str] = []
    escalate_to_human: bool = False
    confidence: float = 0.0


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    logger.info("🎫 Starting Service Desk Host")
    
    try:
        # Initialize database connections (skip PostgreSQL for now)
        await init_database_connections(
            postgres_url=None,  # Skip PostgreSQL since it's not running
            mongodb_url=os.getenv("MONGODB_URL"),
            mongodb_name="aura_servicedesk",
            redis_url=os.getenv("REDIS_URL")
        )
        
        # Initialize repositories (handle cases where databases aren't available)
        try:
            mongo_db = db_manager.get_mongo_db()
            app.state.tickets_repo = MongoRepository("tickets", mongo_db)
            app.state.kb_repo = MongoRepository("knowledge_base", mongo_db)
        except RuntimeError:
            logger.warning("MongoDB not available - using fallback mode")
            app.state.tickets_repo = None
            app.state.kb_repo = None
        
        try:
            redis_client = db_manager.get_redis_client()
            app.state.cache = RedisCache(redis_client)
        except RuntimeError:
            logger.warning("Redis not available - using fallback mode")
            app.state.cache = None
        
        # Initialize AI service
        from shared.utils.ai_service import initialize_ai_service
        await initialize_ai_service(os.getenv("OPENAI_API_KEY"))
        
        logger.info("Service Desk Host initialized successfully")
        
    except Exception as e:
        logger.error(f"Startup error: {e}")
        raise
    
    yield
    
    # Cleanup
    try:
        await db_manager.close_connections()
        logger.info("Database connections closed")
    except Exception as e:
        logger.error(f"Cleanup error: {e}")
    
    logger.info("🛑 Service Desk Host stopped")


# Create FastAPI app
app = FastAPI(
    title="Aura Service Desk Host",
    description="Service Desk Automation - Tickets, Knowledge Base, and AI Chatbot",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add custom middleware
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(ErrorHandlingMiddleware)
app.add_middleware(RateLimitingMiddleware, requests_per_minute=500)
app.add_middleware(SecurityHeadersMiddleware)


# Health Check
@app.get("/health", response_model=HealthCheckResponse)
async def health_check():
    """Service health check"""
    dependencies = await check_database_health()
    
    # Check AI service
    ai_service = get_ai_service()
    dependencies["openai"] = "healthy" if ai_service.client else "unhealthy"
    
    overall_status = "healthy" if all(status == "healthy" for status in dependencies.values()) else "degraded"
    
    return HealthCheckResponse(
        service_name="service-desk-host",
        status=overall_status,
        version="1.0.0",
        dependencies=dependencies
    )


# Ticket Management APIs
@app.post("/api/v1/tickets", response_model=BaseResponse)
async def create_ticket(ticket_data: TicketCreate):
    """Create a new ticket with AI categorization"""
    
    try:
        # Get AI service
        ai_service = get_ai_service()
        prompt_manager = get_prompt_manager()
        
        # Auto-categorize ticket if category not provided
        if not ticket_data.category:
            categories = ["Hardware", "Software", "Network", "Access", "Email", "Other"]
            
            try:
                # Use AI to categorize
                prompt = prompt_manager.render_template(
                    "ticket_categorization",
                    categories=", ".join(categories),
                    title=ticket_data.title,
                    description=ticket_data.description
                )
                
                classification = await ai_service.classify_text(
                    text=f"{ticket_data.title} {ticket_data.description}",
                    categories=categories
                )
                
                ticket_data.category = classification.get("category", "Other")
                
            except Exception as e:
                logger.error(f"AI categorization failed: {e}")
                ticket_data.category = "Other"
        
        # Get AI suggestions for resolution
        ai_suggestions = []
        try:
            if app.state.kb_repo:
                kb_articles = await app.state.kb_repo.find_many(
                    {"category": ticket_data.category},
                    limit=5
                )
                
                if kb_articles:
                    articles_str = "\n".join([f"- {article['title']}" for article in kb_articles])
                    prompt = prompt_manager.render_template(
                        "kb_search",
                        question=f"{ticket_data.title} {ticket_data.description}",
                        articles=articles_str,
                        max_results="3"
                    )
                    
                    response = await ai_service.generate_completion(prompt, max_tokens=300)
                    # Parse AI response for suggestions
                    ai_suggestions = [{"type": "kb_recommendation", "content": response.response}]
        except Exception as e:
            logger.error(f"AI suggestions failed: {e}")
        
        # Create ticket document
        ticket_doc = {
            "title": ticket_data.title,
            "description": ticket_data.description,
            "category": ticket_data.category,
            "priority": ticket_data.priority,
            "status": Status.OPEN,
            "user_id": ticket_data.user_id,
            "user_email": ticket_data.user_email,
            "user_name": ticket_data.user_name,
            "department": ticket_data.department,
            "attachments": ticket_data.attachments,
            "ai_suggestions": ai_suggestions,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        # Save to database or generate mock ID
        if app.state.tickets_repo:
            ticket_id = await app.state.tickets_repo.create(ticket_doc)
        else:
            # Fallback: generate mock ticket ID
            import uuid
            ticket_id = str(uuid.uuid4())
            logger.warning("MongoDB not available - using mock ticket ID")
        
        # Cache ticket for quick access
        if app.state.cache:
            import json
            await app.state.cache.set(f"ticket:{ticket_id}", json.dumps(ticket_doc, default=str), ttl=3600)
        
        logger.info(f"Ticket created: {ticket_id}")
        
        return BaseResponse(
            message="Ticket created successfully",
            data={
                "ticket_id": ticket_id,
                "category": ticket_data.category,
                "ai_suggestions": ai_suggestions
            }
        )
        
    except Exception as e:
        logger.error(f"Error creating ticket: {e}")
        raise HTTPException(status_code=500, detail="Failed to create ticket")


@app.get("/api/v1/tickets", response_model=PaginatedResponse)
async def get_tickets(
    status: Optional[Status] = Query(None, description="Filter by status"),
    category: Optional[str] = Query(None, description="Filter by category"),
    assigned_to: Optional[str] = Query(None, description="Filter by assigned agent"),
    user_id: Optional[str] = Query(None, description="Filter by user"),
    pagination: PaginationParams = Depends()
):
    """Get tickets with filters and pagination"""
    
    try:
        # Build filter
        filter_dict = {}
        if status:
            filter_dict["status"] = status
        if category:
            filter_dict["category"] = category
        if assigned_to:
            filter_dict["assigned_to"] = assigned_to
        if user_id:
            filter_dict["user_id"] = user_id
        
        # Get tickets
        if app.state.tickets_repo:
            tickets = await app.state.tickets_repo.find_many(
                filter_dict,
                limit=pagination.limit,
                skip=pagination.offset
            )
            
            # Get total count
            total = await app.state.tickets_repo.count(filter_dict)
        else:
            # Fallback: return mock tickets for demo
            from datetime import datetime, timedelta
            import uuid
            
            mock_tickets = [
                {
                    "_id": str(uuid.uuid4()),
                    "title": "Computer running very slowly after Windows update",
                    "description": "My computer has been running extremely slowly since the latest Windows update. Applications take forever to load and the system freezes occasionally.",
                    "category": "Software",
                    "priority": "high",
                    "status": "open",
                    "user_id": "jane.doe@company.com",
                    "user_email": "jane.doe@company.com",
                    "user_name": "Jane Doe",
                    "department": "Marketing",
                    "created_at": datetime.utcnow() - timedelta(hours=2),
                    "updated_at": datetime.utcnow() - timedelta(hours=1)
                },
                {
                    "_id": str(uuid.uuid4()),
                    "title": "Email client not receiving new messages",
                    "description": "Outlook is not downloading new emails since this morning. I can send emails but cannot receive them.",
                    "category": "Email",
                    "priority": "high",
                    "status": "open",
                    "user_id": "john.smith@company.com",
                    "user_email": "john.smith@company.com",
                    "user_name": "John Smith",
                    "department": "Sales",
                    "created_at": datetime.utcnow() - timedelta(hours=1),
                    "updated_at": datetime.utcnow() - timedelta(minutes=30)
                },
                {
                    "_id": str(uuid.uuid4()),
                    "title": "Unable to connect to office Wi-Fi",
                    "description": "I can't connect to the office Wi-Fi network. It keeps asking for password even though I'm entering the correct one.",
                    "category": "Network",
                    "priority": "medium",
                    "status": "in_progress",
                    "user_id": "alice.johnson@company.com",
                    "user_email": "alice.johnson@company.com",
                    "user_name": "Alice Johnson",
                    "department": "HR",
                    "assigned_to": "Sarah Wilson",
                    "created_at": datetime.utcnow() - timedelta(days=1),
                    "updated_at": datetime.utcnow() - timedelta(hours=3)
                },
                {
                    "_id": str(uuid.uuid4()),
                    "title": "Printer not responding",
                    "description": "The office printer is not responding to print jobs. The status shows as offline even though it's powered on.",
                    "category": "Hardware",
                    "priority": "low",
                    "status": "resolved",
                    "user_id": "bob.wilson@company.com",
                    "user_email": "bob.wilson@company.com",
                    "user_name": "Bob Wilson",
                    "department": "Finance",
                    "assigned_to": "David Kim",
                    "resolution": "Restarted printer service and updated drivers",
                    "created_at": datetime.utcnow() - timedelta(days=2),
                    "updated_at": datetime.utcnow() - timedelta(hours=6)
                }
            ]
            
            # Apply filters to mock data
            filtered_tickets = mock_tickets
            if status:
                filtered_tickets = [t for t in filtered_tickets if t["status"] == status.value]
            if category:
                filtered_tickets = [t for t in filtered_tickets if t["category"].lower() == category.lower()]
            if assigned_to:
                filtered_tickets = [t for t in filtered_tickets if t.get("assigned_to") == assigned_to]
            if user_id:
                filtered_tickets = [t for t in filtered_tickets if t["user_id"] == user_id]
            
            # Apply pagination
            total = len(filtered_tickets)
            start_idx = pagination.offset
            end_idx = start_idx + pagination.limit
            tickets = filtered_tickets[start_idx:end_idx]
            
            logger.warning("MongoDB not available - returning mock ticket list")
        
        # Calculate pagination info
        pages = (total + pagination.limit - 1) // pagination.limit
        has_next = pagination.page < pages
        has_prev = pagination.page > 1
        
        return PaginatedResponse(
            items=tickets,
            total=total,
            page=pagination.page,
            limit=pagination.limit,
            pages=pages,
            has_next=has_next,
            has_prev=has_prev
        )
        
    except Exception as e:
        logger.error(f"Error retrieving tickets: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve tickets")


@app.get("/api/v1/tickets/{ticket_id}")
async def get_ticket(ticket_id: str = Path(..., description="Ticket ID")):
    """Get ticket by ID"""
    
    try:
        # Skip cache for now - get directly from database
        if app.state.tickets_repo:
            ticket = await app.state.tickets_repo.find_by_id(ticket_id)
            if not ticket:
                raise HTTPException(status_code=404, detail="Ticket not found")
            
            # Return ticket data directly for frontend compatibility
            return ticket
        else:
            # Fallback when database is not available
            logger.warning("MongoDB not available - returning mock ticket data")
            raise HTTPException(status_code=404, detail="Ticket not found")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving ticket {ticket_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve ticket")


@app.put("/api/v1/tickets/{ticket_id}")
async def update_ticket(
    ticket_id: str,
    update_data: TicketUpdate
):
    """Update ticket"""
    
    try:
        # Get current ticket
        ticket = await app.state.tickets_repo.find_by_id(ticket_id)
        if not ticket:
            raise HTTPException(status_code=404, detail="Ticket not found")
        
        # Prepare update data
        update_dict = {k: v for k, v in update_data.dict().items() if v is not None}
        update_dict["updated_at"] = datetime.utcnow()
        
        # Update in database
        success = await app.state.tickets_repo.update_by_id(ticket_id, update_dict)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to update ticket")
        
        # Clear cache
        await app.state.cache.delete(f"ticket:{ticket_id}")
        
        logger.info(f"Ticket updated: {ticket_id}")
        
        return BaseResponse(
            message="Ticket updated successfully",
            data={"ticket_id": ticket_id, "updated_fields": list(update_dict.keys())}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating ticket {ticket_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to update ticket")


@app.post("/api/v1/tickets/{ticket_id}/categorize")
async def categorize_ticket(ticket_id: str):
    """Re-categorize ticket using AI"""
    
    try:
        # Get ticket
        ticket = await app.state.tickets_repo.find_by_id(ticket_id)
        if not ticket:
            raise HTTPException(status_code=404, detail="Ticket not found")
        
        # Get AI service
        ai_service = get_ai_service()
        categories = ["Hardware", "Software", "Network", "Access", "Email", "Other"]
        
        # Classify using AI
        classification = await ai_service.classify_text(
            text=f"{ticket['title']} {ticket['description']}",
            categories=categories
        )
        
        # Update ticket category
        update_dict = {
            "category": classification.get("category", "Other"),
            "updated_at": datetime.utcnow()
        }
        
        await app.state.tickets_repo.update_by_id(ticket_id, update_dict)
        
        # Clear cache
        await app.state.cache.delete(f"ticket:{ticket_id}")
        
        logger.info(f"Ticket re-categorized: {ticket_id} -> {classification.get('category')}")
        
        return BaseResponse(
            message="Ticket categorized successfully",
            data={
                "ticket_id": ticket_id,
                "category": classification.get("category"),
                "confidence": classification.get("confidence")
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error categorizing ticket: {e}")
        raise HTTPException(status_code=500, detail="Failed to categorize ticket")


@app.post("/api/v1/tickets/{ticket_id}/analyze")
async def analyze_ticket(ticket_id: str):
    """Comprehensive AI analysis of ticket for routing and recommendations"""
    
    try:
        # Get ticket
        if not app.state.tickets_repo:
            # Fallback when database is not available
            logger.warning("MongoDB not available - using mock ticket data for analysis")
            ticket = {
                "title": "Sample ticket for analysis",
                "description": "This is a mock ticket used when database is unavailable",
                "category": "Software",
                "priority": "medium",
                "department": "IT"
            }
        else:
            ticket = await app.state.tickets_repo.find_by_id(ticket_id)
            if not ticket:
                raise HTTPException(status_code=404, detail="Ticket not found")
        
        # Get AI service
        ai_service = get_ai_service()
        
        # Mock agents for demonstration
        agents = [
            {"name": "Sarah Wilson", "skills": ["Network", "Hardware"], "availability": "available"},
            {"name": "Mike Chen", "skills": ["Software", "Email"], "availability": "busy"},
            {"name": "Emma Rodriguez", "skills": ["Access", "Security"], "availability": "available"},
            {"name": "David Kim", "skills": ["Hardware", "Software"], "availability": "available"}
        ]
        
        # Find similar tickets for context
        similar_tickets = []
        try:
            if app.state.tickets_repo:
                all_tickets = await app.state.tickets_repo.find_many(
                    {"category": ticket.get("category"), "_id": {"$ne": ticket.get("_id")}},
                    limit=10
                )
                
                # Simple similarity based on category and keywords
                ticket_text = f"{ticket.get('title', '')} {ticket.get('description', '')}".lower()
                for similar in all_tickets:
                    similar_text = f"{similar.get('title', '')} {similar.get('description', '')}".lower()
                    # Basic keyword matching for similarity
                    common_words = set(ticket_text.split()) & set(similar_text.split())
                    if len(common_words) > 2:
                        similar_tickets.append({
                            "title": similar.get("title", ""),
                            "similarity_score": len(common_words) / max(len(ticket_text.split()), len(similar_text.split())),
                            "resolution_approach": similar.get("resolution", "Standard troubleshooting")
                        })
                
                # Sort by similarity and take top 3
                similar_tickets.sort(key=lambda x: x["similarity_score"], reverse=True)
                similar_tickets = similar_tickets[:3]
            else:
                logger.warning("MongoDB not available - skipping similar tickets search")
            
        except Exception as e:
            logger.error(f"Error finding similar tickets: {e}")
        
        # Generate comprehensive AI analysis
        try:
            analysis_prompt = f"""
            Analyze this IT support ticket and provide comprehensive recommendations:
            
            Ticket Title: {ticket.get('title', '')}
            Description: {ticket.get('description', '')}
            Category: {ticket.get('category', '')}
            Priority: {ticket.get('priority', '')}
            Department: {ticket.get('department', 'Unknown')}
            
            Available Agents:
            {chr(10).join([f"- {agent['name']}: {', '.join(agent['skills'])} ({agent['availability']})" for agent in agents])}
            
            Similar Past Tickets:
            {chr(10).join([f"- {similar['title']} (similarity: {similar['similarity_score']:.2f})" for similar in similar_tickets]) if similar_tickets else "None found"}
            
            Please provide:
            1. Best agent to assign (with confidence percentage)
            2. 3-5 self-fix suggestions for the user
            3. Estimated resolution time
            4. Priority recommendation
            5. Any additional insights
            
            Format your response as a structured analysis.
            """
            
            ai_response = await ai_service.generate_completion(analysis_prompt, max_tokens=800)
            
            # Parse AI response and structure the data
            response_text = ai_response.response
            
            # Find the best available agent based on skills matching
            ticket_category = ticket.get('category', '').lower()
            best_agent = None
            best_confidence = 0
            
            for agent in agents:
                if agent['availability'] == 'available':
                    skill_match = any(skill.lower() in ticket_category or ticket_category in skill.lower() 
                                    for skill in agent['skills'])
                    if skill_match:
                        confidence = 0.85 if len([s for s in agent['skills'] if s.lower() in ticket_category]) > 0 else 0.70
                        if confidence > best_confidence:
                            best_agent = agent
                            best_confidence = confidence
            
            # Fallback to first available agent
            if not best_agent:
                available_agents = [a for a in agents if a['availability'] == 'available']
                if available_agents:
                    best_agent = available_agents[0]
                    best_confidence = 0.60
            
            # Generate self-fix suggestions based on category
            self_fix_suggestions = []
            category = ticket.get('category', '').lower()
            
            if 'network' in category:
                self_fix_suggestions = [
                    "Check network cable connections",
                    "Restart your router and modem",
                    "Run Windows Network Troubleshooter",
                    "Check if other devices can connect to the network"
                ]
            elif 'email' in category:
                self_fix_suggestions = [
                    "Check your internet connection",
                    "Verify email server settings",
                    "Clear browser cache and cookies",
                    "Try accessing email from a different device"
                ]
            elif 'software' in category:
                self_fix_suggestions = [
                    "Restart the application",
                    "Check for software updates",
                    "Run the program as administrator",
                    "Temporarily disable antivirus software"
                ]
            elif 'hardware' in category:
                self_fix_suggestions = [
                    "Check all cable connections",
                    "Restart the device",
                    "Check power supply connections",
                    "Look for any visible damage or loose parts"
                ]
            else:
                self_fix_suggestions = [
                    "Restart your computer",
                    "Check for system updates",
                    "Try the operation again",
                    "Document any error messages you see"
                ]
            
            # Estimate resolution time based on priority and category
            priority = ticket.get('priority', 'medium').lower()
            if priority == 'critical':
                resolution_time = "1-2 hours"
            elif priority == 'high':
                resolution_time = "4-6 hours"
            elif priority == 'medium':
                resolution_time = "1-2 business days"
            else:
                resolution_time = "2-3 business days"
            
            # Priority recommendation logic
            if any(word in ticket.get('description', '').lower() for word in ['urgent', 'critical', 'down', 'offline']):
                priority_recommendation = "Consider upgrading to HIGH priority due to business impact keywords"
            elif ticket.get('department', '').lower() in ['executive', 'management']:
                priority_recommendation = "Consider MEDIUM priority for executive department"
            else:
                priority_recommendation = f"Current {priority.upper()} priority appears appropriate"
            
            # Additional insights
            additional_insights = []
            if similar_tickets:
                additional_insights.append(f"Found {len(similar_tickets)} similar tickets that may provide resolution guidance")
            if ticket.get('department'):
                additional_insights.append(f"Department context: {ticket.get('department')} may have specific requirements")
            if len(ticket.get('description', '')) < 50:
                additional_insights.append("Ticket description is brief - may need additional information from user")
            
            # Structure the analysis response
            analysis_data = {
                "suggested_processor": {
                    "name": best_agent['name'] if best_agent else "No agent available",
                    "confidence": best_confidence,
                    "reason": f"Best match for {ticket.get('category', 'this')} category with {best_agent['skills'] if best_agent else []} skills"
                },
                "self_fix_suggestions": self_fix_suggestions,
                "estimated_resolution_time": resolution_time,
                "priority_recommendation": priority_recommendation,
                "similar_tickets": similar_tickets,
                "additional_insights": additional_insights,
                "ai_analysis_text": response_text
            }
            
            logger.info(f"AI analysis completed for ticket {ticket_id}")
            
            # Return analysis data directly for frontend compatibility
            return {
                "ticket_id": ticket_id,
                "analysis": analysis_data
            }
            
        except Exception as e:
            logger.error(f"AI analysis failed: {e}")
            # Provide fallback analysis
            fallback_analysis = {
                "suggested_processor": {
                    "name": "General Support Agent",
                    "confidence": 0.5,
                    "reason": "AI analysis unavailable - defaulting to general support"
                },
                "self_fix_suggestions": [
                    "Restart your computer",
                    "Check for updates",
                    "Try the operation again",
                    "Contact IT support if issue persists"
                ],
                "estimated_resolution_time": "1-2 business days",
                "priority_recommendation": "Current priority level appears appropriate",
                "similar_tickets": [],
                "additional_insights": ["AI analysis temporarily unavailable"],
                "ai_analysis_text": "Fallback analysis provided due to AI service unavailability"
            }
            
            return BaseResponse(
                message="Ticket analysis completed with fallback data",
                data={
                    "ticket_id": ticket_id,
                    "analysis": fallback_analysis
                }
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error analyzing ticket {ticket_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to analyze ticket")


# Knowledge Base APIs
@app.post("/api/v1/kb/articles", response_model=BaseResponse)
async def create_kb_article(article_data: KBArticleCreate):
    """Create knowledge base article"""
    
    try:
        # Create article document
        article_doc = {
            "title": article_data.title,
            "content": article_data.content,
            "category": article_data.category,
            "tags": article_data.tags,
            "author": article_data.author,
            "views": 0,
            "helpful_votes": 0,
            "unhelpful_votes": 0,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        # Save to database
        article_id = await app.state.kb_repo.create(article_doc)
        
        logger.info(f"KB article created: {article_id}")
        
        return BaseResponse(
            message="Knowledge base article created successfully",
            data={"article_id": article_id}
        )
        
    except Exception as e:
        logger.error(f"Error creating KB article: {e}")
        raise HTTPException(status_code=500, detail="Failed to create knowledge base article")


@app.get("/api/v1/kb/articles", response_model=PaginatedResponse)
async def get_kb_articles(
    category: Optional[str] = Query(None, description="Filter by category"),
    search: Optional[str] = Query(None, description="Search in title and content"),
    pagination: PaginationParams = Depends()
):
    """Get knowledge base articles with filters"""
    
    try:
        # Build filter
        filter_dict = {}
        if category:
            filter_dict["category"] = category
        if search:
            # Simple text search in title and content
            filter_dict["$or"] = [
                {"title": {"$regex": search, "$options": "i"}},
                {"content": {"$regex": search, "$options": "i"}}
            ]
        
        # Get articles
        articles = await app.state.kb_repo.find_many(
            filter_dict,
            limit=pagination.limit,
            skip=pagination.offset
        )
        
        # Get total count
        total = await app.state.kb_repo.count(filter_dict)
        
        # Calculate pagination info
        pages = (total + pagination.limit - 1) // pagination.limit
        has_next = pagination.page < pages
        has_prev = pagination.page > 1
        
        return PaginatedResponse(
            items=articles,
            total=total,
            page=pagination.page,
            limit=pagination.limit,
            pages=pages,
            has_next=has_next,
            has_prev=has_prev
        )
        
    except Exception as e:
        logger.error(f"Error retrieving KB articles: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve knowledge base articles")


@app.get("/api/v1/kb/articles/{article_id}")
async def get_kb_article(article_id: str):
    """Get knowledge base article by ID"""
    
    try:
        # Get article
        article = await app.state.kb_repo.find_by_id(article_id)
        if not article:
            raise HTTPException(status_code=404, detail="Article not found")
        
        # Increment view count
        await app.state.kb_repo.update_by_id(article_id, {"$inc": {"views": 1}})
        
        return BaseResponse(message="Article retrieved successfully", data=article)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving KB article {article_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve knowledge base article")


@app.post("/api/v1/kb/search", response_model=BaseResponse)
async def search_kb_articles(search_request: dict):
    """AI-powered knowledge base search"""
    
    try:
        query = search_request.get("query", "")
        if not query:
            raise HTTPException(status_code=400, detail="Query is required")
        
        # Get all articles for AI-powered search
        all_articles = await app.state.kb_repo.find_many({}, limit=100)
        
        if not all_articles:
            return BaseResponse(
                message="No articles found",
                data={"articles": [], "suggestions": []}
            )
        
        # Use AI to find most relevant articles
        ai_service = get_ai_service()
        prompt_manager = get_prompt_manager()
        
        articles_str = "\n".join([
            f"ID: {article['_id']}, Title: {article['title']}, Category: {article['category']}"
            for article in all_articles
        ])
        
        try:
            prompt = prompt_manager.render_template(
                "kb_search",
                question=query,
                articles=articles_str,
                max_results="5"
            )
            
            response = await ai_service.generate_completion(prompt, max_tokens=500)
            
            # Simple relevance scoring based on title and content matching
            relevant_articles = []
            query_lower = query.lower()
            
            for article in all_articles:
                score = 0
                if query_lower in article['title'].lower():
                    score += 3
                if query_lower in article['content'].lower():
                    score += 2
                if article['category'].lower() in query_lower:
                    score += 1
                
                if score > 0:
                    article['relevance_score'] = score
                    relevant_articles.append(article)
            
            # Sort by relevance
            relevant_articles.sort(key=lambda x: x.get('relevance_score', 0), reverse=True)
            top_articles = relevant_articles[:5]
            
            return BaseResponse(
                message="Knowledge base search completed",
                data={
                    "articles": top_articles,
                    "ai_suggestions": response.response,
                    "total_found": len(relevant_articles)
                }
            )
            
        except Exception as e:
            logger.error(f"AI search failed: {e}")
            # Fallback to simple text search
            simple_results = []
            query_lower = query.lower()
            
            for article in all_articles:
                if (query_lower in article['title'].lower() or 
                    query_lower in article['content'].lower()):
                    simple_results.append(article)
            
            return BaseResponse(
                message="Knowledge base search completed (fallback)",
                data={"articles": simple_results[:5], "suggestions": []}
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in KB search: {e}")
        raise HTTPException(status_code=500, detail="Failed to search knowledge base")


# Chatbot APIs
@app.post("/api/v1/chatbot/message", response_model=ChatResponse)
async def chatbot_message(message_data: ChatMessage):
    """Process chatbot message and generate AI response"""
    
    try:
        user_message = message_data.message
        user_id = message_data.user_id
        context = message_data.context or {}
        
        # Get AI service
        ai_service = get_ai_service()
        
        # Analyze user intent
        intent_analysis = await ai_service.extract_intent(user_message)
        
        # Search for relevant KB articles
        kb_results = []
        try:
            all_articles = await app.state.kb_repo.find_many({}, limit=50)
            query_lower = user_message.lower()
            
            for article in all_articles:
                if (query_lower in article['title'].lower() or 
                    any(tag.lower() in query_lower for tag in article.get('tags', []))):
                    kb_results.append(article)
            
        except Exception as e:
            logger.error(f"KB search in chatbot failed: {e}")
        
        # Prepare context for AI
        ai_context = {
            "user_intent": intent_analysis,
            "relevant_articles": [{"title": art["title"], "category": art["category"]} 
                                for art in kb_results[:3]],
            "user_context": context
        }
        
        # Generate AI response
        try:
            prompt_manager = get_prompt_manager()
            context_info = f"Context: {ai_context}" if ai_context else ""
            
            prompt = prompt_manager.render_template(
                "chatbot_response",
                user_message=user_message,
                context_info=context_info
            )
            
            ai_response = await ai_service.generate_completion(prompt, max_tokens=400)
            
            # Determine if escalation is needed
            escalate_keywords = ['complex', 'urgent', 'manager', 'escalate', 'human agent']
            escalate_to_human = any(keyword in user_message.lower() for keyword in escalate_keywords)
            
            # Generate suggestions
            suggestions = []
            if kb_results:
                suggestions = [f"Check: {art['title']}" for art in kb_results[:3]]
            
            # Determine confidence based on intent analysis
            confidence = intent_analysis.get('confidence', 0.7)
            
            response = ChatResponse(
                response=ai_response.response,
                suggestions=suggestions,
                escalate_to_human=escalate_to_human,
                confidence=confidence
            )
            
            # Cache conversation for context
            if user_id:
                conversation_key = f"chat:{user_id}"
                await app.state.cache.set(
                    conversation_key,
                    f"{user_message}|{ai_response.response}",
                    ttl=1800  # 30 minutes
                )
            
            logger.info(f"Chatbot response generated for user {user_id}")
            
            return response
            
        except Exception as e:
            logger.error(f"AI response generation failed: {e}")
            return ChatResponse(
                response="I apologize, but I'm having trouble processing your request right now. Would you like me to connect you with a human agent?",
                suggestions=["Contact human agent", "Try rephrasing your question"],
                escalate_to_human=True,
                confidence=0.0
            )
        
    except Exception as e:
        logger.error(f"Error in chatbot message processing: {e}")
        return ChatResponse(
            response="I'm experiencing technical difficulties. Please try again or contact support.",
            suggestions=["Try again", "Contact support"],
            escalate_to_human=True,
            confidence=0.0
        )


@app.get("/api/v1/kb/recommendations")
async def get_kb_recommendations(ticket_id: Optional[str] = Query(None)):
    """Get KB article recommendations for a ticket"""
    
    try:
        if not ticket_id:
            # Return popular articles
            articles = await app.state.kb_repo.find_many({}, limit=10)
            # Sort by views (simple popularity)
            articles.sort(key=lambda x: x.get('views', 0), reverse=True)
            
            return BaseResponse(
                message="Popular KB articles retrieved",
                data={"articles": articles[:5], "type": "popular"}
            )
        
        # Get ticket for context
        ticket = await app.state.tickets_repo.find_by_id(ticket_id)
        if not ticket:
            raise HTTPException(status_code=404, detail="Ticket not found")
        
        # Find articles in same category
        category_articles = await app.state.kb_repo.find_many(
            {"category": ticket.get("category", "")},
            limit=10
        )
        
        # Use AI to recommend most relevant articles
        if category_articles:
            ai_service = get_ai_service()
            
            articles_context = "\n".join([
                f"- {article['title']}: {article['content'][:200]}..."
                for article in category_articles
            ])
            
            try:
                prompt = f"""
                Based on this ticket, recommend the most relevant knowledge base articles:
                
                Ticket: {ticket.get('title', '')} - {ticket.get('description', '')}
                Category: {ticket.get('category', '')}
                
                Available Articles:
                {articles_context}
                
                Rank the top 3 most relevant articles and explain why they're relevant.
                """
                
                response = await ai_service.generate_completion(prompt, max_tokens=300)
                
                return BaseResponse(
                    message="KB recommendations generated",
                    data={
                        "articles": category_articles[:5],
                        "ai_analysis": response.response,
                        "ticket_id": ticket_id,
                        "type": "ai_recommended"
                    }
                )
                
            except Exception as e:
                logger.error(f"AI recommendation failed: {e}")
        
        # Fallback to category-based recommendations
        return BaseResponse(
            message="Category-based KB recommendations",
            data={
                "articles": category_articles[:5],
                "ticket_id": ticket_id,
                "type": "category_based"
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting KB recommendations: {e}")
        raise HTTPException(status_code=500, detail="Failed to get KB recommendations")


if __name__ == "__main__":
    # Get configuration from environment
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8001"))
    debug = os.getenv("DEBUG", "false").lower() == "true"
    
    # Run the application
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=debug,
        log_level="info",
        access_log=True
    )

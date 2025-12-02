#!/usr/bin/env python3
"""
Generate synthetic data for Infrastructure & Talent Management module
Populates agent profiles, performance metrics, and workload distribution data
"""

import random
import json
from datetime import datetime, timedelta
from faker import Faker

fake = Faker()

# Agent skill categories matching ticket categories
SKILL_CATEGORIES = [
    "Network/VPN",
    "Software/Applications", 
    "Hardware/Equipment",
    "Email/Communication",
    "Access/Permissions",
    "Security",
    "Database",
    "Cloud Services"
]

# Performance tiers
PERFORMANCE_TIERS = {
    "high": {
        "tickets_per_day": (8, 12),
        "avg_resolution_hours": (2, 4),
        "satisfaction_range": (4.5, 5.0),
        "count": 3
    },
    "average": {
        "tickets_per_day": (5, 8),
        "avg_resolution_hours": (4, 8),
        "satisfaction_range": (4.0, 4.7),
        "count": 6
    },
    "new": {
        "tickets_per_day": (3, 5),
        "avg_resolution_hours": (8, 12),
        "satisfaction_range": (3.8, 4.5),
        "count": 3
    }
}


def generate_agent_profile(agent_id, tier):
    """Generate a realistic agent profile"""
    
    hire_dates = {
        "high": (datetime.now() - timedelta(days=random.randint(730, 1825))),  # 2-5 years
        "average": (datetime.now() - timedelta(days=random.randint(365, 1095))),  # 1-3 years
        "new": (datetime.now() - timedelta(days=random.randint(90, 365)))  # 3-12 months
    }
    
    # Generate skills (2-4 skills per agent)
    num_skills = random.randint(2, 4)
    skills = random.sample(SKILL_CATEGORIES, num_skills)
    
    return {
        "agent_id": f"agent_{agent_id:03d}",
        "name": fake.name(),
        "email": fake.email(),
        "role": "IT Support Specialist" if tier == "new" else 
                "Senior IT Specialist" if tier == "high" else 
                "IT Specialist",
        "department": "IT Support",
        "skills": skills,
        "tier": tier,
        "hire_date": hire_dates[tier].isoformat(),
        "status": "active",
        "avatar_color": random.choice(['#1976d2', '#388e3c', '#d32f2f', '#f57c00', '#7b1fa2', '#0288d1'])
    }


def generate_performance_history(agent, days=90):
    """Generate historical performance data for an agent"""
    
    tier_config = PERFORMANCE_TIERS[agent['tier']]
    tickets_range = tier_config['tickets_per_day']
    resolution_range = tier_config['avg_resolution_hours']
    satisfaction_range = tier_config['satisfaction_range']
    
    history = []
    current_date = datetime.now() - timedelta(days=days)
    
    for day in range(days):
        date = current_date + timedelta(days=day)
        
        # Skip weekends (simplified)
        if date.weekday() >= 5:
            continue
        
        # Add some variability
        tickets_resolved = random.randint(tickets_range[0], tickets_range[1])
        
        # Occasional bad/good days
        if random.random() < 0.1:  # 10% chance of outlier
            tickets_resolved = int(tickets_resolved * random.uniform(0.5, 1.5))
        
        avg_resolution = round(random.uniform(resolution_range[0], resolution_range[1]), 1)
        satisfaction = round(random.uniform(satisfaction_range[0], satisfaction_range[1]), 2)
        
        history.append({
            "date": date.strftime("%Y-%m-%d"),
            "tickets_resolved": max(0, tickets_resolved),
            "avg_resolution_time_hours": avg_resolution,
            "satisfaction_score": min(5.0, satisfaction),
            "tickets_created": random.randint(0, 2)  # Agents may also create tickets
        })
    
    return history


def calculate_current_metrics(performance_history, agent):
    """Calculate current performance metrics from history"""
    
    # Last 7 days
    recent = performance_history[-7:]
    week_resolved = sum(day['tickets_resolved'] for day in recent)
    week_avg_time = sum(day['avg_resolution_time_hours'] for day in recent) / len(recent)
    week_satisfaction = sum(day['satisfaction_score'] for day in recent) / len(recent)
    
    # Last 30 days
    month = performance_history[-30:] if len(performance_history) >= 30 else performance_history
    month_resolved = sum(day['tickets_resolved'] for day in month)
    month_avg_time = sum(day['avg_resolution_time_hours'] for day in month) / len(month)
    month_satisfaction = sum(day['satisfaction_score'] for day in month) / len(month)
    
    # All time
    total_resolved = sum(day['tickets_resolved'] for day in performance_history)
    
    # Current active tickets (realistic distribution)
    tier_config = PERFORMANCE_TIERS[agent['tier']]
    min_active = tier_config['tickets_per_day'][0] // 2
    max_active = tier_config['tickets_per_day'][1]
    active_tickets = random.randint(min_active, max_active)
    
    return {
        "current_active_tickets": active_tickets,
        "resolved_today": recent[-1]['tickets_resolved'] if recent else 0,
        "resolved_this_week": week_resolved,
        "resolved_this_month": month_resolved,
        "total_resolved": total_resolved,
        "avg_resolution_time_hours": round(week_avg_time, 1),
        "avg_resolution_time_this_month": round(month_avg_time, 1),
        "satisfaction_score": round(week_satisfaction, 2),
        "satisfaction_score_this_month": round(month_satisfaction, 2),
        "performance_trend": "improving" if week_resolved > (month_resolved / 4) else 
                           "declining" if week_resolved < (month_resolved / 5) else "stable"
    }


def generate_workload_heatmap(agents, days=30):
    """Generate workload heatmap data"""
    
    heatmap = []
    current_date = datetime.now() - timedelta(days=days)
    
    for day in range(days + 1):  # Include today
        date = current_date + timedelta(days=day)
        
        daily_data = {
            "date": date.strftime("%Y-%m-%d"),
            "day_of_week": date.strftime("%A"),
            "agents": []
        }
        
        for agent in agents:
            # Simulate workload (varies by day and agent tier)
            tier_config = PERFORMANCE_TIERS[agent['tier']]
            base_tickets = random.randint(*tier_config['tickets_per_day'])
            
            # Reduce for weekends
            if date.weekday() >= 5:
                base_tickets = int(base_tickets * 0.3)
            
            # Calculate workload percentage (assuming 8 tickets = 100%)
            workload_percent = min(100, (base_tickets / 8) * 100)
            
            # Determine status
            if workload_percent < 70:
                status = "available"
                status_color = "#4caf50"
            elif workload_percent < 90:
                status = "busy"
                status_color = "#ff9800"
            else:
                status = "overloaded"
                status_color = "#f44336"
            
            daily_data["agents"].append({
                "agent_id": agent['agent_id'],
                "name": agent['name'],
                "tickets_count": base_tickets,
                "estimated_hours": base_tickets * random.uniform(2, 6),
                "workload_percent": round(workload_percent, 1),
                "status": status,
                "status_color": status_color
            })
        
        # Calculate daily summary
        total_tickets = sum(a['tickets_count'] for a in daily_data['agents'])
        avg_workload = sum(a['workload_percent'] for a in daily_data['agents']) / len(daily_data['agents'])
        
        daily_data["summary"] = {
            "total_tickets": total_tickets,
            "avg_workload_percent": round(avg_workload, 1),
            "available_agents": len([a for a in daily_data['agents'] if a['status'] == 'available']),
            "busy_agents": len([a for a in daily_data['agents'] if a['status'] == 'busy']),
            "overloaded_agents": len([a for a in daily_data['agents'] if a['status'] == 'overloaded'])
        }
        
        heatmap.append(daily_data)
    
    return heatmap


def generate_team_statistics(agents, performance_data):
    """Generate team-level statistics"""
    
    total_active_tickets = sum(metrics['current_active_tickets'] 
                               for metrics in performance_data.values())
    
    total_resolved_week = sum(metrics['resolved_this_week'] 
                             for metrics in performance_data.values())
    
    avg_satisfaction = sum(metrics['satisfaction_score'] 
                          for metrics in performance_data.values()) / len(agents)
    
    avg_resolution_time = sum(metrics['avg_resolution_time_hours'] 
                             for metrics in performance_data.values()) / len(agents)
    
    return {
        "team_size": len(agents),
        "active_agents": len([a for a in agents if a['status'] == 'active']),
        "total_active_tickets": total_active_tickets,
        "total_resolved_this_week": total_resolved_week,
        "team_avg_satisfaction": round(avg_satisfaction, 2),
        "team_avg_resolution_time": round(avg_resolution_time, 1),
        "high_performers": len([a for a in agents if a['tier'] == 'high']),
        "capacity_utilization": round((total_active_tickets / (len(agents) * 8)) * 100, 1)
    }


def main():
    """Main function to generate all infrastructure data"""
    
    print("Generating Infrastructure & Talent Management synthetic data...")
    
    # Generate agents across all tiers
    agents = []
    agent_id = 1
    
    for tier, config in PERFORMANCE_TIERS.items():
        for _ in range(config['count']):
            agent = generate_agent_profile(agent_id, tier)
            agents.append(agent)
            agent_id += 1
    
    print(f"✓ Generated {len(agents)} agent profiles")
    
    # Generate performance history for each agent
    performance_data = {}
    performance_history_data = {}
    
    for agent in agents:
        history = generate_performance_history(agent, days=90)
        metrics = calculate_current_metrics(history, agent)
        
        performance_data[agent['agent_id']] = metrics
        performance_history_data[agent['agent_id']] = history
    
    print(f"✓ Generated 90 days of performance history for {len(agents)} agents")
    
    # Generate workload heatmap
    workload_heatmap = generate_workload_heatmap(agents, days=30)
    print(f"✓ Generated 30 days of workload heatmap data")
    
    # Generate team statistics
    team_stats = generate_team_statistics(agents, performance_data)
    print(f"✓ Generated team statistics")
    
    # Save all data to JSON files
    output = {
        "agents": agents,
        "performance_metrics": performance_data,
        "performance_history": performance_history_data,
        "workload_heatmap": workload_heatmap,
        "team_statistics": team_stats,
        "generated_at": datetime.now().isoformat(),
        "data_period": {
            "performance_history_days": 90,
            "workload_heatmap_days": 30
        }
    }
    
    output_file = "infrastructure_data.json"
    with open(output_file, 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"\n✓ Infrastructure data saved to {output_file}")
    print(f"\nSummary:")
    print(f"  - Agents: {len(agents)}")
    print(f"    * High performers: {team_stats['high_performers']}")
    print(f"    * Average performers: {PERFORMANCE_TIERS['average']['count']}")
    print(f"    * New agents: {PERFORMANCE_TIERS['new']['count']}")
    print(f"  - Active tickets: {team_stats['total_active_tickets']}")
    print(f"  - Team capacity: {team_stats['capacity_utilization']}%")
    print(f"  - Team satisfaction: {team_stats['team_avg_satisfaction']}/5.0")
    print(f"  - Avg resolution time: {team_stats['team_avg_resolution_time']} hours")
    
    return output


if __name__ == "__main__":
    main()

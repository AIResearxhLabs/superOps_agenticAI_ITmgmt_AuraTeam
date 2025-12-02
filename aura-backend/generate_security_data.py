#!/usr/bin/env python3
"""
Generate synthetic data for Threat Intelligence module
Populates security incidents, security scores, and alert data
"""

import random
import json
from datetime import datetime, timedelta
from faker import Faker

fake = Faker()

# Security incident types with realistic distributions
INCIDENT_TYPES = {
    "Suspicious Email/Phishing": {"weight": 40, "severity_dist": {"low": 30, "medium": 50, "high": 15, "critical": 5}},
    "Unauthorized Access Attempt": {"weight": 20, "severity_dist": {"low": 10, "medium": 30, "high": 40, "critical": 20}},
    "Malware Detection": {"weight": 15, "severity_dist": {"low": 5, "medium": 25, "high": 50, "critical": 20}},
    "Policy Violation": {"weight": 10, "severity_dist": {"low": 50, "medium": 35, "high": 10, "critical": 5}},
    "Data Breach Suspicion": {"weight": 5, "severity_dist": {"low": 0, "medium": 10, "high": 40, "critical": 50}},
    "Suspicious Network Activity": {"weight": 5, "severity_dist": {"low": 15, "medium": 40, "high": 35, "critical": 10}},
    "Other": {"weight": 5, "severity_dist": {"low": 40, "medium": 40, "high": 15, "critical": 5}}
}

# Status progression based on severity
STATUS_PROGRESSION = {
    "critical": ["open", "investigating", "investigating", "resolved"],
    "high": ["open", "investigating", "resolved"],
    "medium": ["open", "investigating", "resolved"],
    "low": ["open", "resolved"]
}

# Security score categories
SECURITY_CATEGORIES = {
    "access_control": {"weight": 20, "base_score": (85, 95)},
    "threat_detection": {"weight": 20, "base_score": (70, 90)},
    "compliance": {"weight": 20, "base_score": (65, 85)},
    "data_protection": {"weight": 20, "base_score": (80, 95)},
    "monitoring": {"weight": 20, "base_score": (88, 98)}
}


def weighted_choice(choices_dict):
    """Select item based on weight distribution"""
    items = list(choices_dict.keys())
    weights = [choices_dict[item]["weight"] for item in items]
    return random.choices(items, weights=weights, k=1)[0]


def generate_incident(incident_id, days_ago):
    """Generate a realistic security incident"""
    
    incident_type = weighted_choice(INCIDENT_TYPES)
    type_config = INCIDENT_TYPES[incident_type]
    
    # Select severity based on type-specific distribution
    severity_choices = list(type_config["severity_dist"].keys())
    severity_weights = list(type_config["severity_dist"].values())
    severity = random.choices(severity_choices, weights=severity_weights, k=1)[0]
    
    # Generate timestamps
    created_at = datetime.now() - timedelta(days=days_ago, hours=random.randint(0, 23))
    
    # Determine status based on age and severity
    age_days = days_ago
    if age_days > 30:
        status = "resolved"
    elif age_days > 7:
        status = random.choice(["investigating", "resolved"])
    else:
        status = random.choice(STATUS_PROGRESSION[severity])
    
    resolved_at = None
    if status == "resolved":
        resolution_time = timedelta(hours=random.randint(2, 48) if severity in ["critical", "high"] 
                                    else random.randint(4, 120))
        resolved_at = created_at + resolution_time
    
    # Generate affected systems
    num_affected = random.randint(1, 5) if severity in ["critical", "high"] else random.randint(1, 2)
    affected_systems = [fake.hostname() for _ in range(num_affected)]
    
    # Generate affected users
    num_users = random.randint(1, 10) if severity == "critical" else random.randint(1, 3)
    affected_users = [fake.email() for _ in range(num_users)]
    
    # Generate description based on incident type
    descriptions = {
        "Suspicious Email/Phishing": [
            "Multiple users reported receiving suspicious emails claiming to be from IT department requesting password reset.",
            "Phishing attempt detected with spoofed sender address mimicking executive email.",
            "Email with malicious attachment identified by security filters.",
            "User clicked suspicious link in email, triggering security alert."
        ],
        "Unauthorized Access Attempt": [
            "Multiple failed login attempts detected from unusual geographic location.",
            "Brute force attack detected on VPN gateway.",
            "Unauthorized access attempt to administrative console from unknown IP.",
            "Suspicious authentication pattern detected for privileged account."
        ],
        "Malware Detection": [
            "Endpoint protection detected and quarantined ransomware on workstation.",
            "Trojan detected in downloaded file, automatically isolated.",
            "Suspicious process behavior detected, potentially malicious software.",
            "Network scan detected malware communication attempt to external server."
        ],
        "Policy Violation": [
            "User attempted to access restricted resource outside authorized hours.",
            "Unauthorized software installation detected on company device.",
            "Data transfer policy violation: large file upload to personal cloud storage.",
            "Encryption policy violation detected on USB storage device."
        ],
        "Data Breach Suspicion": [
            "Unusual data exfiltration pattern detected from database server.",
            "Sensitive data access from unauthorized location.",
            "Large volume of confidential data downloaded by user account.",
            "Suspicious database query patterns indicating potential data theft attempt."
        ],
        "Suspicious Network Activity": [
            "Unusual outbound network traffic to unknown external IP addresses.",
            "Port scanning activity detected from internal network.",
            "Abnormal bandwidth usage detected from specific workstation.",
            "DNS tunneling behavior detected, potential command and control activity."
        ],
        "Other": [
            "Security anomaly detected requiring investigation.",
            "Unusual system behavior reported by monitoring tools.",
            "Potential security incident flagged for review."
        ]
    }
    
    description = random.choice(descriptions.get(incident_type, descriptions["Other"]))
    
    incident = {
        "incident_id": f"SEC-{incident_id:05d}",
        "incident_type": incident_type,
        "severity": severity,
        "status": status,
        "title": f"{incident_type} - {created_at.strftime('%Y-%m-%d')}",
        "description": description,
        "affected_systems": affected_systems,
        "affected_users": affected_users,
        "reported_by": fake.email(),
        "assigned_to": "security_team",
        "created_at": created_at.isoformat(),
        "updated_at": (resolved_at if resolved_at else created_at + timedelta(hours=random.randint(1, 48))).isoformat(),
        "resolved_at": resolved_at.isoformat() if resolved_at else None,
        "resolution_notes": "Incident resolved. No further action required." if status == "resolved" else None,
        "tags": [incident_type.split('/')[0].lower(), severity],
        "ticket_id": f"TKT-{random.randint(1000, 9999)}" if status != "open" else None
    }
    
    return incident


def generate_security_score_history(days=90):
    """Generate daily security score snapshots with realistic trends"""
    
    history = []
    current_date = datetime.now() - timedelta(days=days)
    
    # Initialize category scores with base values
    category_scores = {}
    for category, config in SECURITY_CATEGORIES.items():
        base = random.randint(*config["base_score"])
        category_scores[category] = base
    
    for day in range(days + 1):  # Include today
        date = current_date + timedelta(days=day)
        
        # Add daily variations (-3 to +3 points)
        daily_scores = {}
        for category, score in category_scores.items():
            variation = random.randint(-3, 3)
            new_score = max(0, min(100, score + variation))
            daily_scores[category] = new_score
            category_scores[category] = new_score  # Update for next day
        
        # Calculate overall score (weighted average)
        overall = sum(daily_scores[cat] * SECURITY_CATEGORIES[cat]["weight"] / 100 
                     for cat in daily_scores)
        overall = round(overall, 1)
        
        # Determine issues count based on scores
        issues = {}
        for category, score in daily_scores.items():
            if score < 70:
                issues[category] = random.randint(8, 15)
            elif score < 80:
                issues[category] = random.randint(4, 8)
            elif score < 90:
                issues[category] = random.randint(1, 4)
            else:
                issues[category] = random.randint(0, 2)
        
        history.append({
            "date": date.strftime("%Y-%m-%d"),
            "overall_score": overall,
            "categories": {
                category: {
                    "score": score,
                    "status": "excellent" if score >= 90 else 
                            "good" if score >= 80 else 
                            "warning" if score >= 70 else "critical",
                    "issues": issues[category]
                }
                for category, score in daily_scores.items()
            }
        })
    
    return history


def generate_active_alerts(count=5):
    """Generate current active security alerts"""
    
    alert_types = [
        "Suspicious Login",
        "Failed Authentication",
        "Malware Activity",
        "Unusual Network Traffic",
        "Policy Violation",
        "Data Access Anomaly",
        "Privilege Escalation Attempt",
        "Configuration Change"
    ]
    
    alerts = []
    for i in range(count):
        alert_type = random.choice(alert_types)
        severity = random.choice(["low", "medium", "high", "critical"])
        
        # More recent alerts
        hours_ago = random.randint(1, 72)
        timestamp = datetime.now() - timedelta(hours=hours_ago)
        
        status = random.choice(["active", "investigating", "acknowledged"])
        
        alerts.append({
            "alert_id": f"ALT-{i+1:04d}",
            "type": alert_type,
            "severity": severity,
            "message": f"{alert_type} detected - requires attention",
            "source": random.choice(["IDS", "SIEM", "Endpoint Protection", "Network Monitor", "Access Control"]),
            "timestamp": timestamp.isoformat(),
            "status": status,
            "affected_resource": fake.hostname()
        })
    
    # Sort by timestamp (most recent first)
    alerts.sort(key=lambda x: x["timestamp"], reverse=True)
    
    return alerts


def generate_threat_intelligence():
    """Generate threat intelligence summary"""
    
    return {
        "active_threats": random.randint(2, 8),
        "blocked_attempts_today": random.randint(50, 200),
        "blocked_attempts_week": random.randint(300, 1500),
        "threats_mitigated_today": random.randint(5, 20),
        "threats_mitigated_week": random.randint(30, 150),
        "high_risk_assets": random.randint(1, 5),
        "vulnerabilities_found": random.randint(10, 50),
        "vulnerabilities_patched": random.randint(5, 40),
        "compliance_score": round(random.uniform(75, 95), 1),
        "last_scan": (datetime.now() - timedelta(hours=random.randint(1, 24))).isoformat()
    }


def main():
    """Main function to generate all security data"""
    
    print("Generating Threat Intelligence synthetic data...")
    
    # Generate security incidents (last 60 days)
    incidents = []
    incident_count = random.randint(20, 30)
    
    for i in range(1, incident_count + 1):
        days_ago = random.randint(0, 60)
        incident = generate_incident(i, days_ago)
        incidents.append(incident)
    
    # Sort by created_at (most recent first)
    incidents.sort(key=lambda x: x["created_at"], reverse=True)
    
    print(f"✓ Generated {len(incidents)} security incidents")
    
    # Generate security score history
    score_history = generate_security_score_history(days=90)
    current_score = score_history[-1]  # Most recent
    
    print(f"✓ Generated 90 days of security score history")
    
    # Generate active alerts
    active_alerts = generate_active_alerts(count=random.randint(3, 7))
    
    print(f"✓ Generated {len(active_alerts)} active security alerts")
    
    # Generate threat intelligence summary
    threat_intel = generate_threat_intelligence()
    
    print(f"✓ Generated threat intelligence summary")
    
    # Calculate summary statistics
    total_incidents = len(incidents)
    critical_count = len([i for i in incidents if i["severity"] == "critical"])
    high_count = len([i for i in incidents if i["severity"] == "high"])
    resolved_count = len([i for i in incidents if i["status"] == "resolved"])
    open_count = len([i for i in incidents if i["status"] == "open"])
    investigating_count = len([i for i in incidents if i["status"] == "investigating"])
    
    summary = {
        "total_incidents": total_incidents,
        "by_severity": {
            "critical": critical_count,
            "high": high_count,
            "medium": len([i for i in incidents if i["severity"] == "medium"]),
            "low": len([i for i in incidents if i["severity"] == "low"])
        },
        "by_status": {
            "open": open_count,
            "investigating": investigating_count,
            "resolved": resolved_count
        },
        "resolution_rate": round((resolved_count / total_incidents) * 100, 1) if total_incidents > 0 else 0,
        "avg_resolution_time_hours": round(random.uniform(12, 48), 1),
        "active_alerts_count": len(active_alerts)
    }
    
    # Save all data
    output = {
        "incidents": incidents,
        "current_security_score": current_score,
        "security_score_history": score_history,
        "active_alerts": active_alerts,
        "threat_intelligence": threat_intel,
        "summary": summary,
        "generated_at": datetime.now().isoformat(),
        "data_period": {
            "incidents_days": 60,
            "score_history_days": 90
        }
    }
    
    output_file = "security_data.json"
    with open(output_file, 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"\n✓ Security data saved to {output_file}")
    print(f"\nSummary:")
    print(f"  - Total incidents: {total_incidents}")
    print(f"    * Critical: {critical_count}")
    print(f"    * High: {high_count}")
    print(f"    * Open: {open_count}")
    print(f"    * Investigating: {investigating_count}")
    print(f"    * Resolved: {resolved_count}")
    print(f"  - Current security score: {current_score['overall_score']}/100")
    print(f"  - Active alerts: {len(active_alerts)}")
    print(f"  - Active threats: {threat_intel['active_threats']}")
    print(f"  - Resolution rate: {summary['resolution_rate']}%")
    
    return output


if __name__ == "__main__":
    main()

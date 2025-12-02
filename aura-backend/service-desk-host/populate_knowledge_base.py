#!/usr/bin/env python3
"""
Knowledge Base Population Script
Populates the MongoDB knowledge base with sample IT support articles
"""

import asyncio
import os
import sys
from datetime import datetime
from dotenv import load_dotenv

# Add the current directory to Python path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Load environment variables
load_dotenv()

from shared.utils.database import init_database_connections, db_manager, MongoRepository

# Sample Knowledge Base Articles
SAMPLE_ARTICLES = [
    {
        "title": "How to Reset Your Windows Password",
        "content": """
# Password Reset Guide

## For Windows 10/11 Users

### Method 1: Using Security Questions
1. On the login screen, click "Reset password"
2. Answer your security questions
3. Enter your new password twice
4. Click "Finish"

### Method 2: Using Another Admin Account
1. Log in with an administrator account
2. Go to Settings > Accounts > Family & other users
3. Select the user account
4. Click "Change password"
5. Enter the new password

### Method 3: Using Command Prompt (Admin Required)
1. Open Command Prompt as Administrator
2. Type: `net user [username] [newpassword]`
3. Press Enter
4. The password will be changed immediately

## Important Notes
- Passwords must be at least 8 characters long
- Include uppercase, lowercase, numbers, and special characters
- Don't use personal information in passwords
- Consider using a password manager

## Need Help?
If these methods don't work, contact IT support for assistance.
        """,
        "category": "Account Management",
        "tags": ["password", "reset", "windows", "login", "security"],
        "author": "IT Support Team"
    },
    {
        "title": "VPN Connection Setup Guide",
        "content": """
# VPN Setup Instructions

## Windows VPN Setup

### Step 1: Download VPN Client
1. Download the company VPN client from the IT portal
2. Run the installer as Administrator
3. Follow the installation wizard

### Step 2: Configure Connection
1. Open the VPN client
2. Click "Add New Connection"
3. Enter server details:
   - Server: vpn.company.com
   - Protocol: IKEv2
   - Authentication: Username/Password

### Step 3: Connect
1. Enter your company credentials
2. Click "Connect"
3. Wait for connection confirmation

## macOS VPN Setup

### Using Built-in VPN
1. Go to System Preferences > Network
2. Click "+" to add new service
3. Select "VPN" and "IKEv2"
4. Enter connection details
5. Click "Connect"

## Troubleshooting
- Check internet connection first
- Verify credentials are correct
- Try different server locations
- Contact IT if connection fails repeatedly

## Security Notes
- Always use VPN when working remotely
- Disconnect when not needed
- Report any connection issues immediately
        """,
        "category": "Network",
        "tags": ["vpn", "remote", "connection", "security", "setup"],
        "author": "Network Team"
    },
    {
        "title": "Email Configuration for Outlook",
        "content": """
# Outlook Email Setup

## Automatic Configuration (Recommended)

### For Office 365 Accounts
1. Open Outlook
2. Click "File" > "Add Account"
3. Enter your email address
4. Enter your password
5. Outlook will configure automatically

## Manual Configuration

### IMAP Settings
- **Incoming Server**: mail.company.com
- **Port**: 993
- **Encryption**: SSL/TLS
- **Outgoing Server**: smtp.company.com
- **Port**: 587
- **Encryption**: STARTTLS

### POP3 Settings (Not Recommended)
- **Incoming Server**: pop.company.com
- **Port**: 995
- **Encryption**: SSL/TLS

## Common Issues

### "Cannot Connect to Server"
1. Check internet connection
2. Verify server settings
3. Check firewall settings
4. Try different port numbers

### "Authentication Failed"
1. Verify username and password
2. Check if 2FA is enabled
3. Generate app-specific password if needed

### Emails Not Syncing
1. Check sync settings
2. Verify folder subscriptions
3. Clear Outlook cache
4. Restart Outlook

## Mobile Setup
Use the same IMAP settings for mobile devices.
Enable "Use SSL" for security.

## Support
Contact IT support if you continue experiencing issues.
        """,
        "category": "Email",
        "tags": ["outlook", "email", "configuration", "imap", "smtp"],
        "author": "IT Support Team"
    },
    {
        "title": "Printer Setup and Troubleshooting",
        "content": """
# Printer Setup Guide

## Adding a Network Printer

### Windows 10/11
1. Go to Settings > Devices > Printers & scanners
2. Click "Add a printer or scanner"
3. Select your printer from the list
4. Follow the setup wizard

### Manual IP Setup
1. Click "The printer that I want isn't listed"
2. Select "Add a printer using a TCP/IP address"
3. Enter printer IP address
4. Install appropriate drivers

## Common Printer Issues

### Printer Offline
1. Check power and network cables
2. Restart the printer
3. Remove and re-add printer in Windows
4. Update printer drivers

### Print Jobs Stuck in Queue
1. Open Control Panel > Devices and Printers
2. Right-click your printer
3. Select "See what's printing"
4. Cancel all documents
5. Restart Print Spooler service

### Poor Print Quality
1. Check ink/toner levels
2. Run printer cleaning cycle
3. Check paper type settings
4. Replace cartridges if needed

## Printer Locations
- **Main Office**: HP LaserJet Pro (IP: 192.168.1.100)
- **Conference Room**: Canon ImageClass (IP: 192.168.1.101)
- **Marketing Dept**: Epson EcoTank (IP: 192.168.1.102)

## Driver Downloads
Download latest drivers from manufacturer websites:
- HP: hp.com/support
- Canon: canon.com/support
- Epson: epson.com/support

## Need Help?
Submit a ticket if printer issues persist.
        """,
        "category": "Hardware",
        "tags": ["printer", "setup", "troubleshooting", "network", "drivers"],
        "author": "IT Support Team"
    },
    {
        "title": "Software Installation Requests",
        "content": """
# Software Installation Process

## Approved Software List
The following software can be installed without special approval:
- Microsoft Office Suite
- Adobe Acrobat Reader
- Google Chrome
- Mozilla Firefox
- 7-Zip
- Notepad++
- VLC Media Player
- Zoom
- Teams

## Request Process

### For Approved Software
1. Submit ticket with software name
2. Include business justification
3. IT will install within 24 hours

### For New Software
1. Submit detailed request including:
   - Software name and version
   - Business justification
   - Number of licenses needed
   - Budget information
2. Manager approval required
3. Security review (5-10 business days)
4. Procurement and installation

## Self-Service Options
Some software can be installed via Company Portal:
1. Open Company Portal app
2. Browse available software
3. Click "Install" for desired applications

## Security Requirements
All software must:
- Be from trusted vendors
- Pass security scanning
- Have current support contracts
- Comply with licensing agreements

## Prohibited Software
- Peer-to-peer file sharing applications
- Cryptocurrency mining software
- Unlicensed or cracked software
- Software with known security vulnerabilities

## Installation Guidelines
- Only install software from official sources
- Keep software updated
- Report any suspicious behavior
- Don't share license keys

## Need Custom Software?
Contact IT for evaluation of specialized business applications.
        """,
        "category": "Software",
        "tags": ["software", "installation", "approval", "security", "licensing"],
        "author": "IT Security Team"
    },
    {
        "title": "Wi-Fi Connection Troubleshooting",
        "content": """
# Wi-Fi Connection Guide

## Company Wi-Fi Networks
- **AuraSecure**: Main corporate network (WPA3)
- **AuraGuest**: Guest network (Open with portal)
- **AuraIoT**: Device network (Restricted)

## Connection Steps

### Windows
1. Click Wi-Fi icon in system tray
2. Select "AuraSecure"
3. Enter your domain credentials
4. Check "Connect automatically"

### macOS
1. Click Wi-Fi icon in menu bar
2. Select "AuraSecure"
3. Enter username and password
4. Click "Join"

### Mobile Devices
1. Go to Wi-Fi settings
2. Select "AuraSecure"
3. Choose "WPA2/WPA3 Enterprise"
4. Enter domain credentials

## Troubleshooting Steps

### Cannot See Network
1. Check if Wi-Fi is enabled
2. Refresh available networks
3. Move closer to access point
4. Restart Wi-Fi adapter

### Cannot Connect
1. Verify credentials are correct
2. Forget and reconnect to network
3. Check for MAC address filtering
4. Contact IT for account verification

### Slow Connection
1. Check signal strength
2. Move to different location
3. Restart device
4. Run speed test
5. Report persistent issues

### Frequent Disconnections
1. Update Wi-Fi drivers
2. Disable power management for Wi-Fi
3. Check for interference
4. Reset network settings

## Guest Access
Visitors can use "AuraGuest":
1. Connect to AuraGuest network
2. Open web browser
3. Complete registration form
4. Access valid for 24 hours

## Security Notes
- Never share Wi-Fi passwords
- Use VPN for sensitive data
- Report suspicious network activity
- Keep devices updated

## Coverage Areas
Wi-Fi is available in:
- All office floors
- Conference rooms
- Break areas
- Lobby and reception

## Support
Contact IT for persistent connectivity issues.
        """,
        "category": "Network",
        "tags": ["wifi", "wireless", "connection", "troubleshooting", "network"],
        "author": "Network Team"
    },
    {
        "title": "Multi-Factor Authentication (MFA) Setup",
        "content": """
# Multi-Factor Authentication Setup

## Why MFA is Required
MFA adds an extra layer of security to protect company data and systems from unauthorized access.

## Supported MFA Methods
1. **Microsoft Authenticator** (Recommended)
2. **SMS Text Messages**
3. **Phone Calls**
4. **Hardware Tokens** (For high-privilege accounts)

## Setup Instructions

### Microsoft Authenticator App
1. Download Microsoft Authenticator from app store
2. Go to https://aka.ms/mfasetup
3. Sign in with your company account
4. Click "Set up Authenticator app"
5. Scan QR code with the app
6. Enter verification code to complete setup

### SMS Setup
1. Go to https://aka.ms/mfasetup
2. Select "Phone" as authentication method
3. Enter your mobile phone number
4. Choose "Send me a code by text message"
5. Enter received code to verify

### Phone Call Setup
1. Go to https://aka.ms/mfasetup
2. Select "Phone" as authentication method
3. Enter your phone number
4. Choose "Call me"
5. Answer call and follow prompts

## Using MFA

### Daily Login
1. Enter username and password
2. Approve notification in Authenticator app
   OR
   Enter code from SMS/app

### Backup Codes
- Generate backup codes for emergencies
- Store codes in secure location
- Each code can only be used once

## Troubleshooting

### App Not Working
1. Check internet connection
2. Sync time on device
3. Reinstall Authenticator app
4. Contact IT for reset

### Not Receiving SMS
1. Check phone signal
2. Verify phone number is correct
3. Try phone call method instead
4. Contact IT support

### Lost Device
1. Contact IT immediately
2. Provide alternative verification
3. IT will reset MFA settings
4. Set up MFA on new device

## Best Practices
- Keep backup authentication methods updated
- Don't share authentication codes
- Report lost devices immediately
- Use Authenticator app when possible

## Getting Help
Contact IT support for MFA issues or questions.
        """,
        "category": "Security",
        "tags": ["mfa", "authentication", "security", "microsoft", "2fa"],
        "author": "IT Security Team"
    },
    {
        "title": "File Sharing and OneDrive Usage",
        "content": """
# File Sharing Guide

## OneDrive for Business

### Accessing OneDrive
1. Go to office.com
2. Sign in with company credentials
3. Click OneDrive icon
   OR
4. Use OneDrive desktop app

### Syncing Files
1. Install OneDrive desktop client
2. Sign in with company account
3. Choose folders to sync
4. Files sync automatically

### Sharing Files

#### Internal Sharing
1. Right-click file in OneDrive
2. Select "Share"
3. Enter colleague's email
4. Set permissions (View/Edit)
5. Click "Send"

#### External Sharing
1. Right-click file
2. Select "Share"
3. Click "Anyone with the link"
4. Set expiration date
5. Choose view/edit permissions

## SharePoint Document Libraries

### Accessing Team Sites
1. Go to office.com
2. Click SharePoint
3. Select your team site
4. Navigate to Documents library

### Version Control
- SharePoint automatically saves versions
- View version history by right-clicking file
- Restore previous versions if needed
- Check out files for exclusive editing

## File Sharing Best Practices

### Security Guidelines
- Only share with necessary people
- Set expiration dates for external links
- Use "View only" when editing isn't needed
- Regularly review shared files

### Organization Tips
- Use descriptive file names
- Create folder structures
- Tag files with metadata
- Delete outdated files regularly

## Large File Transfers

### For Files Over 100MB
1. Upload to OneDrive
2. Share link instead of email attachment
3. Use SharePoint for team collaboration
4. Consider file compression

### Alternative Methods
- **Secure File Transfer**: Use company FTP
- **External Partners**: Use approved file sharing services
- **Temporary Sharing**: Use company-approved tools

## Collaboration Features

### Co-authoring
- Multiple users can edit simultaneously
- Real-time changes visible to all
- Comments and suggestions available
- Version conflicts automatically resolved

### Teams Integration
- Access files directly in Teams
- Edit files without leaving Teams
- Share files in chat or channels

## Storage Limits
- OneDrive: 1TB per user
- SharePoint: 25TB per site
- Contact IT for additional storage

## Troubleshooting

### Sync Issues
1. Check internet connection
2. Restart OneDrive client
3. Clear OneDrive cache
4. Reset OneDrive if needed

### Access Denied
1. Check sharing permissions
2. Verify you're signed in correctly
3. Contact file owner for access
4. Submit IT ticket if persistent

## Support
Contact IT for file sharing issues or questions.
        """,
        "category": "Software",
        "tags": ["onedrive", "sharepoint", "file sharing", "collaboration", "cloud"],
        "author": "IT Support Team"
    },
    {
        "title": "Advanced Password Recovery Methods",
        "content": """
# Advanced Password Recovery Guide

## When Standard Reset Methods Don't Work

### Method 1: Using Password Reset Disk
1. Insert your password reset disk
2. On the login screen, click "Reset password"
3. Follow the Password Reset Wizard
4. Create a new password

### Method 2: Safe Mode Administrator Account
1. Restart computer and press F8 during boot
2. Select "Safe Mode"
3. Log in as Administrator (usually no password)
4. Go to Control Panel > User Accounts
5. Reset the user password

### Method 3: Command Prompt Recovery
1. Boot from Windows installation media
2. Press Shift+F10 to open Command Prompt
3. Navigate to System32 folder
4. Replace sethc.exe with cmd.exe
5. Restart and use Sticky Keys shortcut at login

### Method 4: Third-Party Tools
- Ophcrack (for older systems)
- Kon-Boot (commercial solution)
- Trinity Rescue Kit (Linux-based)

## Prevention Tips
- Create a password reset disk when you first set up your account
- Use a password manager
- Set up security questions
- Enable two-factor authentication

## When to Contact IT
- If you're on a domain-joined computer
- If BitLocker encryption is enabled
- If you need to recover encrypted files
- If multiple failed attempts have locked the account
        """,
        "category": "Account Management",
        "tags": ["password", "recovery", "advanced", "troubleshooting", "security"],
        "author": "IT Security Team"
    },
    {
        "title": "VPN Troubleshooting Checklist",
        "content": """
# VPN Connection Troubleshooting

## Quick Diagnostic Steps

### Step 1: Basic Connectivity Check
1. Test internet connection without VPN
2. Try connecting to a different VPN server
3. Restart your network adapter
4. Flush DNS cache: `ipconfig /flushdns`

### Step 2: VPN Client Issues
1. Update VPN client to latest version
2. Run VPN client as administrator
3. Check for conflicting software (antivirus, firewall)
4. Clear VPN client cache and logs

### Step 3: Network Configuration
1. Check if your ISP blocks VPN traffic
2. Try different VPN protocols (OpenVPN, IKEv2, WireGuard)
3. Change VPN port numbers
4. Disable IPv6 temporarily

### Step 4: Firewall and Antivirus
1. Add VPN client to firewall exceptions
2. Temporarily disable antivirus
3. Check Windows Defender settings
4. Verify corporate firewall rules

## Common Error Messages

### "Connection Timeout"
- Check internet connection
- Try different server location
- Verify credentials
- Check firewall settings

### "Authentication Failed"
- Verify username and password
- Check if account is active
- Try resetting password
- Contact IT for account status

### "DNS Resolution Failed"
- Change DNS servers (8.8.8.8, 1.1.1.1)
- Flush DNS cache
- Restart network adapter
- Check DNS leak protection

## Advanced Troubleshooting
- Use network diagnostic tools (ping, tracert, nslookup)
- Check VPN logs for error details
- Test with different devices
- Monitor network traffic with Wireshark

## When to Escalate
- Persistent connection failures after trying all steps
- Suspected network infrastructure issues
- Need for alternative VPN solutions
- Security concerns or policy violations
        """,
        "category": "Network",
        "tags": ["vpn", "troubleshooting", "connectivity", "network", "remote"],
        "author": "Network Team"
    },
    {
        "title": "Email Synchronization Best Practices",
        "content": """
# Email Synchronization Issues Resolution

## Common Sync Problems

### Emails Not Downloading
1. Check internet connection stability
2. Verify account settings (IMAP/POP3)
3. Check server status and maintenance windows
4. Clear Outlook cache and restart

### Sent Items Not Syncing
1. Enable "Save sent items on server"
2. Check SMTP settings
3. Verify folder mapping in account settings
4. Rebuild Outlook profile if needed

### Calendar/Contacts Sync Issues
1. Enable Exchange ActiveSync
2. Check sync frequency settings
3. Verify permissions on shared calendars
4. Clear mobile device cache

## Optimization Tips

### For Better Performance
- Use IMAP instead of POP3 for multiple devices
- Set appropriate sync intervals (15-30 minutes)
- Limit sync to recent emails (30-90 days)
- Use server-side rules instead of client-side

### For Mobile Devices
- Enable push notifications for important folders only
- Sync headers only for large mailboxes
- Use focused inbox to reduce data usage
- Set up VIP lists for priority contacts

### For Shared Mailboxes
- Configure proper permissions (Full Access, Send As)
- Use automapping for seamless access
- Set up delegation instead of shared passwords
- Monitor mailbox size limits

## Troubleshooting Steps

### Outlook Desktop Issues
1. Run Outlook in Safe Mode
2. Repair Office installation
3. Create new Outlook profile
4. Check for add-in conflicts

### Mobile App Problems
1. Remove and re-add account
2. Update app to latest version
3. Check device storage space
4. Verify corporate policy compliance

### Web Access (OWA) Issues
1. Clear browser cache and cookies
2. Try different browser or incognito mode
3. Disable browser extensions
4. Check for proxy settings

## Prevention Strategies
- Regular mailbox cleanup and archiving
- Use rules to organize emails automatically
- Monitor mailbox size limits
- Keep software updated
- Train users on best practices

## When to Contact IT
- Server-side configuration changes needed
- Mailbox migration or setup
- Exchange server issues
- Policy or security concerns
        """,
        "category": "Email",
        "tags": ["email", "synchronization", "outlook", "exchange", "mobile"],
        "author": "IT Support Team"
    },
    {
        "title": "Account Lockout and Security Policies",
        "content": """
# Account Lockout Resolution Guide

## Understanding Account Lockouts

### Why Accounts Get Locked
- Multiple failed login attempts (typically 5-10 attempts)
- Expired passwords not updated
- Cached credentials in applications
- Compromised account security measures
- Automatic security policy enforcement

## Immediate Steps When Locked Out

### Self-Service Options
1. Wait 30 minutes for automatic unlock (if policy allows)
2. Use self-service password reset portal
3. Call IT Help Desk for immediate unlock
4. Verify you're using correct credentials

### Common Causes to Check
- Saved passwords in browsers or apps
- Mobile devices with old passwords
- Mapped network drives with cached credentials
- Third-party applications (email clients, cloud storage)

## Security Policy Guidelines

### Password Requirements
- Minimum 12 characters (complex mode)
- Must include: uppercase, lowercase, numbers, special characters
- Cannot reuse last 12 passwords
- Expires every 90 days
- Cannot contain username or common words

### Failed Login Attempts
- **Threshold**: 5 failed attempts
- **Lockout Duration**: 30 minutes
- **Reset**: Automatically after duration or by IT
- **Warning**: 3 failed attempts triggers notification

## Preventing Future Lockouts

### Best Practices
1. Update password everywhere after reset
2. Remove saved passwords from browsers
3. Disconnect mapped drives before password change
4. Update mobile devices immediately
5. Use password manager for security

### Applications to Update
- Email clients (Outlook, mobile mail)
- VPN connections
- Cloud storage (OneDrive, SharePoint)
- Collaboration tools (Teams, Slack)
- Remote desktop connections

## Troubleshooting Persistent Lockouts

### Finding the Source
1. Check Windows Event Viewer (Security logs)
2. Review recent login attempts
3. Identify which device/application is causing lockouts
4. Disable automatic reconnection temporarily

### Advanced Solutions
1. Clear credential cache: `cmdkey /list` and delete entries
2. Reset network credentials in Control Panel
3. Remove and re-add network printers
4. Update all service accounts if applicable

## Security Alerts

### When to Contact Security Team
- Lockouts when you haven't attempted login
- Suspicious account activity notifications
- Multiple lockouts in short timeframe
- Lockouts from unfamiliar locations
- Account showing unusual access patterns

## Account Types and Policies

### Standard User Accounts
- 30-minute lockout duration
- 5 failed attempt threshold
- Self-service reset available

### Privileged/Admin Accounts
- Stricter security policies
- Immediate IT involvement required
- No self-service options
- Enhanced monitoring and logging

## Emergency Access

### Critical Situations
1. Contact IT Help Desk immediately
2. Provide alternate contact verification
3. Manager approval may be required
4. Temporary credentials may be issued
5. Full security review post-incident

## Compliance and Reporting
- All lockouts are logged for security audit
- Repeated lockouts trigger security review
- Report suspicious activity immediately
- Comply with security training requirements

## Support Resources
- IT Help Desk: Available 24/7
- Self-Service Portal: https://accounts.company.com
- Security Team: security@company.com
        """,
        "category": "Account Management",
        "tags": ["account", "lockout", "security", "password", "policy", "compliance"],
        "author": "IT Security Team"
    },
    {
        "title": "Email Spam and Phishing Protection",
        "content": """
# Email Security and Phishing Prevention

## Identifying Phishing Emails

### Common Red Flags
- Urgent or threatening language
- Requests for sensitive information
- Suspicious sender addresses
- Generic greetings ("Dear Customer")
- Spelling and grammar errors
- Unexpected attachments or links
- Mismatched URLs (hover to check)

### Types of Phishing Attacks

#### Spear Phishing
- Targeted attacks on specific individuals
- Personalized with company/personal information
- Often impersonates known contacts or executives

#### Whaling
- Targets high-level executives
- Sophisticated social engineering
- Significant financial or data theft potential

#### Clone Phishing
- Duplicates legitimate emails
- Replaces links/attachments with malicious ones
- Appears to come from trusted source

## What to Do If You Receive Phishing

### Immediate Actions
1. **DO NOT** click any links or attachments
2. **DO NOT** reply or provide information
3. Report the email to security@company.com
4. Use "Report Phishing" button in Outlook
5. Delete the email after reporting

### If You Clicked a Link
1. Disconnect from network immediately
2. Contact IT Security right away
3. Do not attempt to "undo" actions
4. Change passwords as directed by IT
5. Monitor accounts for suspicious activity

### If You Provided Information
1. Contact IT Security immediately (CRITICAL)
2. Change all passwords instantly
3. Monitor financial accounts closely
4. Enable MFA on all accounts
5. File internal incident report

## Email Filtering and Protection

### Company Anti-Spam Features
- Real-time threat detection
- Automatic quarantine of suspicious emails
- Link and attachment scanning
- Sender verification (SPF, DKIM, DMARC)
- Machine learning threat analysis

### Managing Your Spam Filter

#### Checking Quarantine
1. Go to https://protection.company.com
2. Review quarantined messages
3. Release legitimate emails if needed
4. Report false positives

#### Safe Senders List
1. Open Outlook Settings
2. Go to Mail > Junk Email
3. Add trusted domains/addresses
4. Review list quarterly

#### Block Senders
1. Right-click suspicious email
2. Select "Block Sender"
3. Report to IT if persistent
4. Never engage with spammer

## Best Practices for Email Security

### Verify Before You Trust
- Check sender's full email address
- Verify unexpected requests through alternative channels
- Call the person directly for sensitive requests
- Don't trust caller ID or email display names

### Safe Link Practices
1. Hover over links to preview URL
2. Type addresses manually for banking/sensitive sites
3. Look for HTTPS and valid certificates
4. Be wary of shortened URLs
5. Use link scanning tools when uncertain

### Attachment Safety
- Only open expected attachments
- Scan with antivirus before opening
- Be cautious of executable files (.exe, .bat, .cmd)
- Watch for double extensions (.pdf.exe)
- Verify with sender if unexpected

## Common Phishing Scenarios

### "Account Verification Required"
- Claims account will be suspended
- Requests password or personal info
- Creates sense of urgency
- **Action**: Contact IT directly to verify

### "Package Delivery Notification"
- Fake shipping notifications
- Contains tracking link or attachment
- Often targets employees expecting deliveries
- **Action**: Check tracking directly on shipper's website

### "IT Department Request"
- Impersonates IT support
- Requests credentials for "system maintenance"
- May ask for remote access
- **Action**: Contact IT through official channels

### "Executive Request"
- Appears from CEO/Manager
- Urgent financial request or wire transfer
- Unusual timing or request method
- **Action**: Verify through phone call or in-person

## Reporting and Response

### How to Report
1. Forward suspicious email to: phishing@company.com
2. Use Outlook's "Report Phishing" button
3. Include full email headers
4. Do not modify the original email
5. Await confirmation from security team

### After Reporting
- Security team will analyze threat
- You'll receive feedback on the report
- Protections will be updated if needed
- Company-wide alert may be issued
- Training updates may be provided

## Training and Awareness

### Regular Security Training
- Quarterly phishing simulation tests
- Monthly security awareness newsletters
- Annual comprehensive security training
- Ad-hoc alerts for emerging threats

### Self-Assessment
- Take periodic phishing quizzes
- Review security awareness portal
- Attend optional security workshops
- Stay informed about current threats

## Mobile Email Security

### Additional Mobile Risks
- Smaller screens make verification harder
- Limited security indicators visible
- Auto-download of images/attachments
- Multiple email accounts on one device

### Mobile Best Practices
1. Don't click links in mobile emails when possible
2. Use official apps only
3. Keep apps and OS updated
4. Enable device encryption
5. Use strong device passwords/biometrics

## Support and Resources
- Security Awareness Portal: https://security.company.com
- Report Phishing: phishing@company.com
- IT Security Team: security@company.com
- Emergency Security Hotline: Available 24/7
        """,
        "category": "Security",
        "tags": ["email", "phishing", "security", "spam", "threat", "awareness"],
        "author": "IT Security Team"
    },
    {
        "title": "Hardware Request and Replacement Process",
        "content": """
# Hardware Request and Replacement Guide

## New Equipment Requests

### Eligibility for New Hardware
- New employees (onboarding)
- Role changes requiring different equipment
- Project-specific needs
- Equipment at end-of-life (3-4 years)
- Performance issues affecting productivity

### Standard Equipment Packages

#### Developer Package
- High-performance laptop (32GB RAM)
- Dual 27" monitors
- Mechanical keyboard
- Ergonomic mouse
- Laptop stand and docking station

#### Office Worker Package
- Standard laptop (16GB RAM)
- Single 24" monitor
- Standard keyboard and mouse
- Basic accessories

#### Executive Package
- Premium laptop (16GB RAM)
- 27" monitor
- Premium peripherals
- Mobile accessories (charger, case)
- Conference room equipment access

## Request Process

### Step 1: Submit Request
1. Open IT Service Portal
2. Select "Hardware Request"
3. Choose equipment category
4. Provide business justification
5. Include manager approval

### Step 2: Approval Workflow
- **Standard Requests**: IT Manager approval (1-2 days)
- **High-Value Items**: Department VP approval (3-5 days)
- **Specialized Equipment**: Additional technical review

### Step 3: Procurement
- In-stock items: 1-3 business days
- Special orders: 1-2 weeks
- Custom builds: 2-4 weeks
- International shipping: 3-6 weeks

### Step 4: Delivery and Setup
- Self-service pickup from IT
- Desk delivery for executives
- White-glove setup available
- Remote setup assistance provided

## Equipment Replacement

### When to Request Replacement

#### Performance Issues
- Frequent crashes or freezes
- Extremely slow performance
- Failed diagnostics
- Cannot run required software

#### Physical Damage
- Cracked screens
- Liquid damage
- Keyboard/trackpad failure
- Port damage
- Battery issues (won't hold charge)

#### End of Life
- 4+ years old
- No longer supported by manufacturer
- Cannot upgrade to required OS
- Repair costs exceed replacement value

### Replacement Process
1. Document issue thoroughly
2. Submit repair ticket first
3. IT evaluates repair vs. replace
4. Backup your data
5. Receive replacement equipment
6. Return old equipment

## Temporary Equipment Loans

### Loaner Laptops
- Available while yours is being repaired
- Standard configuration only
- Must sign loan agreement
- Return within 3 days of resolution

### Travel Equipment
- Lightweight laptops for travel
- International power adapters
- Mobile hotspots
- Available 2 weeks in advance

### Event Equipment
- Presentation equipment
- Demo devices
- Conference equipment
- Reserve at least 1 week ahead

## Peripherals and Accessories

### Available Without Approval
- Standard mouse and keyboard
- Monitor cables and adapters
- Headsets for video calls
- Webcam covers
- Cable management accessories

### Requires Approval
- External hard drives
- USB hubs and docks
- Premium headphones
- Ergonomic equipment
- Specialty adapters

### Ergonomic Equipment
- Ergonomic assessment required
- Standing desk converters
- Ergonomic keyboards and mice
- Monitor arms
- Footrests and cushions

## Equipment Return Process

### When Leaving Company
1. Receive return checklist from HR
2. Backup personal data (if allowed)
3. Remove personal information
4. Return all company equipment
5. Obtain return receipt

### Equipment to Return
- Laptop and charger
- Monitors and cables
- Keyboards and mice
- Mobile devices
- Access badges and keys
- Any other company property

### Data Wiping
- IT will securely wipe all devices
- Data cannot be recovered after wipe
- Personal files will be permanently deleted
- Ensure you have backups before returning

## Asset Management

### Equipment Tracking
- All equipment has asset tags
- Never remove or damage asset tags
- Report missing tags immediately
- Equipment tracked in CMDB system

### Your Responsibilities
- Keep equipment secure
- Report theft immediately
- Don't modify hardware without approval
- Use equipment for business purposes only
- Maintain equipment in good condition

### Relocation
- Notify IT before moving offices
- Equipment must be tracked
- Some equipment may need reconfiguration
- Allow 3-5 days for moves

## Lost or Stolen Equipment

### Immediate Actions (CRITICAL)
1. Report to IT Security immediately
2. File police report if stolen
3. Provide incident details
4. Remote wipe will be initiated
5. Change all passwords

### Replacement After Loss
- Investigation required
- Police report may be needed
- Replacement timeline varies
- Cost recovery may apply
- Security review conducted

## Warranty and Repairs

### Manufacturer Warranty
- 3-year warranty on most equipment
- Covers manufacturing defects
- Does not cover accidental damage
- Extended warranty available

### Out-of-Warranty Repairs
- Cost evaluation by IT
- May require approval
- Consider replacement if cost high
- User error damage may be charged

## BYOD (Bring Your Own Device)

### Company Policy
- BYOD allowed for specific roles
- Must meet security requirements
- IT support limited
- Company data must be segregated

### Requirements
- Modern OS (within 2 versions)
- Antivirus installed
- Encrypted storage
- MDM enrollment
- Passcode/biometric required

## Sustainability and Recycling

### Equipment Disposal
- All equipment recycled responsibly
- Certified e-waste recycling
- Data destruction certified
- Environmental compliance

### Equipment Donation
- Old but functional equipment donated
- Partnered with local schools
- Community organizations
- Refurbishment programs

## Support and Contacts
- Hardware Requests: hardware@company.com
- IT Help Desk: 24/7 support available
- Emergency Device Loss: security@company.com
- Asset Management: assets@company.com
        """,
        "category": "Hardware",
        "tags": ["hardware", "equipment", "request", "replacement", "laptop", "peripherals"],
        "author": "IT Support Team"
    },
    {
        "title": "Cloud Storage and Backup Best Practices",
        "content": """
# Cloud Storage and Backup Guide

## Company Cloud Storage Solutions

### OneDrive for Business
- **Storage**: 1TB per user
- **Purpose**: Personal work files
- **Sync**: Automatic with desktop client
- **Access**: Web, desktop, mobile
- **Retention**: 93 days in recycle bin

### SharePoint Online
- **Storage**: 25TB per site collection
- **Purpose**: Team collaboration
- **Features**: Version control, permissions
- **Integration**: Teams, Office apps
- **Retention**: Custom retention policies

### Teams Files
- **Backend**: SharePoint storage
- **Purpose**: Channel/chat file sharing
- **Access**: Teams app, SharePoint
- **Organization**: By team/channel
- **Collaboration**: Real-time co-authoring

## File Organization Best Practices

### Folder Structure Guidelines
- Use clear, descriptive names
- Create logical hierarchies
- Limit nesting to 3-4 levels
- Use consistent naming conventions
- Include dates for time-sensitive files

### Naming Conventions
```
[Project]_[Document Type]_[Version]_[Date]
Example: AuraProject_Requirements_v2_2024-11-23
```

### What to Store Where

#### OneDrive (Personal)
- Draft documents
- Personal work files
- Files you own
- Templates
- Reference materials

#### SharePoint/Teams (Shared)
- Team projects
- Shared documentation
- Collaborative workspaces
- Department resources
- Published/approved documents

## Data Backup Strategy

### 3-2-1 Backup Rule
- **3** copies of data
- **2** different storage types
- **1** copy off-site

### Automatic Backups
- OneDrive: Continuous sync
- SharePoint: Built-in versioning
- Email: Daily backups
- Databases: Real-time replication

### Manual Backup Recommendations
- Critical project files: Weekly
- Important documents: Monthly
- Archive data: Quarterly
- Personal data: User responsibility

## File Recovery Options

### OneDrive Recovery
1. Go to OneDrive recycle bin
2. Files kept for 93 days
3. Restore to original location
4. Contact IT if deleted permanently

### SharePoint Version History
1. Right-click file > Version History
2. View all previous versions
3. Restore or download old version
4. Major versions kept indefinitely

### Deleted Item Recovery
- **First-stage**: User recycle bin (93 days)
- **Second-stage**: Site collection recycle bin (93 days)
- **Beyond retention**: Contact IT for backup restore
- **Permanent deletion**: After 186 days total

## Sharing and Permissions

### Internal Sharing
- Share with specific people
- Set view or edit permissions
- Set expiration dates if needed
- Monitor sharing regularly

### External Sharing
- Requires business justification
- Limited to approved partners
- Automatic expiration (30 days)
- Extra security measures applied
- Audited and logged

### Permission Levels

#### Read
- View files only
- Download copies
- Cannot make changes
- Ideal for reference materials

#### Edit
- Modify files
- Delete files
- Share with others
- Full collaboration access

#### Owner
- Full control
- Manage permissions
- Delete permanently
- Configure settings

## Sync Settings and Performance

### Optimizing OneDrive Sync
- Select folders to sync
- Use Files On-Demand
- Limit bandwidth if needed
- Sync during off-hours
- Pause sync when needed

### Files On-Demand
- Cloud-only: No local storage used
- Locally available: Always on device
- Free up space automatically
- Download on-access

### Sync Troubleshooting
1. Check internet connection
2. Verify storage space
3. Restart OneDrive client
4. Reset sync if needed
5. Contact IT for persistent issues

## Storage Quota Management

### Monitoring Usage
- Check OneDrive storage meter
- Review SharePoint site usage
- Clean up unnecessary files
- Archive old projects
- Compress large files when appropriate

### Requesting Additional Storage
- Submit justification to IT
- Explain business need
- Provide usage statistics
- Clean up existing files first
- Alternative solutions may be offered

## Mobile Access

### Mobile Apps
- OneDrive mobile app
- SharePoint mobile app
- Teams mobile app
- Office mobile apps
- Offline access available

### Mobile Best Practices
- Enable PIN/biometric protection
- Download important files offline
- Use Wi-Fi for large uploads
- Clear cache periodically
- Report lost devices immediately

## Compliance and Security

### Data Classification
- **Public**: Can be shared freely
- **Internal**: Company employees only
- **Confidential**: Limited access
- **Restricted**: Highly sensitive

### Retention Policies
- Email: 7 years
- Financial records: 10 years
- HR records: 7 years after termination
- General business: 3 years
- IT logs: 1 year

### Legal Hold
- Preserves data for litigation
- Prevents deletion
- Managed by legal team
- User cannot override
- Contact legal for questions

## Advanced Features

### Version Control
- Track all changes
- See who made changes
- Restore previous versions
- Compare versions
- Major/minor versions

### Co-Authoring
- Multiple users edit simultaneously
- See changes in real-time
- Automatic conflict resolution
- Works in Office apps
- Available on web and desktop

### Metadata and Search
- Add custom properties
- Tag files for easy finding
- Search by content
- Filter by metadata
- Save search queries

## Troubleshooting Common Issues

### Sync Conflicts
- Review conflict files
- Choose correct version
- Merge changes if needed
- Prevent with co-authoring
- Contact IT for help

### Access Denied
- Check sharing permissions
- Verify account access
- Request access from owner
- Check group membership
- Contact IT if persistent

### Missing Files
- Check recycle bin
- Review version history
- Verify sync status
- Check other devices
- Contact IT for backup restore

## Best Practices Summary

### Do's
✓ Organize files logically
✓ Use descriptive names
✓ Enable auto-save
✓ Check sync status regularly
✓ Clean up old files
✓ Use version control
✓ Set appropriate permissions

### Don'ts
✗ Store personal files on company storage
✗ Share sensitive data externally without approval
✗ Ignore sync errors
✗ Bypass security measures
✗ Delete files without consideration
✗ Use consumer cloud services for company data

## Support Resources
- OneDrive Help: https://onedrive.company.com/help
- SharePoint Help: https://sharepoint.company.com/help
- IT Help Desk: Available 24/7
- Storage Requests: storage@company.com
- Data Recovery: backup@company.com
        """,
        "category": "Software",
        "tags": ["cloud", "storage", "backup", "onedrive", "sharepoint", "data", "recovery"],
        "author": "IT Support Team"
    },
    {
        "title": "Data Loss Prevention and Compliance",
        "content": """
# Data Loss Prevention (DLP) Policies

## Understanding DLP

### What is DLP?
Data Loss Prevention (DLP) is a security strategy that detects and prevents sensitive data from leaving the organization through unauthorized channels.

### Why DLP Matters
- Protects sensitive company information
- Ensures regulatory compliance
- Prevents data breaches
- Maintains customer trust
- Reduces legal liability

## Types of Sensitive Data

### Personal Identifiable Information (PII)
- Social Security Numbers
- Driver's License Numbers
- Passport Numbers
- Credit Card Information
- Bank Account Numbers
- Employee IDs
- Health Records

### Business Confidential
- Trade secrets
- Financial reports
- Strategic plans
- Customer databases
- Proprietary algorithms
- M&A information
- Contract details

### Regulated Data
- GDPR protected data
- HIPAA health information
- PCI-DSS payment data
- SOX financial records
- ITAR controlled technology
- Export controlled data

## DLP Controls in Place

### Email Protection
- Outbound email scanning
- Attachment inspection
- Link analysis
- Recipient verification
- Encryption enforcement
- External warning banners

### File Sharing
- OneDrive/SharePoint scanning
- External sharing restrictions
- Link expiration enforcement
- Download prevention options
- Watermarking for sensitive docs

### Endpoint Protection
- USB device control
- Screen capture prevention
- Print restrictions
- Copy/paste limitations
- Browser upload blocking

## DLP Policy Violations

### What Happens When DLP Triggers

#### Warning
- User receives notification
- Can override with justification
- Action is logged and reviewed
- Manager may be notified

#### Block
- Action is prevented
- User receives explanation
- IT Security notified
- Alternative options provided

#### Quarantine
- Content held for review
- Security team evaluates
- Released or permanently blocked
- User notified of decision

### Common DLP Triggers
- Emailing credit card numbers
- Sharing files with personal email
- Uploading to unauthorized cloud services
- Copying data to USB drives
- Printing confidential documents
- Taking screenshots of sensitive data

## Handling Sensitive Data

### Email Best Practices
- Use encrypted email for sensitive data
- Verify recipient before sending
- Use internal systems when possible
- Don't forward external emails with PII
- Remove sensitive info from replies

### File Sharing Guidelines
- Use approved sharing methods only
- Set appropriate permissions
- Apply expiration dates
- Never use personal email/cloud services
- Verify recipient authorization

### Data Transfer Methods

#### Approved Methods
- Company email (internal)
- OneDrive/SharePoint (secured links)
- Secure File Transfer (SFTP)
- Encrypted email (for external)
- Approved collaboration platforms

#### Prohibited Methods
- Personal email (Gmail, Yahoo, etc.)
- Consumer cloud storage (Dropbox, Google Drive)
- Unencrypted external drives
- Public file sharing sites
- Unsecured messaging apps

## Working with Regulated Data

### GDPR Compliance
- Know what data you have
- Limit data collection
- Obtain proper consent
- Allow data access requests
- Delete data when required
- Report breaches within 72 hours

### HIPAA Compliance
- Access only necessary health information
- Use encrypted communications
- Log all access to patient records
- Complete required training
- Report suspected breaches

### PCI-DSS Compliance
- Never store full credit card data
- Use approved payment systems
- Limit payment data access
- Follow data retention rules
- Complete annual training

## Data Classification

### How to Classify
1. Identify data type
2. Assess sensitivity level
3. Apply appropriate label
4. Follow handling procedures
5. Review classification periodically

### Classification Labels

#### Public
- Marketing materials
- Press releases
- Public website content
- **Handling**: No restrictions

#### Internal
- General business documents
- Internal announcements
- Training materials
- **Handling**: Company employees only

#### Confidential
- Financial reports
- Customer information
- Business strategies
- **Handling**: Need-to-know basis

#### Restricted
- Trade secrets
- Legal documents
- Executive communications
- **Handling**: Explicit authorization required

## Responding to DLP Alerts

### If You Receive a Warning
1. Read the warning carefully
2. Verify the data in question
3. Determine if sharing is necessary
4. Use approved alternative if available
5. Provide justification if overriding

### If Content is Blocked
1. Review the blocked content
2. Remove or redact sensitive information
3. Try again with cleaned content
4. Contact IT if you need the data shared
5. Never attempt to bypass controls

### If You Made a Mistake
1. Report the incident immediately
2. Contact IT Security
3. Provide full details
4. Follow remediation instructions
5. Complete incident report if required

## Remote Work Considerations

### Home Network Security
- Use company VPN always
- Don't use public Wi-Fi for sensitive work
- Secure your home network
- Use encrypted communications
- Avoid using personal devices

### Physical Security
- Lock computer when away
- Don't work in public spaces with sensitive data
- Use privacy screens
- Secure printed documents
- Shred confidential papers

### Device Security
- Enable full disk encryption
- Use strong passwords
- Keep software updated
- Report lost/stolen devices immediately
- Don't share devices with family

## Training and Awareness

### Required Training
- Annual security awareness training
- Role-specific data handling training
- Compliance training (as applicable)
- Incident response procedures
- Policy updates and changes

### Self-Assessment
- Review data classification guide
- Test your knowledge with quizzes
- Attend optional security workshops
- Stay informed about new threats
- Report concerns or questions

## Incident Reporting

### What to Report
- Suspected data breach
- Lost/stolen devices
- Suspicious emails or calls
- Policy violations observed
- System anomalies
- DLP false positives

### How to Report
1. Contact IT Security immediately
2. Email: security@company.com
3. Phone: 24/7 Security Hotline
4. Use incident reporting portal
5. Don't delay - report right away

### After Reporting
- Security team will investigate
- You may be contacted for details
- Follow any instructions given
- Don't discuss incident publicly
- Complete any required documentation

## Consequences of Policy Violations

### Severity Levels

#### Minor (Unintentional)
- Security awareness retraining
- Manager notification
- Increased monitoring

#### Moderate (Negligence)
- Formal warning
- Mandatory retraining
- Access restrictions
- Performance documentation

#### Major (Intentional)
- Disciplinary action up to termination
- Legal consequences possible
- Law enforcement involvement
- Financial liability

## Support and Resources

### Getting Help
- Data Classification Guide: Available on intranet
- DLP Policy: https://policies.company.com/dlp
- IT Security Team: security@company.com
- Compliance Team: compliance@company.com
- Privacy Officer: privacy@company.com

### Additional Resources
- Security Awareness Portal
- Monthly security newsletters
- Compliance training modules
- Policy documentation
- FAQ database

## Key Takeaways

### Remember
✓ Think before you share
✓ Classify data properly
✓ Use approved channels only
✓ Report incidents immediately
✓ When in doubt, ask
✓ Security is everyone's responsibility

### Never
✗ Share sensitive data via personal email
✗ Upload company data to personal cloud
✗ Bypass security controls
✗ Ignore DLP warnings
✗ Share login credentials
✗ Work with sensitive data in public
        """,
        "category": "Security",
        "tags": ["dlp", "data", "security", "compliance", "privacy", "gdpr", "protection"],
        "author": "IT Security Team"
    },
    {
        "title": "Printer Driver Installation Guide",
        "content": """
# Comprehensive Printer Driver Installation

## Automatic Installation Methods

### Windows Update Method
1. Connect printer via USB or ensure network connectivity
2. Go to Settings > Update & Security > Windows Update
3. Click "Check for updates"
4. Windows will automatically detect and install drivers
5. Test print to verify installation

### Manufacturer's Software
1. Visit printer manufacturer's website
2. Download latest driver package for your OS
3. Run installer as administrator
4. Follow setup wizard instructions
5. Configure printer preferences

## Manual Installation Steps

### For Network Printers
1. Open Control Panel > Devices and Printers
2. Click "Add a printer"
3. Select "Add a network, wireless or Bluetooth printer"
4. Choose your printer from the list
5. If not found, click "The printer that I want isn't listed"
6. Enter printer IP address or hostname
7. Select appropriate driver from list

### For USB Printers
1. Connect printer to computer via USB
2. Power on the printer
3. Windows should auto-detect (if not, follow manual steps)
4. Go to Settings > Printers & scanners
5. Click "Add a printer or scanner"
6. Select your printer and click "Add device"

## Driver Troubleshooting

### Driver Conflicts
1. Uninstall old/conflicting drivers
2. Use manufacturer's removal tool
3. Clean registry entries (use CCleaner)
4. Restart computer before installing new drivers

### Compatibility Issues
1. Check Windows compatibility mode
2. Download drivers for correct OS version (32-bit vs 64-bit)
3. Use generic PCL or PostScript drivers as fallback
4. Contact manufacturer for updated drivers

### Installation Failures
1. Run installer as administrator
2. Temporarily disable antivirus
3. Check Windows Installer service status
4. Use Windows built-in troubleshooter

## Advanced Configuration

### Print Server Setup
1. Install printer on server computer
2. Share printer with appropriate permissions
3. Install drivers for all client OS versions
4. Configure print queues and priorities

### Group Policy Deployment
1. Create printer deployment package
2. Configure Group Policy for automatic installation
3. Test deployment on pilot group
4. Monitor installation success rates

## Common Issues and Solutions

### "Driver is unavailable"
- Update Windows to latest version
- Download latest driver from manufacturer
- Use Windows Update to find compatible driver
- Try generic driver as temporary solution

### Print quality problems after driver update
- Access printer properties and reset to defaults
- Calibrate printer if option available
- Check paper type settings
- Clean print heads or replace cartridges

### Printer not responding after driver installation
- Restart print spooler service
- Check printer connection (USB/network)
- Verify printer is set as default
- Run printer troubleshooter

## Maintenance Tips
- Keep drivers updated regularly
- Monitor manufacturer websites for updates
- Document successful driver versions
- Create system restore points before major updates
- Test print functionality after any system changes

## When to Escalate
- Corporate printer policy violations
- Network printer server issues
- Bulk driver deployment problems
- Licensing or procurement questions
        """,
        "category": "Hardware",
        "tags": ["printer", "driver", "installation", "troubleshooting", "network"],
        "author": "IT Support Team"
    }
]

async def populate_knowledge_base():
    """Populate the knowledge base with sample articles"""
    print("🔧 Initializing database connections...")
    
    try:
        # Initialize database connections
        await init_database_connections(
            postgres_url=None,  # Skip PostgreSQL for KB
            mongodb_url=os.getenv("MONGODB_URL", "mongodb://localhost:27017/aura_servicedesk"),
            mongodb_name="aura_servicedesk",
            redis_url=None  # Skip Redis for this script
        )
        
        # Get MongoDB database and create repository
        mongo_db = db_manager.get_mongo_db()
        kb_repo = MongoRepository("knowledge_base", mongo_db)
        
        print("📚 Checking existing knowledge base articles...")
        
        # Check if articles already exist
        existing_count = await kb_repo.count({})
        print(f"Found {existing_count} existing articles")
        
        if existing_count >= len(SAMPLE_ARTICLES):
            print("✅ Knowledge base already has sufficient articles. Skipping population.")
            return
        
        print(f"📝 Adding {len(SAMPLE_ARTICLES)} sample articles to knowledge base...")
        
        # Add each article
        for i, article_data in enumerate(SAMPLE_ARTICLES, 1):
            # Check if article with same title already exists
            existing_articles = await kb_repo.find_many({"title": article_data["title"]}, limit=1)
            
            if existing_articles and len(existing_articles) > 0:
                print(f"   ⏭️  Article '{article_data['title']}' already exists, skipping...")
                continue
            
            # Prepare article document
            article_doc = {
                **article_data,
                "views": 0,
                "helpful_votes": 0,
                "unhelpful_votes": 0,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
            
            # Insert article
            article_id = await kb_repo.create(article_doc)
            print(f"   ✅ Added article {i}/{len(SAMPLE_ARTICLES)}: '{article_data['title']}'")
        
        # Final count
        final_count = await kb_repo.count({})
        print(f"\n🎉 Knowledge base population completed!")
        print(f"📊 Total articles in database: {final_count}")
        
        # Show category breakdown
        categories = {}
        all_articles = await kb_repo.find_many({}, limit=100)
        for article in all_articles:
            category = article.get("category", "Unknown")
            categories[category] = categories.get(category, 0) + 1
        
        print("\n📋 Articles by category:")
        for category, count in categories.items():
            print(f"   • {category}: {count} articles")
        
    except Exception as e:
        print(f"❌ Error populating knowledge base: {e}")
        raise
    finally:
        # Close database connections
        try:
            await db_manager.close_connections()
            print("🔌 Database connections closed")
        except Exception as e:
            print(f"⚠️  Warning: Error closing connections: {e}")

if __name__ == "__main__":
    print("🚀 Aura Knowledge Base Population Script")
    print("=" * 50)
    
    # Run the population script
    asyncio.run(populate_knowledge_base())

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a FreePBX deployment automation project for Hetzner VPS servers. It provides one-command deployment of a complete SIP/VoIP system using Docker containers with embedded MySQL database.

**Key Components:**
- `deploy.sh` - Main deployment script (437 lines) with full FreePBX installation and service management
- `security-setup.sh` - VPS security hardening script (216 lines) with UFW, fail2ban, and monitoring
- `README.md` - Russian user documentation with setup and usage instructions
- `README_DEPLOYMENT.md` - Technical deployment guide
- Auto-generated management scripts in `/opt/freepbx/`

## Common Commands

### Initial Deployment
```bash
# Full installation (requires root)
sudo ./deploy.sh

# Security hardening (run separately)
sudo ./security-setup.sh
```

### Service Management (via deploy.sh)
```bash
./deploy.sh start    # Start FreePBX services
./deploy.sh stop     # Stop FreePBX services
./deploy.sh status   # Show system status and resource usage
./deploy.sh logs     # View FreePBX logs (follows with tail)
./deploy.sh backup   # Create backup using fwconsole
./deploy.sh update   # Update FreePBX container image
./deploy.sh users    # Create SIP users (1001-1005) with predefined passwords
```

### Direct Management Scripts (created at /opt/freepbx/)
```bash
cd /opt/freepbx
./start.sh    # Start services, show web URL
./stop.sh     # Stop services  
./status.sh   # System status with Docker stats and network info
./logs.sh     # Follow logs with last 100 lines
./backup.sh   # Full backup including database dump
./update.sh   # Pull latest image and restart
```

### Docker Operations
```bash
# Manual container management
cd /opt/freepbx
docker-compose up -d                    # Start in background
docker-compose down                     # Stop and remove containers  
docker-compose logs -f freepbx-main    # Follow main container logs
docker-compose ps                       # Show running containers
docker-compose exec freepbx-main bash  # Shell access to container
```

## Architecture

**Deployment Flow (deploy.sh):**
1. Root permission and OS detection checks (`check_root`, `detect_os`)
2. Docker & Docker Compose v2.21.0 installation (`install_docker`)
3. UFW firewall configuration (`setup_firewall`) - ports 22, 8080, 8443, 5060, 5160, 10000-20000
4. Project structure creation in `/opt/freepbx/` (`create_project_structure`)
5. Docker Compose YAML and .env file generation
6. Management scripts creation (`create_management_scripts`)
7. Container deployment and startup (`start_freepbx`)

**Container Architecture:**
- **Image:** `tiredofit/freepbx:latest` 
- **Container Name:** `freepbx-main`
- **Database:** Embedded MySQL (`DB_EMBEDDED=TRUE`)
- **Network:** Bridge network `freepbx_network` (172.18.0.0/16)
- **Health Check:** HTTP check on `/admin/config.php` with 5-minute startup period
- **Restart Policy:** `unless-stopped`

**Port Mapping:**
- Web Interface: 8080→80 (HTTP), 8443→443 (HTTPS)
- SIP: 5060→5060 (UDP/TCP), 5160→5160 (UDP/TCP - PJSIP)
- RTP Media: 10000-20000→10000-20000 (UDP)
- Container SSH: 2222→22 (optional management)

**Persistent Volumes:**
- `freepbx_data` - Main FreePBX data and configuration
- `freepbx_logs` - System and application logs 
- `freepbx_recordings` - Call recordings storage
- `freepbx_backup` - Backup file storage

**Security Features (security-setup.sh):**
- UFW firewall with restrictive default policies
- Fail2ban with custom Asterisk/FreePBX filters
- System hardening via sysctl (network security, performance tuning)
- Automated security updates via unattended-upgrades
- Log rotation configuration
- Cron-based monitoring script (`/usr/local/bin/pbx-monitor.sh`)

## Key Functions and Implementation Details

**deploy.sh Core Functions:**
- `check_root()` - Validates root permissions (line 38)
- `detect_os()` - OS detection and version checking (line 45)
- `install_docker()` - Complete Docker/Docker Compose setup (line 57)
- `setup_firewall()` - UFW configuration with all required ports (line 93)
- `create_project_structure()` - Generates docker-compose.yml and .env (line 127)
- `create_management_scripts()` - Creates all operational scripts (line 243)
- `start_freepbx()` - Container deployment and startup (line 321)

**Environment Configuration:**
- Default timezone: `Europe/Moscow`
- Server IP hardcoded: `37.27.240.184` (update in both .env and scripts)
- RTP port range: 10000-20000
- Container uses privileged mode for Asterisk functionality

**Error Handling:**
- All scripts use `set -e` for immediate error exit
- Color-coded logging functions: `log()`, `warn()`, `error()`, `info()`
- Comprehensive status checking and reporting
- Health checks with proper startup wait times

**Security Implementation:**
- Fail2ban filters for Asterisk registration attempts and web attacks
- Sysctl network security hardening parameters
- UFW with specific port rules and comments
- Automated monitoring with service restart capability
- Log rotation for long-term maintenance

## Post-Installation Access

**Initial Setup:**
- FreePBX web interface: `http://37.27.240.184:8080`
- Initialization time: 3-5 minutes (health check allows up to 5 minutes)
- Follow FreePBX setup wizard to create admin account
- All management via generated scripts in `/opt/freepbx/`

**Monitoring:**
- Cron job runs every 5 minutes checking container and port status
- Logs in `/var/log/pbx-monitor.log`
- Automatic container restart on failure

## SIP Users Management

**Automated User Creation:**
- `create-sip-users.sh` - Creates 5 predefined SIP users (1001-1005)
- Passwords stored as MD5 hashes in FreePBX database
- Users: 1001-1005 with passwords password1001-password1005
- Full user details in `sip-users-passwords.txt`

**Usage:**
```bash
# Create users after FreePBX is running
./deploy.sh users
# Or directly
./create-sip-users.sh
```

**SIP Client Configuration:**
- Server: 37.27.240.184:5060
- Transport: UDP
- Username: 1001 (or 1002-1005)
- Password: password1001 (corresponding password)
- Internal calls work between all extensions
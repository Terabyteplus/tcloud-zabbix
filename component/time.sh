#!/bin/bash
#############################################
# NTP & Timezone Setup Script
# License By: Terabyte Plus
# Reference: Zabbix 7 on Ubuntu 24.04 Guide
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   NTP & Timezone Configuration${NC}"
echo -e "${CYAN}   Terabyte Plus - tCloud${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ─── Check root ───
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root (sudo -s)${NC}"
    exit 1
fi

# ─── Locale Setup ───
echo -e "${YELLOW}[INFO] Setting up locale...${NC}"
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
echo -e "${GREEN}[OK] Locale set to en_US.UTF-8${NC}"
echo ""

# ─── Current Timezone ───
echo -e "${YELLOW}[INFO] Current timezone:${NC}"
timedatectl | grep "Time zone"
echo ""

# ─── Set Timezone ───
read -p "$(echo -e ${CYAN}Enter timezone [default: Asia/Bangkok]:${NC} )" INPUT_TIMEZONE
TIMEZONE="${INPUT_TIMEZONE:-Asia/Bangkok}"

# Validate timezone
if timedatectl list-timezones | grep -qx "$TIMEZONE"; then
    timedatectl set-timezone "$TIMEZONE"
    echo -e "${GREEN}[OK] Timezone set to: $TIMEZONE${NC}"
else
    echo -e "${RED}[ERROR] Invalid timezone: $TIMEZONE${NC}"
    exit 1
fi
echo ""

# ─── Install NTP ───
echo -e "${YELLOW}[INFO] Installing NTP service...${NC}"
read -p "$(echo -e ${CYAN}Install NTP service? [Y/n]:${NC} )" INSTALL_NTP
INSTALL_NTP="${INSTALL_NTP:-Y}"

if [[ "$INSTALL_NTP" =~ ^[Yy]$ ]]; then
    # Stop and disable systemd-timesyncd (conflicts with ntpsec/ntp)
    echo -e "${YELLOW}[INFO] Disabling systemd-timesyncd (conflicts with NTP)...${NC}"
    systemctl stop systemd-timesyncd 2>/dev/null || true
    systemctl disable systemd-timesyncd 2>/dev/null || true
    apt remove -y systemd-timesyncd 2>/dev/null || true
    echo -e "${GREEN}[OK] systemd-timesyncd removed${NC}"

    # Install ntpsec (replacement for ntp on Ubuntu 24.04)
    apt install ntpsec ntpsec-ntpq -y
    echo -e "${GREEN}[OK] NTPsec installed successfully${NC}"
else
    echo -e "${YELLOW}[SKIP] NTP installation skipped${NC}"
    exit 0
fi
echo ""

# ─── NTP Server Configuration ───
echo -e "${YELLOW}[INFO] Configuring NTP servers...${NC}"
echo -e "${CYAN}Default NTP servers (from config/ntp.conf):${NC}"
echo "  - time1.nimt.or.th"
echo "  - time2.nimt.or.th"
echo "  - time3.nimt.or.th"
echo "  - time4.nimt.or.th"
echo ""

read -p "$(echo -e ${CYAN}Add additional NTP server IP? [enter to skip]:${NC} )" EXTRA_NTP_SERVER
echo ""

# ─── LAN Subnet Restriction ───
read -p "$(echo -e ${CYAN}Enter LAN subnet to allow NTP access [e.g. 10.255.XXX.1] [enter to skip]:${NC} )" LAN_SUBNET
read -p "$(echo -e ${CYAN}Enter subnet mask [default: 255.255.255.0]:${NC} )" LAN_MASK
LAN_MASK="${LAN_MASK:-255.255.255.0}"
echo ""

# ─── Detect NTP config path ───
if [ -d /etc/ntpsec ]; then
    NTP_CONF_DEST="/etc/ntpsec/ntp.conf"
    NTP_SERVICE="ntpsec"
elif [ -f /etc/ntp.conf ]; then
    NTP_CONF_DEST="/etc/ntp.conf"
    NTP_SERVICE="ntp"
else
    # Default for ntpsec on Ubuntu 24.04
    NTP_CONF_DEST="/etc/ntpsec/ntp.conf"
    NTP_SERVICE="ntpsec"
    mkdir -p /etc/ntpsec
fi

echo -e "${YELLOW}[INFO] NTP config path: $NTP_CONF_DEST${NC}"
echo -e "${YELLOW}[INFO] NTP service name: $NTP_SERVICE${NC}"

# ─── Backup existing config ───
if [ -f "$NTP_CONF_DEST" ]; then
    cp "$NTP_CONF_DEST" "${NTP_CONF_DEST}.bak"
    echo -e "${GREEN}[OK] Backed up $NTP_CONF_DEST to ${NTP_CONF_DEST}.bak${NC}"
fi

# ─── Build NTP config dynamically ───
cat > "$NTP_CONF_DEST" <<NTPEOF
# /etc/ntpsec/ntp.conf
#
# License By: Terabyte Plus
# Use public NTP servers from the National Metrology Institute of Thailand
#
server time1.nimt.or.th iburst
server time2.nimt.or.th iburst
server time3.nimt.or.th iburst
server time4.nimt.or.th iburst
NTPEOF

# Append extra NTP server if provided
if [ -n "$EXTRA_NTP_SERVER" ]; then
    echo "server ${EXTRA_NTP_SERVER} iburst" >> "$NTP_CONF_DEST"
    echo -e "${GREEN}[OK] Added extra NTP server: $EXTRA_NTP_SERVER${NC}"
fi

# Append the rest of config
cat >> "$NTP_CONF_DEST" <<NTPEOF

# Drift file
driftfile /var/lib/ntpsec/ntp.drift

# Allow localhost
restrict default kod nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1
NTPEOF

# Add LAN restriction if provided
if [ -n "$LAN_SUBNET" ]; then
    echo "restrict ${LAN_SUBNET} mask ${LAN_MASK} nomodify notrap" >> "$NTP_CONF_DEST"
    echo -e "${GREEN}[OK] Added LAN restriction: $LAN_SUBNET/$LAN_MASK${NC}"
fi

# Append logging config
cat >> "$NTP_CONF_DEST" <<NTPEOF

# Logging
logfile /var/log/ntp.log

# Statistics
statistics loopstats peerstats clockstats
statsdir /var/log/ntpstats/

# Enable filegen
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable
NTPEOF

echo -e "${GREEN}[OK] NTP config written to: $NTP_CONF_DEST${NC}"
echo ""

# ─── Create stats directory ───
mkdir -p /var/log/ntpstats
chown ntpsec:ntpsec /var/log/ntpstats 2>/dev/null || true

# ─── Restart NTP service ───
echo -e "${YELLOW}[INFO] Restarting NTP service ($NTP_SERVICE)...${NC}"
systemctl restart "$NTP_SERVICE"
systemctl enable "$NTP_SERVICE"
echo -e "${GREEN}[OK] $NTP_SERVICE service restarted and enabled${NC}"
echo ""

# ─── Verify NTP sync ───
echo -e "${YELLOW}[INFO] Checking NTP service status...${NC}"
systemctl status "$NTP_SERVICE" --no-pager -l 2>/dev/null || true
echo ""

echo -e "${YELLOW}[INFO] Verifying NTP synchronization...${NC}"
ntpq -p 2>/dev/null || echo -e "${YELLOW}[WARN] ntpq not ready yet, NTP may need a moment to sync${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   NTP & Timezone Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

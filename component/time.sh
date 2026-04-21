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
    apt install ntp -y
    echo -e "${GREEN}[OK] NTP installed successfully${NC}"
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

# ─── Backup existing config ───
if [ -f /etc/ntp.conf ]; then
    cp /etc/ntp.conf /etc/ntp.conf.bak
    echo -e "${GREEN}[OK] Backed up /etc/ntp.conf to /etc/ntp.conf.bak${NC}"
elif [ -f /etc/ntpsec/ntp.conf ]; then
    cp /etc/ntpsec/ntp.conf /etc/ntpsec/ntp.conf.bak
    echo -e "${GREEN}[OK] Backed up /etc/ntpsec/ntp.conf to /etc/ntpsec/ntp.conf.bak${NC}"
fi

# ─── Generate NTP config ───
NTP_CONF_DEST="/etc/ntp.conf"
if [ -d /etc/ntpsec ]; then
    NTP_CONF_DEST="/etc/ntpsec/ntp.conf"
fi

# Copy base config
cp "$PROJECT_DIR/config/ntp.conf" "$NTP_CONF_DEST"

# Append extra NTP server if provided
if [ -n "$EXTRA_NTP_SERVER" ]; then
    sed -i "/server time4.nimt.or.th iburst/a server ${EXTRA_NTP_SERVER} iburst" "$NTP_CONF_DEST"
    echo -e "${GREEN}[OK] Added extra NTP server: $EXTRA_NTP_SERVER${NC}"
fi

# Add LAN restriction if provided
if [ -n "$LAN_SUBNET" ]; then
    sed -i "s|# restrict \[IP_ADDRESS\] mask 255.255.255.0 nomodify notrap|restrict ${LAN_SUBNET} mask ${LAN_MASK} nomodify notrap|" "$NTP_CONF_DEST"
    echo -e "${GREEN}[OK] Added LAN restriction: $LAN_SUBNET/$LAN_MASK${NC}"
fi

echo -e "${GREEN}[OK] NTP config written to: $NTP_CONF_DEST${NC}"
echo ""

# ─── Restart NTP ───
systemctl restart ntp
systemctl enable ntp
echo -e "${GREEN}[OK] NTP service restarted and enabled${NC}"
echo ""

# ─── Verify NTP sync ───
echo -e "${YELLOW}[INFO] Verifying NTP synchronization...${NC}"
ntpq -p
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   NTP & Timezone Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

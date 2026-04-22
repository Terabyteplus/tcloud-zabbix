#!/bin/bash
#############################################
# Zabbix 7.2+ Apache Path Fix Script
# License By: Terabyte Plus
#
# Starting with Zabbix 7.2, frontend PHP files
# were moved from /usr/share/zabbix to
# /usr/share/zabbix/ui
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Zabbix 7.2+ Apache Path Fix${NC}"
echo -e "${CYAN}   Terabyte Plus - tCloud${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ─── Check root ───
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root (sudo -s)${NC}"
    exit 1
fi

ZABBIX_CONF="/etc/apache2/conf-available/zabbix.conf"

# ─── Check if fix is needed ───
if [ ! -f "$ZABBIX_CONF" ]; then
    echo -e "${YELLOW}[SKIP] Zabbix Apache config not found at $ZABBIX_CONF${NC}"
    echo -e "${YELLOW}[INFO] This fix is only needed for Zabbix 7.2+${NC}"
    exit 0
fi

# Check if already using /ui path
if grep -q "/usr/share/zabbix/ui" "$ZABBIX_CONF"; then
    echo -e "${GREEN}[OK] Apache config already using /usr/share/zabbix/ui path${NC}"
    echo -e "${YELLOW}[INFO] No fix needed${NC}"
    exit 0
fi

# Check if using old path
if grep -q "/usr/share/zabbix" "$ZABBIX_CONF"; then
    echo -e "${YELLOW}[INFO] Detected old path /usr/share/zabbix in Apache config${NC}"
    echo -e "${YELLOW}[INFO] Zabbix 7.2+ requires /usr/share/zabbix/ui${NC}"
    echo ""

    echo -ne "${CYAN}Apply fix now? [Y/n]: ${NC}"
    read CONFIRM
    CONFIRM="${CONFIRM:-Y}"

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[SKIP] Fix cancelled${NC}"
        exit 0
    fi

    # Backup
    cp "$ZABBIX_CONF" "${ZABBIX_CONF}.bak"
    echo -e "${GREEN}[OK] Backed up to ${ZABBIX_CONF}.bak${NC}"

    # Fix path
    sed -i 's:/usr/share/zabbix:/usr/share/zabbix/ui:g' "$ZABBIX_CONF"
    echo -e "${GREEN}[OK] Updated path to /usr/share/zabbix/ui${NC}"

    # Restart Apache
    echo -e "${YELLOW}[INFO] Restarting Apache...${NC}"
    systemctl restart apache2
    echo -e "${GREEN}[OK] Apache restarted${NC}"
    echo ""

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Apache Path Fix Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${YELLOW}[INFO] No Zabbix path found in Apache config${NC}"
fi

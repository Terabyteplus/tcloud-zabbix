#!/bin/bash
#############################################
# Zabbix Service Management Script
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

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Zabbix Service Management${NC}"
echo -e "${CYAN}   Terabyte Plus - tCloud${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ─── Check root ───
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root (sudo -s)${NC}"
    exit 1
fi

# ─── Web Server Selection ───
echo -e "${CYAN}Select installed web server:${NC}"
echo "  1) Apache (default)"
echo "  2) Nginx"
echo ""
read -p "$(echo -e ${CYAN}Select web server [default: 1]:${NC} )" WS_CHOICE
WS_CHOICE="${WS_CHOICE:-1}"

case "$WS_CHOICE" in
    1) WEB_SERVICE="apache2" ;;
    2) WEB_SERVICE="nginx" ;;
    *)
        echo -e "${RED}[ERROR] Invalid choice${NC}"
        exit 1
        ;;
esac
echo ""

# ─── Service Action ───
echo -e "${CYAN}Select action:${NC}"
echo "  1) Start & Enable all services"
echo "  2) Restart all services"
echo "  3) Stop all services"
echo "  4) Check status"
echo ""
read -p "$(echo -e ${CYAN}Select action [default: 1]:${NC} )" ACTION_CHOICE
ACTION_CHOICE="${ACTION_CHOICE:-1}"
echo ""

SERVICES="zabbix-server zabbix-agent ${WEB_SERVICE}"

case "$ACTION_CHOICE" in
    1)
        echo -e "${YELLOW}[INFO] Starting and enabling services...${NC}"
        systemctl restart $SERVICES
        systemctl enable $SERVICES
        echo -e "${GREEN}[OK] All services started and enabled${NC}"
        ;;
    2)
        echo -e "${YELLOW}[INFO] Restarting services...${NC}"
        systemctl restart $SERVICES
        echo -e "${GREEN}[OK] All services restarted${NC}"
        ;;
    3)
        echo -e "${YELLOW}[INFO] Stopping services...${NC}"
        systemctl stop $SERVICES
        echo -e "${GREEN}[OK] All services stopped${NC}"
        ;;
    4)
        echo -e "${YELLOW}[INFO] Checking service status...${NC}"
        ;;
    *)
        echo -e "${RED}[ERROR] Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Service Status${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

for SERVICE in $SERVICES; do
    STATUS=$(systemctl is-active "$SERVICE" 2>/dev/null || echo "inactive")
    ENABLED=$(systemctl is-enabled "$SERVICE" 2>/dev/null || echo "disabled")

    if [ "$STATUS" == "active" ]; then
        echo -e "  ${GREEN}●${NC} ${SERVICE}: ${GREEN}active${NC} (${ENABLED})"
    else
        echo -e "  ${RED}●${NC} ${SERVICE}: ${RED}${STATUS}${NC} (${ENABLED})"
    fi
done

echo ""

# ─── Show Access Info ───
if [ "$ACTION_CHOICE" == "1" ] || [ "$ACTION_CHOICE" == "2" ]; then
    echo -e "${YELLOW}[INFO] Getting server IP address...${NC}"
    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Zabbix is Ready!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${CYAN}  Access Zabbix Web UI:${NC}"
    echo -e "  http://${SERVER_IP}/zabbix"
    echo ""
    echo -e "${CYAN}  Default Credentials:${NC}"
    echo -e "  Username: ${GREEN}Admin${NC}"
    echo -e "  Password: ${GREEN}zabbix${NC}"
    echo ""
    echo -e "${YELLOW}  ⚠ Please change the default password after first login!${NC}"
    echo ""
fi

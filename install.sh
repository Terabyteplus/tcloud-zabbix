#!/bin/bash
#############################################
#  Zabbix 7 Full Installation Script
#  License By: Terabyte Plus
#  Platform: Ubuntu 24.04 (Noble)
#
#  Reference:
#    - How to Install Zabbix 7 on Ubuntu 24
#    - https://www.zabbix.com/download
#
#  Usage:
#    sudo bash install.sh
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Banner ───
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════╗"
    echo "  ║                                                       ║"
    echo "  ║     ████████╗ ██████╗██╗      ██████╗ ██╗   ██╗██████╗║"
    echo "  ║     ╚══██╔══╝██╔════╝██║     ██╔═══██╗██║   ██║██╔══██║"
    echo "  ║        ██║   ██║     ██║     ██║   ██║██║   ██║██║  ██║"
    echo "  ║        ██║   ██║     ██║     ██║   ██║██║   ██║██║  ██║"
    echo "  ║        ██║   ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝"
    echo "  ║        ╚═╝    ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝"
    echo "  ║                                                       ║"
    echo "  ║           Zabbix 7 Installer - Terabyte Plus          ║"
    echo "  ║           Platform: Ubuntu 24.04 (Noble)              ║"
    echo "  ╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# ─── Check root ───
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR] This script must be run as root${NC}"
        echo -e "${YELLOW}[INFO] Run: sudo bash install.sh${NC}"
        exit 1
    fi
}

# ─── Show Menu ───
show_menu() {
    echo -e "${BOLD}${YELLOW}  Installation Menu${NC}"
    echo -e "${YELLOW}  ────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC}  Full Installation (All Steps)"
    echo -e "  ${CYAN}2)${NC}  NTP & Timezone Setup"
    echo -e "  ${CYAN}3)${NC}  Zabbix Server Installation"
    echo -e "  ${CYAN}4)${NC}  Database Setup"
    echo -e "  ${CYAN}5)${NC}  Start/Manage Services"
    echo -e "  ${CYAN}6)${NC}  SSL/HTTPS Configuration"
    echo -e "  ${CYAN}7)${NC}  System Update (Security Patches)"
    echo -e "  ${CYAN}8)${NC}  Fix Apache Path (Zabbix 7.2+)"
    echo ""
    echo -e "  ${CYAN}0)${NC}  Exit"
    echo ""
    echo -e "${YELLOW}  ────────────────────────────────────────${NC}"
    echo ""
}

# ─── System Update ───
system_update() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   System Update${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    echo -e "${CYAN}Select update type:${NC}"
    echo "  1) Security patches only (recommended)"
    echo "  2) Full upgrade (all packages)"
    echo ""
    read -p "$(echo -e ${CYAN}Select option [default: 1]:${NC} )" UPDATE_CHOICE
    UPDATE_CHOICE="${UPDATE_CHOICE:-1}"
    echo ""

    read -p "$(echo -e ${CYAN}Proceed with update? [Y/n]:${NC} )" CONFIRM
    CONFIRM="${CONFIRM:-Y}"

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[SKIP] Update cancelled${NC}"
        return
    fi

    apt update -y

    case "$UPDATE_CHOICE" in
        1)
            echo -e "${YELLOW}[INFO] Installing security patches only...${NC}"
            apt install --only-upgrade $(apt list --upgradable 2>/dev/null | grep -i security | awk -F/ '{print $1}') 2>/dev/null || true
            echo -e "${GREEN}[OK] Security patches installed${NC}"
            ;;
        2)
            echo -e "${YELLOW}[INFO] Upgrading all packages...${NC}"
            apt upgrade -y
            echo -e "${GREEN}[OK] Full upgrade complete${NC}"
            ;;
    esac
    echo ""
}

# ─── Full Installation ───
full_install() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Full Zabbix Installation${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}This will run all installation steps in order:${NC}"
    echo "  1. System Update"
    echo "  2. NTP & Timezone Setup"
    echo "  3. Zabbix Server Installation"
    echo "  4. Database Setup"
    echo "  5. Start Services"
    echo ""
    read -p "$(echo -e ${CYAN}Proceed with full installation? [Y/n]:${NC} )" CONFIRM
    CONFIRM="${CONFIRM:-Y}"

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[SKIP] Installation cancelled${NC}"
        return
    fi

    echo ""
    echo -e "${YELLOW}━━━ Step 1/5: System Update ━━━${NC}"
    system_update

    echo ""
    echo -e "${YELLOW}━━━ Step 2/5: NTP & Timezone ━━━${NC}"
    bash "$SCRIPT_DIR/component/time.sh"

    echo ""
    echo -e "${YELLOW}━━━ Step 3/5: Zabbix Installation ━━━${NC}"
    bash "$SCRIPT_DIR/component/zabbix.sh"

    echo ""
    echo -e "${YELLOW}━━━ Step 4/5: Database Setup ━━━${NC}"
    bash "$SCRIPT_DIR/component/database.sh"

    echo ""
    echo -e "${YELLOW}━━━ Step 5/5: Start Services ━━━${NC}"
    bash "$SCRIPT_DIR/component/service.sh"

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                           ║${NC}"
    echo -e "${GREEN}║   Full Installation Complete! 🎉          ║${NC}"
    echo -e "${GREEN}║                                           ║${NC}"
    echo -e "${GREEN}║   Optional: Run SSL setup (option 6)      ║${NC}"
    echo -e "${GREEN}║                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
}

# ─── Main ───
main() {
    check_root
    show_banner

    while true; do
        show_menu
        echo -ne "${CYAN}  Select option: ${NC}"
        read CHOICE
        echo ""

        case "$CHOICE" in
            1)
                full_install
                ;;
            2)
                bash "$SCRIPT_DIR/component/time.sh"
                ;;
            3)
                bash "$SCRIPT_DIR/component/zabbix.sh"
                ;;
            4)
                bash "$SCRIPT_DIR/component/database.sh"
                ;;
            5)
                bash "$SCRIPT_DIR/component/service.sh"
                ;;
            6)
                bash "$SCRIPT_DIR/component/ssl.sh"
                ;;
            7)
                system_update
                ;;
            8)
                bash "$SCRIPT_DIR/component/fix-apache.sh"
                ;;
            0)
                echo -e "${GREEN}Goodbye! 👋${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid option. Please try again.${NC}"
                ;;
        esac

        echo ""
        echo -ne "${CYAN}Press Enter to return to menu...${NC}"
        read
        show_banner
    done
}

main "$@"

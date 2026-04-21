#!/bin/bash
#############################################
# Zabbix 7 Installation Script
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
echo -e "${CYAN}   Zabbix Server Installation${NC}"
echo -e "${CYAN}   Terabyte Plus - tCloud${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ─── Check root ───
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root (sudo -s)${NC}"
    exit 1
fi

# ─── Check OS ───
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    echo -e "${RED}[ERROR] This script is designed for Ubuntu only${NC}"
    exit 1
fi

OS_VERSION=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
echo -e "${YELLOW}[INFO] Detected OS: Ubuntu $OS_VERSION${NC}"
echo ""

# ─── Zabbix Version Selection ───
echo -e "${CYAN}Available Zabbix Versions:${NC}"
echo "  1) Zabbix 7.4 (Latest)"
echo "  2) Zabbix 7.0 LTS (Recommended)"
echo "  3) Zabbix 6.4"
echo "  4) Custom version"
echo ""
read -p "$(echo -e ${CYAN}Select Zabbix version [default: 1]:${NC} )" ZABBIX_CHOICE
ZABBIX_CHOICE="${ZABBIX_CHOICE:-1}"

case "$ZABBIX_CHOICE" in
    1) ZABBIX_VERSION="7.4" ;;
    2) ZABBIX_VERSION="7.0" ;;
    3) ZABBIX_VERSION="6.4" ;;
    4)
        read -p "$(echo -e ${CYAN}Enter Zabbix version [e.g. 7.0]:${NC} )" ZABBIX_VERSION
        if [ -z "$ZABBIX_VERSION" ]; then
            echo -e "${RED}[ERROR] Zabbix version is required${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}[ERROR] Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}[OK] Selected Zabbix version: $ZABBIX_VERSION${NC}"
echo ""

# ─── Ubuntu Version for Repository ───
read -p "$(echo -e ${CYAN}Ubuntu version for repository [default: $OS_VERSION]:${NC} )" UBUNTU_VER
UBUNTU_VER="${UBUNTU_VER:-$OS_VERSION}"
echo ""

# ─── Database Selection ───
echo -e "${CYAN}Select Database Backend:${NC}"
echo "  1) MySQL (default)"
echo "  2) PostgreSQL"
echo ""
read -p "$(echo -e ${CYAN}Select database [default: 1]:${NC} )" DB_CHOICE
DB_CHOICE="${DB_CHOICE:-1}"

case "$DB_CHOICE" in
    1) DB_TYPE="mysql" ;;
    2) DB_TYPE="pgsql" ;;
    *)
        echo -e "${RED}[ERROR] Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}[OK] Selected database: $DB_TYPE${NC}"
echo ""

# ─── Web Server Selection ───
echo -e "${CYAN}Select Web Server:${NC}"
echo "  1) Apache (default)"
echo "  2) Nginx"
echo ""
read -p "$(echo -e ${CYAN}Select web server [default: 1]:${NC} )" WS_CHOICE
WS_CHOICE="${WS_CHOICE:-1}"

case "$WS_CHOICE" in
    1) WEB_SERVER="apache" ;;
    2) WEB_SERVER="nginx" ;;
    *)
        echo -e "${RED}[ERROR] Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}[OK] Selected web server: $WEB_SERVER${NC}"
echo ""

# ─── Components Selection ───
echo -e "${CYAN}Select Components to Install:${NC}"
read -p "$(echo -e ${CYAN}Install Zabbix Server? [Y/n]:${NC} )" INSTALL_SERVER
INSTALL_SERVER="${INSTALL_SERVER:-Y}"

read -p "$(echo -e ${CYAN}Install Zabbix Frontend? [Y/n]:${NC} )" INSTALL_FRONTEND
INSTALL_FRONTEND="${INSTALL_FRONTEND:-Y}"

read -p "$(echo -e ${CYAN}Install Zabbix Agent? [Y/n]:${NC} )" INSTALL_AGENT
INSTALL_AGENT="${INSTALL_AGENT:-Y}"
echo ""

# ─── Confirmation ───
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Installation Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "  Zabbix Version  : ${GREEN}$ZABBIX_VERSION${NC}"
echo -e "  Ubuntu Version  : ${GREEN}$UBUNTU_VER${NC}"
echo -e "  Database        : ${GREEN}$DB_TYPE${NC}"
echo -e "  Web Server      : ${GREEN}$WEB_SERVER${NC}"
echo -e "  Server          : ${GREEN}$INSTALL_SERVER${NC}"
echo -e "  Frontend        : ${GREEN}$INSTALL_FRONTEND${NC}"
echo -e "  Agent           : ${GREEN}$INSTALL_AGENT${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
read -p "$(echo -e ${CYAN}Proceed with installation? [Y/n]:${NC} )" CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[SKIP] Installation cancelled${NC}"
    exit 0
fi

# ─── Step 1: Update System ───
echo ""
echo -e "${YELLOW}[STEP 1/5] Updating system packages...${NC}"
apt update -y
echo -e "${GREEN}[OK] System updated${NC}"
echo ""

# ─── Step 2: Fix dpkg excludes for Zabbix docs ───
echo -e "${YELLOW}[STEP 2/5] Configuring dpkg excludes for Zabbix...${NC}"
DPKG_EXCLUDES="/etc/dpkg/dpkg.cfg.d/excludes"
if [ -f "$DPKG_EXCLUDES" ]; then
    if ! grep -q "zabbix" "$DPKG_EXCLUDES"; then
        echo "" >> "$DPKG_EXCLUDES"
        echo "#... except zabbix" >> "$DPKG_EXCLUDES"
        echo "path-include=/usr/share/doc/zabbix*" >> "$DPKG_EXCLUDES"
        echo -e "${GREEN}[OK] Added Zabbix exception to dpkg excludes${NC}"
    else
        echo -e "${YELLOW}[SKIP] Zabbix exception already exists in dpkg excludes${NC}"
    fi
else
    echo -e "${YELLOW}[SKIP] dpkg excludes file not found, skipping${NC}"
fi
echo ""

# ─── Step 3: Install Zabbix Repository ───
echo -e "${YELLOW}[STEP 3/5] Installing Zabbix repository...${NC}"
REPO_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+ubuntu${UBUNTU_VER}_all.deb"
echo -e "${CYAN}[INFO] Repository URL: $REPO_URL${NC}"

wget "$REPO_URL" -O /tmp/zabbix-release.deb
dpkg -i /tmp/zabbix-release.deb
apt update -y
rm -f /tmp/zabbix-release.deb
echo -e "${GREEN}[OK] Zabbix repository installed${NC}"
echo ""

# ─── Step 4: Install Zabbix Packages ───
echo -e "${YELLOW}[STEP 4/5] Installing Zabbix packages...${NC}"
PACKAGES=""

if [[ "$INSTALL_SERVER" =~ ^[Yy]$ ]]; then
    if [ "$DB_TYPE" == "mysql" ]; then
        PACKAGES="$PACKAGES zabbix-server-mysql zabbix-sql-scripts"
    else
        PACKAGES="$PACKAGES zabbix-server-pgsql zabbix-sql-scripts"
    fi
fi

if [[ "$INSTALL_FRONTEND" =~ ^[Yy]$ ]]; then
    PACKAGES="$PACKAGES zabbix-frontend-php"
    if [ "$WEB_SERVER" == "apache" ]; then
        PACKAGES="$PACKAGES zabbix-apache-conf"
    else
        PACKAGES="$PACKAGES zabbix-nginx-conf"
    fi
fi

if [[ "$INSTALL_AGENT" =~ ^[Yy]$ ]]; then
    PACKAGES="$PACKAGES zabbix-agent"
fi

echo -e "${CYAN}[INFO] Installing: $PACKAGES${NC}"
apt install $PACKAGES -y
echo -e "${GREEN}[OK] Zabbix packages installed${NC}"
echo ""

# ─── Step 5: Install Database Server ───
echo -e "${YELLOW}[STEP 5/5] Database Server Installation...${NC}"
read -p "$(echo -e ${CYAN}Install database server on this host? [Y/n]:${NC} )" INSTALL_DB_SERVER
INSTALL_DB_SERVER="${INSTALL_DB_SERVER:-Y}"

if [[ "$INSTALL_DB_SERVER" =~ ^[Yy]$ ]]; then
    if [ "$DB_TYPE" == "mysql" ]; then
        apt install mysql-server -y
        echo -e "${GREEN}[OK] MySQL Server installed${NC}"
        mysql --version
    else
        apt install postgresql postgresql-contrib -y
        echo -e "${GREEN}[OK] PostgreSQL Server installed${NC}"
        psql --version
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Zabbix Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}[NEXT] Run the database setup script:${NC}"
echo -e "${CYAN}  sudo bash component/database.sh${NC}"
echo ""

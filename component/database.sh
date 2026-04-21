#!/bin/bash
#############################################
# Zabbix Database Setup Script
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
echo -e "${CYAN}   Zabbix Database Setup${NC}"
echo -e "${CYAN}   Terabyte Plus - tCloud${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ─── Check root ───
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root (sudo -s)${NC}"
    exit 1
fi

# ─── Database Type Selection ───
echo -e "${CYAN}Select Database Type:${NC}"
echo "  1) MySQL (default)"
echo "  2) PostgreSQL"
echo ""
read -p "$(echo -e ${CYAN}Select database type [default: 1]:${NC} )" DB_CHOICE
DB_CHOICE="${DB_CHOICE:-1}"

case "$DB_CHOICE" in
    1) DB_TYPE="mysql" ;;
    2) DB_TYPE="pgsql" ;;
    *)
        echo -e "${RED}[ERROR] Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}[OK] Database type: $DB_TYPE${NC}"
echo ""

# ─── Check Database Service ───
echo -e "${YELLOW}[INFO] Checking database service status...${NC}"
if [ "$DB_TYPE" == "mysql" ]; then
    if systemctl is-active --quiet mysql; then
        echo -e "${GREEN}[OK] MySQL is running${NC}"
    else
        echo -e "${RED}[ERROR] MySQL is not running. Please install and start MySQL first.${NC}"
        read -p "$(echo -e ${CYAN}Start MySQL now? [Y/n]:${NC} )" START_DB
        START_DB="${START_DB:-Y}"
        if [[ "$START_DB" =~ ^[Yy]$ ]]; then
            systemctl start mysql
            systemctl enable mysql
            echo -e "${GREEN}[OK] MySQL started and enabled${NC}"
        else
            exit 1
        fi
    fi
else
    if systemctl is-active --quiet postgresql; then
        echo -e "${GREEN}[OK] PostgreSQL is running${NC}"
    else
        echo -e "${RED}[ERROR] PostgreSQL is not running. Please install and start PostgreSQL first.${NC}"
        read -p "$(echo -e ${CYAN}Start PostgreSQL now? [Y/n]:${NC} )" START_DB
        START_DB="${START_DB:-Y}"
        if [[ "$START_DB" =~ ^[Yy]$ ]]; then
            systemctl start postgresql
            systemctl enable postgresql
            echo -e "${GREEN}[OK] PostgreSQL started and enabled${NC}"
        else
            exit 1
        fi
    fi
fi
echo ""

# ─── Database Credentials ───
echo -e "${YELLOW}[INFO] Database Configuration${NC}"
echo ""

read -p "$(echo -e ${CYAN}Enter database name [default: zabbix]:${NC} )" DB_NAME
DB_NAME="${DB_NAME:-zabbix}"

read -p "$(echo -e ${CYAN}Enter database user [default: zabbix]:${NC} )" DB_USER
DB_USER="${DB_USER:-zabbix}"

read -p "$(echo -e ${CYAN}Enter database host [default: localhost]:${NC} )" DB_HOST
DB_HOST="${DB_HOST:-localhost}"

while true; do
    read -sp "$(echo -e ${CYAN}Enter database password for user \"$DB_USER\":${NC} )" DB_PASSWORD
    echo ""
    if [ -z "$DB_PASSWORD" ]; then
        echo -e "${RED}[ERROR] Password cannot be empty${NC}"
        continue
    fi
    read -sp "$(echo -e ${CYAN}Confirm database password:${NC} )" DB_PASSWORD_CONFIRM
    echo ""
    if [ "$DB_PASSWORD" == "$DB_PASSWORD_CONFIRM" ]; then
        break
    else
        echo -e "${RED}[ERROR] Passwords do not match. Please try again.${NC}"
    fi
done
echo ""

read -p "$(echo -e ${CYAN}Enter MySQL root password [enter if none]:${NC} )" MYSQL_ROOT_PASSWORD
echo ""

# ─── Confirmation ───
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Database Setup Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "  Database Type   : ${GREEN}$DB_TYPE${NC}"
echo -e "  Database Name   : ${GREEN}$DB_NAME${NC}"
echo -e "  Database User   : ${GREEN}$DB_USER${NC}"
echo -e "  Database Host   : ${GREEN}$DB_HOST${NC}"
echo -e "  Password        : ${GREEN}********${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
read -p "$(echo -e ${CYAN}Proceed with database setup? [Y/n]:${NC} )" CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[SKIP] Database setup cancelled${NC}"
    exit 0
fi

# ─── MySQL Setup ───
if [ "$DB_TYPE" == "mysql" ]; then
    echo ""
    echo -e "${YELLOW}[STEP 1/4] Creating database and user...${NC}"

    MYSQL_CMD="mysql"
    if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
        MYSQL_CMD="mysql -uroot -p${MYSQL_ROOT_PASSWORD}"
    else
        MYSQL_CMD="mysql -uroot"
    fi

    $MYSQL_CMD <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS '${DB_USER}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${DB_HOST}';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EOF

    echo -e "${GREEN}[OK] Database '${DB_NAME}' and user '${DB_USER}' created${NC}"
    echo ""

    # ─── Import Schema ───
    echo -e "${YELLOW}[STEP 2/4] Importing Zabbix schema...${NC}"
    echo -e "${CYAN}[INFO] This may take a few minutes...${NC}"

    SQL_SCRIPT="/usr/share/zabbix/sql-scripts/mysql/server.sql.gz"
    if [ -f "$SQL_SCRIPT" ]; then
        zcat "$SQL_SCRIPT" | mysql --default-character-set=utf8mb4 -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}"
        echo -e "${GREEN}[OK] Zabbix schema imported successfully${NC}"
    else
        # Try alternative path for newer versions
        SQL_SCRIPT="/usr/share/zabbix-sql-scripts/mysql/server.sql.gz"
        if [ -f "$SQL_SCRIPT" ]; then
            zcat "$SQL_SCRIPT" | mysql --default-character-set=utf8mb4 -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}"
            echo -e "${GREEN}[OK] Zabbix schema imported successfully${NC}"
        else
            echo -e "${RED}[ERROR] Zabbix SQL script not found at expected paths${NC}"
            echo -e "${YELLOW}[INFO] Please import schema manually:${NC}"
            echo -e "${CYAN}  zcat /path/to/server.sql.gz | mysql -u${DB_USER} -p ${DB_NAME}${NC}"
        fi
    fi
    echo ""

    # ─── Disable log_bin_trust_function_creators ───
    echo -e "${YELLOW}[STEP 3/4] Disabling log_bin_trust_function_creators...${NC}"
    $MYSQL_CMD -e "SET GLOBAL log_bin_trust_function_creators = 0;"
    echo -e "${GREEN}[OK] log_bin_trust_function_creators disabled${NC}"
    echo ""

    # ─── Configure Zabbix Server ───
    echo -e "${YELLOW}[STEP 4/4] Configuring Zabbix server...${NC}"
    ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"

    if [ -f "$ZABBIX_CONF" ]; then
        # Backup config
        cp "$ZABBIX_CONF" "${ZABBIX_CONF}.bak"
        echo -e "${GREEN}[OK] Backed up zabbix_server.conf${NC}"

        # Set DBPassword
        if grep -q "^# DBPassword=" "$ZABBIX_CONF"; then
            sed -i "s|^# DBPassword=.*|DBPassword=${DB_PASSWORD}|" "$ZABBIX_CONF"
        elif grep -q "^DBPassword=" "$ZABBIX_CONF"; then
            sed -i "s|^DBPassword=.*|DBPassword=${DB_PASSWORD}|" "$ZABBIX_CONF"
        else
            echo "DBPassword=${DB_PASSWORD}" >> "$ZABBIX_CONF"
        fi

        # Set DBName
        if grep -q "^DBName=" "$ZABBIX_CONF"; then
            sed -i "s|^DBName=.*|DBName=${DB_NAME}|" "$ZABBIX_CONF"
        fi

        # Set DBUser
        if grep -q "^DBUser=" "$ZABBIX_CONF"; then
            sed -i "s|^DBUser=.*|DBUser=${DB_USER}|" "$ZABBIX_CONF"
        fi

        # Set DBHost
        if grep -q "^DBHost=" "$ZABBIX_CONF"; then
            sed -i "s|^DBHost=.*|DBHost=${DB_HOST}|" "$ZABBIX_CONF"
        fi

        echo -e "${GREEN}[OK] Zabbix server configured with database credentials${NC}"
    else
        echo -e "${RED}[ERROR] Zabbix server config not found at $ZABBIX_CONF${NC}"
        echo -e "${YELLOW}[INFO] Please configure DBPassword manually in zabbix_server.conf${NC}"
    fi

# ─── PostgreSQL Setup ───
elif [ "$DB_TYPE" == "pgsql" ]; then
    echo ""
    echo -e "${YELLOW}[STEP 1/4] Creating database and user...${NC}"

    sudo -u postgres psql <<EOF
CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C';
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
EOF

    echo -e "${GREEN}[OK] Database '${DB_NAME}' and user '${DB_USER}' created${NC}"
    echo ""

    echo -e "${YELLOW}[STEP 2/4] Importing Zabbix schema...${NC}"
    SQL_SCRIPT="/usr/share/zabbix/sql-scripts/postgresql/server.sql.gz"
    if [ -f "$SQL_SCRIPT" ]; then
        zcat "$SQL_SCRIPT" | sudo -u ${DB_USER} psql ${DB_NAME}
        echo -e "${GREEN}[OK] Zabbix schema imported successfully${NC}"
    else
        SQL_SCRIPT="/usr/share/zabbix-sql-scripts/postgresql/server.sql.gz"
        if [ -f "$SQL_SCRIPT" ]; then
            zcat "$SQL_SCRIPT" | sudo -u ${DB_USER} psql ${DB_NAME}
            echo -e "${GREEN}[OK] Zabbix schema imported successfully${NC}"
        else
            echo -e "${RED}[ERROR] Zabbix SQL script not found${NC}"
        fi
    fi
    echo ""

    echo -e "${YELLOW}[STEP 3/4] Skipped (PostgreSQL specific)${NC}"
    echo ""

    echo -e "${YELLOW}[STEP 4/4] Configuring Zabbix server...${NC}"
    ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"

    if [ -f "$ZABBIX_CONF" ]; then
        cp "$ZABBIX_CONF" "${ZABBIX_CONF}.bak"
        sed -i "s|^# DBPassword=.*|DBPassword=${DB_PASSWORD}|" "$ZABBIX_CONF"
        echo -e "${GREEN}[OK] Zabbix server configured${NC}"
    else
        echo -e "${RED}[ERROR] Zabbix server config not found${NC}"
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Database Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}[NEXT] Start Zabbix services:${NC}"
echo -e "${CYAN}  sudo bash component/service.sh${NC}"
echo ""

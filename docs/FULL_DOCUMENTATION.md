# 📖 T.Cloud Zabbix Installer — Full Documentation

> **Automated Zabbix 7 Installation for Ubuntu 24.04**
> License By: Terabyte Plus & Brownyroll (BBamz Kittisak Udomsri)

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Project Structure](#project-structure)
4. [Quick Start](#quick-start)
5. [install.sh — Main Menu](#installsh--main-menu)
6. [component/time.sh — NTP & Timezone](#componenttimesh--ntp--timezone)
7. [component/zabbix.sh — Zabbix Installation](#componentzabbixsh--zabbix-installation)
8. [component/database.sh — Database Setup](#componentdatabasesh--database-setup)
9. [component/service.sh — Service Management](#componentservicesh--service-management)
10. [component/ssl.sh — SSL/HTTPS Configuration](#componentsslsh--sslhttps-configuration)
11. [component/fix-apache.sh — Apache Path Fix](#componentfix-apachesh--apache-path-fix)
12. [config/ntp.conf — NTP Template](#configntpconf--ntp-template)
13. [Zabbix 7.2+ Path Change Notes](#zabbix-72-path-change-notes)
14. [Troubleshooting](#troubleshooting)

---

## Overview

T.Cloud Zabbix Installer เป็นชุด Shell Scripts แบบ Interactive สำหรับติดตั้ง Zabbix 7 บน Ubuntu 24.04 โดยอัตโนมัติ ออกแบบเป็นระบบ Menu-driven ที่ให้ผู้ใช้เลือกติดตั้งทั้งหมดในครั้งเดียว (Full Installation) หรือติดตั้งทีละ Module

**ความสามารถหลัก:**
- ตั้งค่า NTP/Timezone (NIMT Thailand)
- ติดตั้ง Zabbix Server, Frontend, Agent
- ตั้งค่า Database (MySQL หรือ PostgreSQL)
- จัดการ Services (start/stop/restart/status)
- ตั้งค่า SSL/HTTPS (Self-signed, Custom cert, Let's Encrypt)
- Fix Apache path สำหรับ Zabbix 7.2+

---

## Requirements

| Item | Version |
|------|---------|
| OS | Ubuntu 24.04 LTS (Noble) |
| Zabbix | 7.0 LTS / 7.4 / 6.4 |
| Database | MySQL หรือ PostgreSQL |
| Web Server | Apache หรือ Nginx |
| Permission | Root (sudo) |

---

## Project Structure

```
tcloud-zabbix/
├── install.sh                 # Entry point — Main menu
├── component/
│   ├── time.sh                # NTP & Timezone setup
│   ├── zabbix.sh              # Zabbix package installation
│   ├── database.sh            # Database creation & schema import
│   ├── service.sh             # Service start/stop/restart/status
│   ├── ssl.sh                 # SSL/HTTPS configuration
│   └── fix-apache.sh          # Apache DocumentRoot fix (Zabbix 7.2+)
├── config/
│   └── ntp.conf               # NTP config template (NIMT Thailand)
├── LICENSE                    # MIT License
└── readme.md                  # Quick-start README
```

---

## Quick Start

```bash
# 1. Install Git
apt install git -y

# 2. Clone
git clone https://github.com/terabyteplus/tcloud-zabbix.git

# 3. Run
cd tcloud-zabbix
sudo bash ./install.sh
```

---

## install.sh — Main Menu

**ไฟล์หลักของ Project** — แสดง ASCII banner และ Menu ให้ผู้ใช้เลือก

### Prerequisites
- ต้องรันด้วย root (`sudo bash install.sh`)

### Menu Options

| Option | Description | เรียก Script |
|--------|-------------|-------------|
| 1 | Full Installation (ทุกขั้นตอน) | เรียก option 7→2→3→4→5 ตามลำดับ |
| 2 | NTP & Timezone Setup | `component/time.sh` |
| 3 | Zabbix Server Installation | `component/zabbix.sh` |
| 4 | Database Setup | `component/database.sh` |
| 5 | Start/Manage Services | `component/service.sh` |
| 6 | SSL/HTTPS Configuration | `component/ssl.sh` |
| 7 | System Update (Security Patches) | ฟังก์ชัน `system_update()` ภายใน |
| 8 | Fix Apache Path (ซ่อนอยู่) | `component/fix-apache.sh` |
| 0 | Exit | ออกจาก Script |

### Option 7 — System Update (Input/Output)

| # | Input | Default | Description |
|---|-------|---------|-------------|
| 1 | Update type (`1` or `2`) | `1` | 1=Security patches only, 2=Full upgrade |
| 2 | Confirm (`Y/n`) | `Y` | ยืนยันก่อนอัปเดต |

| Output | Description |
|--------|-------------|
| `apt update -y` | อัปเดต package list |
| Security patches installed | ถ้าเลือก option 1 |
| Full upgrade complete | ถ้าเลือก option 2 |

### Option 1 — Full Installation Flow

เรียกทุก Module ตามลำดับ:

```
Step 1/5: System Update     → system_update()
Step 2/5: NTP & Timezone    → component/time.sh
Step 3/5: Zabbix Install    → component/zabbix.sh
Step 4/5: Database Setup    → component/database.sh
Step 5/5: Start Services    → component/service.sh
```

| Input | Default | Description |
|-------|---------|-------------|
| Confirm (`Y/n`) | `Y` | ยืนยันก่อน Full Install |

---

## component/time.sh — NTP & Timezone

ตั้งค่า Locale, Timezone และ NTP Service พร้อม NTP Server จาก NIMT Thailand

### Inputs

| # | Input | Default | Description |
|---|-------|---------|-------------|
| 1 | Timezone | `Asia/Bangkok` | Timezone ที่ต้องการ (validate กับ `timedatectl list-timezones`) |
| 2 | Install NTP? (`Y/n`) | `Y` | ถ้า `n` จะข้ามและจบ Script |
| 3 | Extra NTP Server IP | *(skip)* | IP ของ NTP Server เพิ่มเติม (optional) |

### Process Flow

```
1. locale-gen en_US.UTF-8
2. timedatectl set-timezone <TIMEZONE>
3. systemctl stop/disable systemd-timesyncd
4. apt remove systemd-timesyncd
5. apt install ntp
6. เขียน /etc/ntp.conf (NIMT servers + extra)
7. mkdir /var/log/ntpstats
8. Detect service name (ntpsec หรือ ntp)
9. systemctl restart & enable NTP
10. ntpq -p (verify sync)
```

### Outputs / Files Modified

| File | Action |
|------|--------|
| `/etc/ntp.conf` | สร้างใหม่ (backup `.bak` ก่อน) |
| `/etc/ntp.conf.bak` | Backup ของ config เดิม |
| `/var/log/ntpstats/` | สร้าง directory สำหรับ NTP statistics |
| `/var/log/ntp.log` | NTP log file (กำหนดใน config) |

### NTP Config Content ที่สร้าง

```
server time1.nimt.or.th iburst
server time2.nimt.or.th iburst
server time3.nimt.or.th iburst
server time4.nimt.or.th iburst
server <EXTRA_IP> iburst          ← ถ้าใส่ extra IP

driftfile /var/lib/ntp/ntp.drift

restrict default kod nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1

logfile /var/log/ntp.log

statistics loopstats peerstats clockstats
statsdir /var/log/ntpstats/
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable
```

### Services Affected

| Service | Action |
|---------|--------|
| `systemd-timesyncd` | Stop, Disable, Remove |
| `ntpsec` หรือ `ntp` | Restart, Enable |

---

## component/zabbix.sh — Zabbix Installation

ติดตั้ง Zabbix Repository, Packages และ Database Server

### Inputs

| # | Input | Default | Options | Description |
|---|-------|---------|---------|-------------|
| 1 | Zabbix Version | `1` (7.4) | 1=7.4, 2=7.0 LTS, 3=6.4, 4=Custom | เวอร์ชัน Zabbix |
| 2 | Ubuntu Version | Auto-detect | ค่า `VERSION_ID` | เวอร์ชัน Ubuntu สำหรับ Repository |
| 3 | Database Type | `1` (MySQL) | 1=MySQL, 2=PostgreSQL | ประเภท Database |
| 4 | Web Server | `1` (Apache) | 1=Apache, 2=Nginx | Web Server |
| 5 | Install Server? | `Y` | `Y/n` | ติดตั้ง Zabbix Server |
| 6 | Install Frontend? | `Y` | `Y/n` | ติดตั้ง Zabbix Frontend |
| 7 | Install Agent? | `Y` | `Y/n` | ติดตั้ง Zabbix Agent |
| 8 | Confirm | `Y` | `Y/n` | ยืนยันก่อนติดตั้ง |
| 9 | Install DB Server? | `Y` | `Y/n` | ติดตั้ง DB Server บนเครื่องนี้ |

### Process Flow (5 Steps)

```
Step 1/5: apt update
Step 2/5: Fix dpkg excludes (เพิ่ม zabbix exception)
Step 3/5: Download & install Zabbix repository .deb
Step 4/5: Install selected Zabbix packages
Step 5/5: Install database server (MySQL/PostgreSQL)
```

### Packages Installed (ขึ้นกับ Input)

| Condition | Packages |
|-----------|----------|
| Server + MySQL | `zabbix-server-mysql zabbix-sql-scripts` |
| Server + PostgreSQL | `zabbix-server-pgsql zabbix-sql-scripts` |
| Frontend + Apache | `zabbix-frontend-php zabbix-apache-conf` |
| Frontend + Nginx | `zabbix-frontend-php zabbix-nginx-conf` |
| Agent | `zabbix-agent` |
| DB Server (MySQL) | `mysql-server` |
| DB Server (PostgreSQL) | `postgresql postgresql-contrib` |

### Repository URL Pattern

```
https://repo.zabbix.com/zabbix/<VERSION>/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_<VERSION>+ubuntu<UBUNTU_VER>_all.deb
```

### Outputs / Files Modified

| File | Action |
|------|--------|
| `/etc/dpkg/dpkg.cfg.d/excludes` | เพิ่ม `path-include=/usr/share/doc/zabbix*` |
| `/tmp/zabbix-release.deb` | ดาวน์โหลดแล้วลบ |

---

## component/database.sh — Database Setup

สร้าง Database, User, Import Schema และตั้งค่า `zabbix_server.conf`

### Inputs

| # | Input | Default | Description |
|---|-------|---------|-------------|
| 1 | Database Type | `1` (MySQL) | 1=MySQL, 2=PostgreSQL |
| 2 | Start DB? (ถ้าไม่ running) | `Y` | Start database service |
| 3 | Database Name | `zabbix` | ชื่อ Database |
| 4 | Database User | `zabbix` | ชื่อ User |
| 5 | Database Host | `localhost` | Host address |
| 6 | Database Password | *(required)* | รหัสผ่าน (ใส่ 2 ครั้งเพื่อ confirm) |
| 7 | MySQL Root Password | *(empty=none)* | เฉพาะ MySQL |
| 8 | Confirm | `Y` | ยืนยันก่อนทำงาน |

### Process Flow — MySQL (4 Steps)

```
Step 1/4: สร้าง Database & User
  → CREATE DATABASE <name> CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
  → CREATE USER '<user>'@'<host>' IDENTIFIED BY '<password>'
  → GRANT ALL PRIVILEGES
  → SET GLOBAL log_bin_trust_function_creators = 1

Step 2/4: Import Zabbix Schema
  → zcat server.sql.gz | mysql ...
  → ลอง path: /usr/share/zabbix-sql-scripts/mysql/server.sql.gz
  → fallback: /usr/share/zabbix/sql-scripts/mysql/server.sql.gz

Step 3/4: SET GLOBAL log_bin_trust_function_creators = 0

Step 4/4: Configure zabbix_server.conf
  → DBPassword, DBName, DBUser, DBHost
```

### Process Flow — PostgreSQL (4 Steps)

```
Step 1/4: สร้าง Database & User
  → CREATE USER <user> WITH PASSWORD '<password>'
  → CREATE DATABASE <name> OWNER <user> TEMPLATE template0 ENCODING UTF8

Step 2/4: Import Schema
  → zcat server.sql.gz | psql
  → ลอง path: /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz
  → fallback: /usr/share/zabbix/sql-scripts/postgresql/server.sql.gz

Step 3/4: (Skipped for PostgreSQL)

Step 4/4: Configure zabbix_server.conf → DBPassword
```

### Outputs / Files Modified

| File | Action |
|------|--------|
| `/etc/zabbix/zabbix_server.conf` | แก้ไข DBPassword, DBName, DBUser, DBHost |
| `/etc/zabbix/zabbix_server.conf.bak` | Backup ของ config เดิม |
| Database `zabbix` | สร้าง Database + User + Import Schema |

---

## component/service.sh — Service Management

จัดการ Services ทั้งหมดของ Zabbix (start/stop/restart/status)

### Inputs

| # | Input | Default | Options | Description |
|---|-------|---------|---------|-------------|
| 1 | Web Server | `1` (Apache) | 1=Apache, 2=Nginx | เลือก Web Server ที่ติดตั้ง |
| 2 | Action | `1` (Start) | 1=Start & Enable, 2=Restart, 3=Stop, 4=Status | การกระทำ |

### Services Managed

| Service Name | Description |
|-------------|-------------|
| `zabbix-server` | Zabbix Server process |
| `zabbix-agent` | Zabbix Agent process |
| `apache2` หรือ `nginx` | Web Server (ขึ้นกับ Input) |

### Outputs

| Output | Condition |
|--------|-----------|
| Service status table (●/● active/inactive) | ทุกกรณี |
| Server IP + Access URL + Default credentials | เมื่อ Start หรือ Restart |

### Access Info (แสดงเมื่อ Start/Restart)

```
Access Zabbix Web UI:
  http://<SERVER_IP>/zabbix

Default Credentials:
  Username: Admin
  Password: zabbix
```

---

## component/ssl.sh — SSL/HTTPS Configuration

ตั้งค่า HTTPS สำหรับ Zabbix Web UI — รองรับ 3 รูปแบบ

### Inputs (ส่วนกลาง)

| # | Input | Default | Description |
|---|-------|---------|-------------|
| 1 | SSL Type | `1` | 1=Self-signed, 2=Custom cert, 3=Let's Encrypt |
| 2 | Server Domain Name | *(required)* | เช่น `zabbix.example.com` |

### Option 1: Self-Signed Certificate — Inputs

| # | Input | Default | Description |
|---|-------|---------|-------------|
| 3 | Certificate validity (days) | `3650` | อายุ Certificate |
| 4 | Organization name | `T.Cloud` | ชื่อองค์กร |
| 5 | Country code | `TH` | รหัสประเทศ |
| 6 | IP addresses (loop) | *(enter to finish)* | IP สำหรับ SAN — ใส่ได้หลาย IP |

**Certificate Subject:**
```
/C=<COUNTRY>/O=<ORG>/OU=T.Cloud Gen3/CN=<SERVER_NAME>
```

**SAN (Subject Alternative Name):**
```
DNS:<SERVER_NAME>,IP:<IP1>,IP:<IP2>,...
```

### Option 2: Custom Certificate — Inputs

| # | Input | Default | Description |
|---|-------|---------|-------------|
| 3 | Path to `.crt` file | *(required)* | Certificate file path |
| 4 | Path to `.key` file | *(required)* | Private key file path |

### Option 3: Let's Encrypt — Inputs

| # | Input | Default | Description |
|---|-------|---------|-------------|
| 3 | Email | *(required)* | Email สำหรับ Let's Encrypt |

**Packages installed:** `certbot python3-certbot-apache`

### Common Inputs (Option 1 & 2)

| # | Input | Default | Description |
|---|-------|---------|-------------|
| Last | Enable HTTP→HTTPS redirect? | `Y` | Redirect port 80 → 443 |

### Outputs / Files Modified

| File | Action |
|------|--------|
| `/etc/httpd/ssl/` | สร้าง directory |
| `/etc/httpd/ssl/private/` | สร้าง directory (chmod 700) |
| `/etc/httpd/ssl/server.crt` | Certificate file (Self-signed) |
| `/etc/httpd/ssl/private/private_key.key` | Private key (Self-signed) |
| `/etc/apache2/sites-available/default-ssl.conf` | สร้างใหม่ (backup `.bak`) |
| `/etc/apache2/sites-available/default-ssl.conf.bak` | Backup |
| `/etc/apache2/sites-available/000-default.conf` | แก้ไข redirect (backup `.bak`) |

### Apache Config ที่สร้าง

**default-ssl.conf:**
```apache
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin webmaster@<SERVER_NAME>
        ServerName <SERVER_NAME>
        DocumentRoot /usr/share/zabbix

        SSLEngine on
        SSLCertificateFile      <CERT_FILE>
        SSLCertificateKeyFile   <KEY_FILE>
    </VirtualHost>
</IfModule>
```

**000-default.conf (ถ้า enable redirect):**
```apache
<VirtualHost *:80>
    DocumentRoot "/usr/share/zabbix"
    ServerName <SERVER_NAME>
    Redirect permanent / https://<SERVER_NAME>/
</VirtualHost>
```

### Apache Modules Enabled
- `ssl` (via `a2enmod ssl`)
- `default-ssl` site (via `a2ensite default-ssl`)

---

## component/fix-apache.sh — Apache Path Fix

**สำหรับ Zabbix 7.2+ เท่านั้น** — แก้ไข DocumentRoot จาก `/usr/share/zabbix` เป็น `/usr/share/zabbix/ui`

### Inputs

| # | Input | Default | Description |
|---|-------|---------|-------------|
| 1 | Apply fix? (`Y/n`) | `Y` | ยืนยัน (ถามเฉพาะเมื่อพบ old path) |

### Logic Flow

```
1. ตรวจ /etc/apache2/conf-available/zabbix.conf มีหรือไม่
   → ไม่มี = SKIP (ไม่ใช่ Zabbix 7.2+)

2. ตรวจว่ามี /usr/share/zabbix/ui อยู่แล้วหรือไม่
   → มีแล้ว = ไม่ต้อง fix

3. ตรวจว่ามี /usr/share/zabbix (old path) หรือไม่
   → มี = ถาม confirm แล้ว sed replace
```

### Outputs / Files Modified

| File | Action |
|------|--------|
| `/etc/apache2/conf-available/zabbix.conf` | `sed -i 's:/usr/share/zabbix:/usr/share/zabbix/ui:g'` |
| `/etc/apache2/conf-available/zabbix.conf.bak` | Backup ก่อนแก้ |

---

## config/ntp.conf — NTP Template

Template file สำหรับ reference (ไม่ได้ถูกเรียกใช้โดยตรง — `time.sh` สร้าง config เอง)

### NTP Servers (NIMT Thailand)

| Server | Description |
|--------|-------------|
| `time1.nimt.or.th` | NIMT Primary |
| `time2.nimt.or.th` | NIMT Secondary |
| `time3.nimt.or.th` | NIMT Tertiary |
| `time4.nimt.or.th` | NIMT Quaternary |

### Restrictions

| Rule | Description |
|------|-------------|
| `restrict default kod nomodify nopeer noquery limited` | Default restriction |
| `restrict 127.0.0.1` | Allow localhost |
| `restrict ::1` | Allow IPv6 localhost |

---

## Zabbix 7.2+ Path Change Notes

ตั้งแต่ Zabbix 7.2 เป็นต้นไป PHP frontend ย้ายจาก:
- **เดิม:** `/usr/share/zabbix`
- **ใหม่:** `/usr/share/zabbix/ui`

### ต้องแก้ 2 ไฟล์ (ถ้าตั้ง SSL ด้วยมือ):

**1. `/etc/apache2/sites-available/000-default.conf`**
```diff
-    DocumentRoot "/usr/share/zabbix"
+    DocumentRoot "/usr/share/zabbix/ui"
```

**2. `/etc/apache2/sites-available/default-ssl.conf`**
```diff
-        DocumentRoot /usr/share/zabbix/
+        DocumentRoot /usr/share/zabbix/ui
```

> ใช้ Option 8 (fix-apache.sh) เพื่อแก้อัตโนมัติสำหรับ `zabbix.conf`

---

## Troubleshooting

### NTP ไม่ Sync
```bash
# ตรวจสถานะ
systemctl status ntpsec
ntpq -p

# Restart
systemctl restart ntpsec
```

### Zabbix Frontend ไม่ขึ้น (7.2+)
```bash
# ตรวจ DocumentRoot
grep -r "DocumentRoot" /etc/apache2/sites-available/
# ถ้าเป็น /usr/share/zabbix → ต้องเปลี่ยนเป็น /usr/share/zabbix/ui
sudo bash component/fix-apache.sh
```

### Database Connection Error
```bash
# ตรวจ zabbix_server.conf
grep -E "^DB" /etc/zabbix/zabbix_server.conf

# ตรวจ MySQL
systemctl status mysql
mysql -uzabbix -p zabbix -e "SELECT 1"
```

### SSL Certificate ไม่ Valid
```bash
# ดูรายละเอียด cert
openssl x509 -in /etc/httpd/ssl/server.crt -noout -text

# ตรวจ Apache SSL
apachectl -t
systemctl restart apache2
```

---

## Summary — All Files Modified by Scripts

| Script | Files Created/Modified |
|--------|----------------------|
| `time.sh` | `/etc/ntp.conf`, `/etc/ntp.conf.bak`, `/var/log/ntpstats/` |
| `zabbix.sh` | `/etc/dpkg/dpkg.cfg.d/excludes` |
| `database.sh` | `/etc/zabbix/zabbix_server.conf`, `/etc/zabbix/zabbix_server.conf.bak` |
| `ssl.sh` | `/etc/httpd/ssl/server.crt`, `/etc/httpd/ssl/private/private_key.key`, `/etc/apache2/sites-available/default-ssl.conf`, `/etc/apache2/sites-available/000-default.conf` |
| `fix-apache.sh` | `/etc/apache2/conf-available/zabbix.conf` |

---

## References

- [Zabbix Download](https://www.zabbix.com/download?zabbix=7.0&os_distribution=ubuntu&os_version=24.04&components=server_frontend_agent&db=mysql&ws=apache)
- [Zabbix 7.2 Upgrade Notes](https://www.zabbix.com/documentation/current/en/manual/installation/upgrade_notes_720)
- [NIMT Thailand NTP](https://www.nimt.or.th/)

---

*📄 MIT License — Terabyte Plus*

# Squid Proxy Server

A simple, robust Squid proxy server that only allows access to whitelisted domains for HTTP and HTTPS traffic.  
Includes automated setup script, config, and whitelist management.

---

## 📂 Repository Structure
```bash
squid-proxy/
├── setup-squid-proxy.sh      # Setup script to automate installation & config
├── squid.conf                # Robust Squid configuration
└── whitelist.txt             # Allowed domains (one per line)
```

---

## ⚙️  Features

- Whitelist-based proxy for HTTP & HTTPS  
- Access control via ACLs  
- Cache optimization for APT repos and large downloads  
- Easy whitelist updates without restarting Squid  
- One-command deployment via setup script  

---

## 🖼️ How It Works

```bash
Client (HTTP/HTTPS)
       |
       v
  Squid Proxy (ACL + Whitelist)
       |
       v
  Allowed Domains (Internet)
       |
       v
  Response back to Client
```
> **HTTP requests** are filtered via `dstdomain` ACL.  
> **HTTPS requests** use `CONNECT` and are allowed only for **whitelisted domains**.

---

## 1️⃣  Source Networks in `squid.conf`
The provided `squid.conf` already defines these source networks:
```bash
acl localhost src 127.0.0.1/32 ::1
acl lan1 src 192.168.12.0/24
acl lan2 src 172.29.236.0/24
```
➡️  If you are using different networks, edit these lines in `squid.conf` before running the setup script.
The setup script will then deploy the modified configuration into:
```bash
/etc/squid/squid.conf
```

---

## 2️⃣  Whitelist Management
Edit `whitelist.txt` to add or remove allowed domains:
```bash
archive.ubuntu.com
security.ubuntu.com
pypi.org
.launchpad.net
.ubuntu.com
```
This Whitelist.txt could be modified later in `/etc/squid/whitelist.txt` after running the script. 
After modifying reload Squid to apply changes: 
```bash
sudo systemctl reload squid
```

---

## 3️⃣  Install & Setup
Make the setup script executable and run it:
```bash
cd squid-proxy
chmod +x setup-squid-proxy.sh
sudo ./setup-squid-proxy.sh
```
**What the setup script does:**

1. Installs Squid proxy server if not already installed  
2. Backs up any existing `squid.conf` to `squid.conf.backup`  
3. Deploys the provided `squid.conf` configuration  to `/etc/squid/`
4. Copies `whitelist.txt` to `/etc/squid/`  
5. Initializes Squid cache directories using `squid -z`  
6. Restarts and enables the Squid service to start on boot

---

### 4️⃣  Configure APT Clients
Create `/etc/apt/apt.conf.d/01proxy` with the following content:
```bash
Acquire::http::Proxy "http://<proxy-ip>:3128";
Acquire::https::Proxy "http://<proxy-ip>:3128";
```

---

### 5️⃣  Testing
**HTTP Test (allowed site):**
```bash
curl -v -x http://<proxy-ip>:3128 http://archive.ubuntu.com/
```
**HTTPS Test (CONNECT to allowed site):**
```bash
curl -v -x http://<proxy-ip>:3128 https://pypi.org
```
**Blocked site (should fail):**
```bash
curl -v -x http://<proxy-ip>:3128 http://example.com/
```
**Monitor Squid logs:**
```bash
sudo tail -f /var/log/squid/access.log
```

---
 
### 6️⃣  Firewall Considerations
> Note: During the Squid installation, the `ufw` service was either stopped, disabled, or inactive. Ensure your firewall rules allow traffic to Squid if you enable it later.
Check status of `ufw` service:

```bash
systemctl status ufw
```

---

### 7️⃣  Monitoring & Troubleshooting

**View Squid logs:**

```bash
sudo tail -f /var/log/squid/access.log /var/log/squid/cache.log
```
**Check cache and Squid stats:**
```bash
squidclient -h localhost -p 3128 mgr:info
```
**Rebuild cache if corrupted:**
```bash
sudo systemctl stop squid
sudo squid -z
sudo systemctl start squid
```
**Search for denied requests:**
```bash
grep DENIED /var/log/squid/access.log
```

---

### 8️⃣  Quick Checklist

- Clone the repository
- Run `setup-squid-proxy.sh` as root
- Verify `squid.conf` and `whitelist.txt`
- Reload Squid after whitelist updates
- Configure clients to use `http://<proxy-ip>:3128`

---

### 9️⃣  Notes

- ACLs are processed top-down, so order in `squid.conf` matters.
- `dstdomain` works for HTTP and HTTPS (CONNECT).
- Cache settings (`cache_mem`, `cache_dir`) can be tuned according to server resources.
- Use `tail -f /var/log/squid/access.log` to monitor requests.


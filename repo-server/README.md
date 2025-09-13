# Ubuntu Mirror Setup with Nginx

This repository helps you set up a **local Ubuntu package mirror** and expose it with **Nginx**, so clients can fetch packages directly without relying on the internet.  
This is useful for **air-gapped environments**, faster installations, or local control over package updates.

---

## Requirements

- An Ubuntu server (22.04 Jammy or 24.04 Noble) with sufficient disk space:  
- ~1–1.5 TB if mirroring `main, restricted, universe, multiverse` + `updates, security, backports` for `amd64`.  
- More space if mirroring additional architectures like `arm64`.  
- Outbound rsync/HTTP(S) access to an upstream Ubuntu mirror (or access to a staging host if air-gapped).  
- A hostname (e.g. `repo-server.td2.com`) resolvable via DNS or `/etc/hosts`.

---

## Step 1 — Install prerequisites

```bash
sudo apt update
sudo apt install -y debmirror rsync gnupg ubuntu-keyring nginx
```

---

## Step 2 — Create mirror location

```bash
sudo mkdir -p /srv/mirror
sudo chown -R $USER:$USER /srv/mirror
```
---

## Step 3 — Mirror script (Start a tmux session before running the mirror script)

```bash
sudo install -m 0755 ubuntu-mirror.sh /usr/local/sbin/ubuntu-mirror.sh
/usr/local/sbin/ubuntu-mirror.sh
```
Run manually or schedule with cron:
```bash
0 3 * * * /usr/local/sbin/ubuntu-mirror.sh >> /var/log/ubuntu-mirror.log 2>&1
```

---

## Step 4 — Install and configure Nginx

We provide a helper script `setup-nginx-repo.sh` which:

- Installs Nginx
- Prompts you for `server_name` (e.g., `repo-server.td2.com`) and `mirror_root` (e.g., `/srv/mirror/ubuntu`)
- Creates the site configuration in `/etc/nginx/sites-available/`
- Enables and reloads Nginx
- Generates `sources.list` templates for clients

### Run the script

```bash
chmod +x setup-nginx-repo.sh
./setup-nginx-repo.sh
```
When complete, your mirror will be served at:

```bash
http://<your-server-name>/
```
---

## Step 5 — Configure clients

On a client system:

### For Jammy (22.04)

```bash
sudo cp $HOME/sources.list.jammy /etc/apt/sources.list
sudo apt update
```

### For Noble (24.04)

```bash
sudo cp $HOME/sources.list.noble /etc/apt/sources.list
sudo apt update
```

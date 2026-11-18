# Project Zomboid Dedicated Server — Linux VPS (DigitalOcean, Ubuntu 24.04)

Private server for 4 friends (Windows + Mac clients), Build 42.21, `-nosteam` mode so GOG copies can join.

---

## 0. Create the Droplet

- **Image:** Ubuntu 24.04 LTS x64
- **Size:** Basic → Premium AMD (or Regular) → **4 vCPU / 8 GB RAM** (see README notes on sizing)
- **Region:** the datacenter closest to *all* players (lowest average ping)
- **Authentication:** SSH key (not password)

SSH in from your Mac:

```bash
ssh root@YOUR_DROPLET_IP
```

## 1. Prepare the system

```bash
apt update && apt upgrade -y
apt install -y lib32gcc-s1 curl tar ufw

# Dedicated user — never run the game server as root
adduser --disabled-password --gecos "" pz

# 2 GB swap as a safety net against out-of-memory crashes
fallocate -l 2G /swapfile && chmod 600 /swapfile
mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

## 2. Firewall

```bash
ufw allow OpenSSH
ufw allow 16261/udp
ufw allow 16262/udp
ufw enable
ufw status
```

Optional: in DigitalOcean → Networking → Firewalls, create the same rules and restrict SSH (22/tcp) to your own IP.

## 3. Install SteamCMD and the server (as `pz`)

```bash
su - pz

mkdir -p ~/steamcmd && cd ~/steamcmd
curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

./steamcmd.sh +force_install_dir /home/pz/pzserver +login anonymous \
  +app_update 380870 -beta 42.21 validate +quit
```

> If SteamCMD says the branch doesn't exist, list the real branch names with
> `./steamcmd.sh +login anonymous +app_info_print 380870 +quit` and look under `branches`.
> The server version **must equal** the version all 4 players run.

## 4. Set the RAM limit

Edit `/home/pz/pzserver/ProjectZomboid64.json` and change the `-Xmx` value inside `vmArgs`:

```json
"-Xmx6g",
```

Rule of thumb: droplet RAM minus 2 GB (8 GB droplet → `-Xmx6g`).

## 5. First run — set admin password

```bash
cd ~/pzserver
./start-server.sh -nosteam
```

Enter an admin password when prompted. Wait for `SERVER STARTED` and confirm the log shows `42.21`. Then type:

```text
quit
```

## 6. Make it private

```bash
nano ~/Zomboid/Server/servertest.ini
```

Change these lines (join password must differ from the admin password):

```ini
Public=false
Password=your-friends-password
MaxPlayers=8
```

Optional, stricter: set `Open=false` and create accounts yourself later with
`adduser "name" "password"` (see step 8 for sending commands).

Save with **Ctrl+O, Enter, Ctrl+X**, then `exit` back to root.

## 7. Run as a service (auto-start, auto-restart, clean shutdown)

As **root**, create `/etc/systemd/system/pzserver.socket`:

```ini
[Unit]
BindsTo=pzserver.service

[Socket]
ListenFIFO=/home/pz/pzserver.control
FileDescriptorName=control
RemoveOnStop=true
SocketMode=0660
SocketUser=pz
```

Create `/etc/systemd/system/pzserver.service`:

```ini
[Unit]
Description=Project Zomboid Server
After=network.target

[Service]
User=pz
Group=pz
WorkingDirectory=/home/pz/pzserver
Sockets=pzserver.socket
StandardInput=socket
StandardOutput=journal
StandardError=journal
ExecStart=/home/pz/pzserver/start-server.sh -nosteam
ExecStop=/bin/sh -c "echo save > /home/pz/pzserver.control; sleep 15; echo quit > /home/pz/pzserver.control"
KillSignal=SIGCONT
TimeoutStopSec=90
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
systemctl daemon-reload
systemctl enable --now pzserver
journalctl -u pzserver -f      # watch the log; Ctrl+C to stop watching
```

## 8. Everyday commands

```bash
systemctl status pzserver                 # is it running?
systemctl restart pzserver                # restart (saves first)
systemctl stop pzserver                   # stop (saves first)
journalctl -u pzserver -n 200             # last 200 log lines

# Send console commands to the running server:
echo 'servermsg "Restart in 5 minutes"' > /home/pz/pzserver.control
echo 'players' > /home/pz/pzserver.control
echo 'adduser "friendname" "theirpassword"' > /home/pz/pzserver.control
```

Output of these commands appears in `journalctl -u pzserver`.

## 9. Daily backup + daily restart

As root, run `crontab -e` and add:

```cron
# 05:00 save the world, then archive it (keeps the last 7 days)
0 5 * * * echo save > /home/pz/pzserver.control && sleep 30 && mkdir -p /home/pz/backups && tar czf /home/pz/backups/pz-$(date +\%F).tar.gz -C /home/pz Zomboid/Saves/Multiplayer Zomboid/Server Zomboid/db && find /home/pz/backups -name 'pz-*.tar.gz' -mtime +7 -delete

# 05:10 restart to clear memory creep
10 5 * * * systemctl restart pzserver
```

Copy a backup to your Mac occasionally:

```bash
scp root@YOUR_DROPLET_IP:/home/pz/backups/pz-*.tar.gz ~/Downloads/
```

## 10. Updating the game version

Only update when **all 4 players** are ready to update too.

```bash
systemctl stop pzserver
su - pz -c "~/steamcmd/steamcmd.sh +force_install_dir /home/pz/pzserver +login anonymous +app_update 380870 -beta NEW_BRANCH validate +quit"
systemctl start pzserver
```

Re-check `-Xmx` in `ProjectZomboid64.json` afterwards — updates can reset it.

## 11. How friends join (Windows and Mac)

1. All on the **same game version** as the server (GOG Galaxy: disable auto-update, pick the matching version).
2. Steam owners: add `-nosteam` to the game's launch options.
3. Main Menu → **Join** → add server:
   - IP: `YOUR_DROPLET_IP`
   - Port: `16261`
   - Server password: the join password
   - Username/password: anything they choose (becomes their account on first join)

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Version mismatch" | Client and server builds differ — align versions |
| Connection timed out | `ufw status` shows 16261/16262 udp? DO cloud firewall too? Service running? |
| Server crashes / killed | `journalctl -u pzserver` — if OutOfMemory, lower `-Xmx` or upsize droplet |
| Steam player can't join | They forgot `-nosteam` in launch options |
| Lag with 4 players | Upgrade to CPU-Optimized droplet or pick a closer region |

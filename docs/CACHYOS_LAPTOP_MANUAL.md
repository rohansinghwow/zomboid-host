# Project Zomboid Server — Home Laptop (CachyOS) behind a Jio router

Host: 4-core i7 11th gen laptop, 512 GB SSD, CachyOS. Players: 4 friends (2 Windows, 2 Mac).
Build 42.21, `-nosteam` mode so GOG copies can join.

---

## 0. First decide HOW friends reach you (Jio CGNAT check)

Jio connections (especially AirFiber, often JioFiber too) are frequently behind **CGNAT**.
That means you do **not** have your own public IPv4 address, so **port forwarding will not work**
no matter what you set in the router.

**Check:**

1. Open the router page: `http://192.168.29.1` → log in → find the **WAN IPv4 address**.
2. On the laptop, run: `curl -4 ifconfig.me`
3. Compare:
   - **Same address** → you have a public IP. Use **Option B (port forward)**.
   - **Different**, or the WAN IP starts with `100.64.`–`100.127.` or `10.` → **CGNAT**. Use **Option A (Tailscale)**.

| Option | Works with CGNAT | Friends install anything | Exposed to internet | Recommendation |
|---|---|---|---|---|
| **A. Tailscale** (private VPN) | Yes | Yes, Tailscale app (Win/Mac) | No | **Best for 4 friends** |
| B. Router port forward | No | No | Yes | Only if you have a public IP |
| C. playit.gg tunnel | Yes | No | Yes | Fallback (port remapping can break PZ's 2nd port) |

---

## 1. Prepare the laptop

### Keep it awake with the lid closed

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/no-lid-sleep.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
sudo systemctl restart systemd-logind

# Block sleep/hibernate entirely while it's a server
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

Also: keep it **plugged in**, on a hard surface (cooling), and if possible use an **Ethernet cable** to the Jio router instead of Wi-Fi. Wi-Fi works but gives more lag spikes.

### Packages

CachyOS has the multilib repo enabled by default.

```bash
sudo pacman -Syu
sudo pacman -S --needed lib32-gcc-libs curl tar ufw tmux

# Dedicated user — don't run the server as your normal account or root
sudo useradd -m -s /bin/bash pz
```

---

## 2. Install SteamCMD and the server (as `pz`)

```bash
sudo -iu pz

mkdir -p ~/steamcmd && cd ~/steamcmd
curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

./steamcmd.sh +force_install_dir /home/pz/pzserver +login anonymous \
  +app_update 380870 -beta 42.21 validate +quit
```

> If the branch doesn't exist, list real names with
> `./steamcmd.sh +login anonymous +app_info_print 380870 +quit` (look under `branches`).
> Server version **must equal** every player's game version.

### RAM limit

Check total RAM with `free -h`. Edit `/home/pz/pzserver/ProjectZomboid64.json`, change `-Xmx` in `vmArgs`:

| Laptop RAM | Only hosting | Hosting **and** you play on the same laptop |
|---|---|---|
| 8 GB | `-Xmx4g` (tight) | Not recommended |
| 16 GB | `-Xmx8g` | `-Xmx6g` |
| 32 GB | `-Xmx10g` | `-Xmx8g` |

### First run — admin password

```bash
cd ~/pzserver
./start-server.sh -nosteam
```

Set the admin password, wait for `SERVER STARTED` and confirm `42.21` in the log, then type `quit`.

### Make it private

```bash
nano ~/Zomboid/Server/servertest.ini
```

```ini
Public=false
Password=your-friends-password
MaxPlayers=8

# Auto-save the whole world every 10 minutes (0 = off)
SaveWorldEveryMinutes=10

# Built-in backups (stored in ~/Zomboid/backups)
BackupsCount=5
BackupsOnStart=true
BackupsOnVersionChange=true
BackupsPeriod=60
```

If any of these lines don't exist yet, add them; if they already exist, change the value in place (don't duplicate).

**This laptop (16 GB):** set `-Xmx8g` if only hosting, `-Xmx6g` if you also play on it.

Save (Ctrl+O, Enter, Ctrl+X) and `exit` back to your normal user.

---

## 3. Run as a service

`/etc/systemd/system/pzserver.socket`:

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

`/etc/systemd/system/pzserver.service`:

```ini
[Unit]
Description=Project Zomboid Server
After=network-online.target
Wants=network-online.target

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

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pzserver
journalctl -u pzserver -f
```

Send console commands:

```bash
echo 'players' | sudo tee /home/pz/pzserver.control
echo 'servermsg "Restarting in 5 min"' | sudo tee /home/pz/pzserver.control
```

Tip: if you don't want it running 24/7, skip `enable` and just `sudo systemctl start pzserver` before a session and `stop` after.

---

## 4. Firewall (laptop)

```bash
sudo ufw allow 16261/udp
sudo ufw allow 16262/udp
sudo ufw enable
sudo ufw status
```

---

## 5A. Tailscale — recommended (works even with Jio CGNAT)

On the laptop:

```bash
sudo pacman -S tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up            # opens a login link
tailscale ip -4              # your server IP, looks like 100.x.y.z
```

Allow game traffic over Tailscale through the firewall:

```bash
sudo ufw allow in on tailscale0
```

Friends:

1. Install Tailscale (Windows / macOS) from tailscale.com and sign in with their own account.
2. In your Tailscale admin console → **Machines** → your laptop → **Share…** → invite each friend's email.
   (Or invite them as users to your tailnet; sharing a single machine is the more private choice.)
3. In Zomboid they connect to the **`100.x.y.z`** address, port `16261`.

Nothing on the Jio router needs to change, and the server isn't visible to the public internet.

## 5B. Router port forward — only if you have a real public IP

1. Give the laptop a fixed local IP: router page → LAN / DHCP → **reserve** an address (e.g. `192.168.29.50`) for the laptop's MAC.
2. Router → **Security / NAT → Port Forwarding** (menu name varies by Jio model) → add:
   - UDP `16261` → `192.168.29.50:16261`
   - UDP `16262` → `192.168.29.50:16262`
3. Friends connect to the output of `curl -4 ifconfig.me`, port `16261`.
4. Jio public IPs usually **change** after router restarts. Use a free DDNS (e.g. DuckDNS) or re-check the IP each session.

## 5C. playit.gg — fallback

Install `playit` (AUR: `paru -S playit-bin`), run it, claim the agent via the printed link,
and create a **UDP** tunnel to local port `16261` (and one for `16262`).
Friends connect to the address/port playit gives you. Because playit assigns its own public ports,
PZ may fail to connect if the two ports don't line up; use Tailscale if that happens.

---

## 6. Backups

As root (`sudo crontab -e`):

```cron
0 5 * * * echo save > /home/pz/pzserver.control && sleep 30 && mkdir -p /home/pz/backups && tar czf /home/pz/backups/pz-$(date +\%F).tar.gz -C /home/pz Zomboid/Saves/Multiplayer Zomboid/Server Zomboid/db && find /home/pz/backups -name 'pz-*.tar.gz' -mtime +7 -delete
```

CachyOS may not ship a cron daemon. If `crontab` is missing: `sudo pacman -S cronie && sudo systemctl enable --now cronie`.

---

## 7. How friends join (Windows and Mac)

1. Same game version as the server (turn off auto-update in GOG Galaxy / Steam).
2. Steam owners: add `-nosteam` to launch options.
3. Main Menu → **Join** → add server:
   - IP: Tailscale `100.x.y.z` (5A) or your public IP (5B)
   - Port: `16261`
   - Server password: the join password
   - Username/password: anything they choose (becomes their account)

**You (the host) on the same laptop:** connect to `127.0.0.1`, port `16261`.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Friends time out, port forward set | Probably CGNAT — redo step 0, switch to Tailscale |
| Tailscale friends time out | `sudo ufw allow in on tailscale0`; can they `ping 100.x.y.z`? |
| Version mismatch | Align client and server versions |
| Server stops when lid closes | Re-check step 1 logind config, `systemctl status sleep.target` should be masked |
| Lag spikes | Use Ethernet, lower `-Xmx` if you also play, check laptop temps (`sensors`) |
| Crash / OutOfMemory | `journalctl -u pzserver` — adjust `-Xmx` |

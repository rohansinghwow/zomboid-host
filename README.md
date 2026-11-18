# 🧟 Zomboid Host — Project Zomboid server app for Debian 13

One app that turns a **Debian 13** laptop (Ubuntu and Arch also work) into a private **Project Zomboid Build 42** server
for 4 friends (Windows + Mac), even behind a **Jio router with CGNAT**.

It asks permission once, then does everything: installs the server, keeps the laptop awake,
opens the firewall, sets up Tailscale, tunes the network for low ping, auto-saves, backs up daily,
and shows the exact info your friends type into the game.
If anything fails it can send a detailed, password-free error report to GitHub so it can be fixed.

---

## For the host (the Debian laptop)

### 1. Install (one time)

Open a terminal and run:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/rohansinghwow/zomboid-host.git ~/zomboid-host
cd ~/zomboid-host
./install.sh
```

> **"user is not in the sudoers file"?** Debian does this if you set a root password during install. Fix once:
> `su -` → `apt install -y sudo && usermod -aG sudo YOUR_USERNAME` → `exit`, then log out and back in.
>
> To send error reports you need a free GitHub account; the app asks you to log in
> (`gh auth login`) the first time you send one.

### 2. Set up

The app opens automatically. Choose **1) Set up the server**:

1. Read the permission screen, type `yes`
2. Enter your password once
3. Answer a few questions (game version, RAM, passwords, Tailscale or port forwarding)
4. Wait — the first download and world creation take 10–30 minutes
5. The **join info for friends** appears at the end (also saved in `~/ZOMBOID_JOIN_INFO.txt`)

Next time, open **Zomboid Host** from the app menu / desktop icon, or type `pzhost`.

### 3. Every game session

| Want to… | Menu option |
|---|---|
| Start / stop the server | 1 / 2 |
| Show what friends type in game | **4) Join info for friends** |
| See who's online | 5 |
| Save right now | 7 |
| Check ping / Wi-Fi / Tailscale direct vs relay | **18) Ping check** |
| Something broke | **14) Send error report** |
| Get the fix | **15) Update this app** |

---

## For the 4 friends (Windows / Mac)

The host sends you the join info. In short:

1. Game version must match the server exactly (default **42.21**). Turn off auto-update.
2. **Steam** copy: Library → Project Zomboid → Properties → Launch Options: `-nosteam`
   (GOG: nothing to do).
3. **Tailscale mode** (default): install [Tailscale](https://tailscale.com/download),
   sign in, accept the host's share invite email, keep it connected while playing.
4. In game: **Join** → add server → IP + port `16261` + server password →
   pick your own username and password.

---

## What the app changes on the laptop

| Change | Why | Undo |
|---|---|---|
| Packages: `lib32gcc-s1 curl tar git gh iputils-ping iw tailscale` (+ Tailscale apt repo) | SteamCMD, reports, networking | apt |
| System user `pz` (`/home/pz`) | runs the server safely | uninstall |
| `pzserver.service` + `.socket` | runs server, clean save on stop, console commands | uninstall |
| `pzbackup.timer` (05:00), `pzrestart.timer` (05:10) | daily backup (7 days kept), daily restart | uninstall |
| Lid-close ignored, sleep targets masked | laptop keeps hosting | uninstall |
| UDP 16261-16262 (+41641 Tailscale) in ufw/firewalld | friends can connect | uninstall |
| `/etc/sysctl.d/90-pzhost.conf`, Wi-Fi power-save off, server `Nice=-5`, performance profile while running | lower, steadier ping | uninstall |
| `servertest.ini`: private, password, auto-save every 10 min, built-in backups | safety | settings |

Everything is reverted with **17) Uninstall** (`pzhost uninstall`). The world is only deleted if you
explicitly say so, and a copy is saved to your home folder first.

## Logs and error reports

- App log: `~/.local/state/pzhost/pzhost.log` (every command, its output and exit code)
- Install log: `~/.local/state/pzhost/install.log`
- Server log: `journalctl -u pzserver` (or menu **10**)
- Error report: menu **14** builds a report (system info, config, service status, firewall, ping check,
  app log, server log, console.txt, backups), **removes passwords, tokens and your public IP**,
  and opens a **public** GitHub issue labelled `error-report` (emails are removed too). Without GitHub login it saves the file and tells you
  where to upload it.

## Command line

```text
pzhost                 menu
pzhost setup           install / repair
pzhost start|stop|restart|status|players|join
pzhost say "text"      message all players
pzhost save|backup|restore
pzhost ping            ping / Wi-Fi / Tailscale check
pzhost netcheck        Jio CGNAT check
pzhost settings|update-server|report|self-update|uninstall
```

## Other guides

- [`docs/CACHYOS_LAPTOP_MANUAL.md`](docs/CACHYOS_LAPTOP_MANUAL.md) — manual setup (written for CachyOS; the app now targets Debian)
- [`docs/LINUX_VPS.md`](docs/LINUX_VPS.md) — Ubuntu VPS (DigitalOcean)
- [`docs/WINDOWS_VPS.md`](docs/WINDOWS_VPS.md) — Windows VPS

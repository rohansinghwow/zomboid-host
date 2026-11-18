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

### Already have an older version? (update to the window app)

Nothing is reinstalled: your world, passwords, settings and the downloaded server are kept.
Do it when nobody is playing.

**Easiest:** open the old app (`pzhost`) → **15) Update this app** → answer **Enter** (yes) to *Repair*.

**Or by hand** (`git pull` alone only downloads the files — `./install.sh` puts the window app in place):

```bash
cd "$(cat ~/.config/pzhost/source_dir)"   # the folder you cloned, e.g. ~/zomboid-host
git pull
./install.sh
```

Then open **Zomboid Host** from the app menu or desktop icon (or type `pzhost-gui`; the first time,
running it from a terminal shows any error). If the icon still opens the old terminal version, log out and back in once.
Afterwards: **Laptop** tab → **Set up**, then reboot once.

### 2. Set up

The **Zomboid Host** window opens by itself (later: app menu or desktop icon).

1. Fill in the **Set up** page: game version, join password, admin password, Tailscale or port forwarding
2. Press **Set up the server**, read the permission list, press **Allow**, type your laptop password
3. Wait — the first download and world creation take 10–30 minutes (the window shows the progress;
   for Tailscale your browser opens to log in)
4. The **Server** tab then shows the **join info for friends** with copy buttons

### 3. Using the app

| Tab | What's there |
|---|---|
| **Server** | Start / Stop / Restart · join info (IP, port, password) with copy buttons · players online · message everyone |
| **Gameplay** | **Beginner** / Normal / Hard presets · zombies, speed, infection, XP, loot, day length, water/power, zombie respawn… |
| **World** | Save now · backup now · restore a backup · **Start a new world** |
| **Console** | **Player manager**: everyone online with tick boxes, an **Everyone** switch, “Commands go to: …” always shown, a ⋯ menu per player (quick help just for them, bring others here, kick) · **Quick help** (switches itself off): *surrounded* · *hurt* · *stuck / locked door* · *hungry* · *weapon* · *car* · *dark* · rescue / god mode / walk through walls / teleport · searchable **item list** (~57) and **command list** (~80: vehicles, meds, doors, zombies, weather, server, players) — *Send* runs it for every ticked player · whole-world commands are marked · the server's answer is shown with who got what |
| **Laptop** | **Make this laptop a server**: battery stops at 80%, no sleep, Wi-Fi never sleeps + reconnects by itself, server starts on boot |
| **More** | Join password, memory, auto-save, game version · ping check · server log · **Send error report** · **Update this app** · repair · uninstall |

**Repair and updates never redo work:** the ~5 GB server is downloaded once. Repair fixes only what is
missing, keeps your world, passwords, gameplay and server settings (max players, PvP, mods…), and keeps the
server running unless a change needs a restart. **Check for a game server update** asks Steam first and downloads
only if there is a newer build (the running server is stopped and started again for you). A Zomboid server started
outside the app (e.g. the game's own *Host* button) is stopped before ours starts, and only one task runs at a time.

Prefer the terminal? **Zomboid Host (terminal)** in the app menu, or type `pzhost` — same features as a numbered menu
(19 gameplay, 20 new world, 21 laptop server mode, 14 error report, 15 update).

---|---|
| Start / stop the server | 1 / 2 |
| Show what friends type in game | **4) Join info for friends** |
| See who's online | 5 |
| Save right now | 7 |
| Check ping / Wi-Fi / Tailscale direct vs relay | **18) Ping check** |
| Change zombies, loot, XP, day length (has a **Beginner** preset) | **19) Gameplay settings** |
| Start the game over on a fresh map (keeps accounts + settings, old world kept) | **20) Start a new world** |
| Battery stops at 80%, no sleep, Wi-Fi reconnects by itself, server starts on boot | **21) Laptop server mode** |
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
| `pzbattery.service`: charging stops at 80% (if the laptop supports it from Linux, otherwise BIOS help is shown) | battery lasts years plugged in 24/7 | uninstall (back to 100%) |
| Current Wi-Fi connection: password stored system-wide, auto-connect, unlimited retries, power saving off | Wi-Fi works after reboot without login and never dozes off | NetworkManager settings |
| `/etc/modprobe.d/pzhost-wifi.conf` (Intel / Realtek / MediaTek Wi-Fi chip power saving off) | no random Wi-Fi drop-outs | uninstall |
| `pzwifi-watchdog.timer`: every minute; if router + internet don't answer 3× in a row, reconnects Wi-Fi (then restarts NetworkManager) | Wi-Fi recovers by itself | uninstall |
| UDP 16261-16262 (+41641 Tailscale) in ufw/firewalld | friends can connect | uninstall |
| `/etc/sysctl.d/90-pzhost.conf`, Wi-Fi power-save off, server `Nice=-5`, performance profile while running | lower, steadier ping | uninstall |
| `servertest.ini`: private, password, auto-save every 10 min, built-in backups | safety | settings |
| `servertest_SandboxVars.lua`: only if you use **19) Gameplay settings** (old file kept as `.bak-<date>`) | difficulty | gameplay settings |

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
pzhost new-world       fresh map, new characters (old world moved to ~pz/Zomboid/old-worlds)
pzhost ping            ping / Wi-Fi / Tailscale check
pzhost laptop          battery limit / no sleep / Wi-Fi auto-connect
pzhost netcheck        Jio CGNAT check
pzhost gameplay        zombies / loot / XP / beginner preset
pzhost settings|update-server|report|self-update|uninstall
```

## Other guides

- [`docs/DEBIAN_LAPTOP_MANUAL.md`](docs/DEBIAN_LAPTOP_MANUAL.md) — the same setup done by hand on Debian 13
- [`docs/LINUX_VPS.md`](docs/LINUX_VPS.md) — Ubuntu VPS (DigitalOcean)
- [`docs/WINDOWS_VPS.md`](docs/WINDOWS_VPS.md) — Windows VPS

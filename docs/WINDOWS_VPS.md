## 1. Windows VPS — install the server

1. Connect to your Windows VPS using Remote Desktop. Download [SteamCMD for Windows](https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip) and extract it to `C:\SteamCMD`.
2. Open `C:\SteamCMD\steamcmd.exe`. At the `Steam>` prompt, enter these commands one at a time. Wait for the install to finish before entering `quit`.

   ```text
   force_install_dir C:\PZServer
   login anonymous
   app_update 380870 -beta 42.21 validate
   quit
   ```

3. Run `C:\PZServer\StartServer64_nosteam.bat` so GOG clients can join.
4. Set an admin password when prompted. Wait for `SERVER STARTED` and confirm the console shows `42.21.0`.

## 2. Windows VPS — make it private

1. Type `quit` in the server console.
2. Press **Win + R**, enter `%USERPROFILE%\Zomboid\Server`, and open `servertest.ini` in Notepad.
3. Edit these settings in place. Choose a join password different from the admin password.

   ```ini
   Public=false
   Password=your-friends-password
   ```

4. Save the file and reopen `StartServer64_nosteam.bat`.
5. Allow inbound UDP `16261` and `16262` in Windows Firewall and in your VPS provider’s firewall if one is enabled. If your friends have fixed public IPs, restrict both rules to those addresses.
6. Share the VPS public IP, port `16261`, and the join password with your friends privately.

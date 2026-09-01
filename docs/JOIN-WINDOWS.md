---
type: guide
status: active
created: 2026-08-04
updated: 2026-08-31
---

# Migrate to Mythic Prehistory 1.3 on Windows

✅ **Current pack:** Minecraft 1.20.1, Forge 47.4.22, Mythic Prehistory 1.3.0.

Install the new instance beside the old one. Keep the old instance untouched until the new one reaches the main menu and joins the server.

| Keep | Replace |
|---|---|
| Screenshots, local worlds, Xaero maps/waypoints | Mods, configs, Forge, updater files |
| Microsoft account and personal keybinds | The old Mythic instance |
| A full backup until migration is proven | Individually downloaded mod updates |

## Before you start

You need:

- Windows 10 or 11, 64-bit.
- A Microsoft account that owns Minecraft: Java Edition.
- At least 8 GB system RAM; 16 GB recommended.
- About 3 GB free disk space.
- Your exact Minecraft username added to the server whitelist.
- The host to start the server before you join. The server deliberately does not wake from connection attempts.

Official links:

- [Download Prism Launcher](https://prismlauncher.org/download/windows/)
- [Prism Java setup](https://prismlauncher.org/wiki/getting-started/installing-java/)
- [Prism zip import help](https://prismlauncher.org/wiki/help-pages/zip-import/)
- [Mythic Prehistory bootstrap](https://mythic-pack.ariaxhan.com/downloads/MythicPrehistory-client.zip)

Use Prism's normal installer. If you use the portable edition, keep it out of Desktop, Documents, OneDrive, Dropbox, and other synchronized folders.

## 1. Back up the old instance

Do not delete or update the old instance in place.

1. Close Minecraft.
2. In Prism, right-click the old Mythic instance → **Folder** or **Instance Folder**.
3. Close Prism completely.
4. Copy that entire instance folder to a safe local folder such as `C:\Games\Mythic-Backup`.
5. Reopen Prism and rename the old tile to **Mythic Prehistory OLD**.

The multiplayer world and inventory live on the server. This backup protects local screenshots, settings, single-player worlds, maps, and waypoints.

## 2. Install or update Prism

1. Install the current 64-bit Prism Launcher from the official link above.
2. Open Prism → **Settings → Java**.
3. Turn on **Autodetect Java version** and **Auto-download Mojang Java**.
4. Sign in through **Accounts → Manage Accounts → Add Microsoft**.

If Prism asks which Java to use, choose **Java 17, 64-bit**. Do not use Java 8 or 21 for this pack.

## 3. Import the clean 1.3 instance

1. Download `MythicPrehistory-client.zip` from the bootstrap link above.
2. Do **not** unzip it.
3. In Prism, choose **Add Instance → Import**.
4. Select the downloaded zip, then choose **OK**.
5. Confirm that the new tile is named **Mythic Prehistory**, not **OLD**.

The bootstrap is intentionally small. It contains Minecraft/Forge declarations and a hash-checking updater; the first launch downloads the complete pack.

## 4. Verify Java and memory

Right-click the new instance → **Edit → Settings**.

### Java

- Open **Java**.
- Leave the instance-specific Java location override off.
- If a path is selected, it must identify a 64-bit Java 17 runtime.
- Use **Test** if Prism offers it.

### Memory

- 8 GB computer: set maximum to **4096 MiB**.
- 16 GB or more: keep the supplied **6144 MiB**.
- Never allocate more than **6144 MiB**. More memory can worsen pauses and starve Windows.

## 5. Run the updater and reach the menu

1. Launch the new instance.
2. The Packwiz updater opens before Minecraft.
3. Approve the complete update when prompted.
4. Keep Prism open until Forge reaches the Minecraft main menu.

The first run downloads and verifies roughly 136 client mods plus configuration. Several minutes of high disk or CPU use is normal. Later launches check hashes and download only approved changes.

Do not bypass, cancel, or remove the pre-launch updater. It is what keeps every player synchronized with the server.

## 6. Move personal files only

After the new instance reaches the menu once, close Minecraft and Prism. Open both old and new instance folders and copy only what you need:

| Old `minecraft` item | Copy? | Notes |
|---|---:|---|
| `screenshots` | Yes | Safe. |
| `saves` | Yes | Local single-player worlds only. Back them up first. |
| `XaeroWorldMap` | Yes | Personal map tiles. |
| `XaeroWaypoints` | Yes | Personal waypoints. |
| `options.txt` | Optional | Restores keybinds/video settings; may reintroduce conflicts. |
| `resourcepacks`, `shaderpacks` | Optional | Leave disabled until the unmodified pack works. |
| `mods` | **No** | Causes version mismatches and crashes. |
| `config`, `defaultconfigs` | **No** | Overwrites pack-owned fixes. |
| `kubejs`, `scripts`, updater files | **No** | Breaks pack synchronization. |

Launch again after copying. If a problem begins only after the copy, restore the clean new instance and move one personal folder at a time.

## 7. Join the server

Ask the host to confirm that the server is started and your exact Minecraft username is whitelisted.

In Minecraft:

1. Choose **Multiplayer → Add Server**.
2. Name: **Mythic Prehistory**.
3. Address: `aria-mythic-prehistory.fly.dev`.
4. Join.

No port is needed. A red **Incompatible FML modded server** mark can be cosmetic; try **Join Server** before treating it as an error.

## Migration is complete when

- The new instance reaches the main menu twice, proving the updater is repeatable.
- Multiplayer joins without a missing-mod or channel mismatch.
- Your inventory, quests, and position appear on the server.
- Any copied maps, waypoints, screenshots, or local worlds are present.

Keep **Mythic Prehistory OLD** and the backup for at least one successful play session. Then delete them only if you no longer need local data.

## Troubleshooting

Start with the phase that failed. Do not reinstall everything first.

### Prism will not open

**`MSVCP140_2.dll` or Visual C++ error**

- Install Microsoft's current Visual C++ 2015–2022 Redistributable for your CPU architecture.
- Restart Windows, then reopen Prism.
- Use Prism's recommended x64 build on ordinary Intel/AMD Windows PCs.

**Prism is inside OneDrive or a synchronized folder**

- Move or reinstall it to a normal local location.
- Do not move files while Prism or Minecraft is open.

### The zip will not import

- Confirm the filename ends in `.zip`; do not import a browser shortcut or an extracted folder.
- Download it again from the official Mythic bootstrap link.
- In Prism use **Add Instance → Import**, not **Create vanilla instance**.
- If the instance name already exists, rename the old tile and retry.

### Java error before Minecraft starts

**Wrong version, invalid path, or `Java binary is not found`**

1. Right-click the new instance → **Edit → Settings → Java**.
2. Turn off the instance-specific Java path override.
3. Choose **Auto-detect** and select 64-bit Java 17.
4. In Prism's global Java settings, enable automatic Java download.
5. Run **Test**.

Do not enable **Skip Java compatibility checks**. Do not point this instance at Java 8 or 21.

### The Packwiz updater fails

**Network, timeout, certificate, 403, or 404**

1. Open `https://mythic-pack.ariaxhan.com/pack.toml` in a browser. Plain text beginning with `name = "Mythic Prehistory"` proves the manifest is reachable.
2. Confirm Windows date, time, and time zone are automatic; a wrong clock breaks HTTPS.
3. Disable VPN/proxy temporarily if it blocks Cloudflare downloads.
4. Allow Prism and Java through the firewall if Windows prompted you.
5. Relaunch the instance.

Do not bypass the updater. If the manifest opens but the updater still fails, send the complete updater error to the host.

**Hash/checksum error**

- Close Minecraft and relaunch once; the updater normally replaces a partial download.
- If the same file fails again, stop. Send its exact filename and error to the host.
- Do not download a replacement mod from CurseForge or Modrinth yourself.

**Updater never appears**

- Confirm you launched the new **Mythic Prehistory** tile, not **OLD**.
- Right-click new instance → **Edit → Settings → Custom commands**.
- A pre-launch command using `packwiz-installer-bootstrap.jar` and `https://mythic-pack.ariaxhan.com/pack.toml` must exist.
- If absent, delete only the failed new instance and import the bootstrap again. Keep the old backup.

### Minecraft crashes before the main menu

**Out of memory, exit code `-805306369`, or Windows becomes unresponsive**

- Close browsers and other games.
- Use 4096 MiB on an 8 GB PC or 6144 MiB on a 16+ GB PC.
- Confirm the Java runtime is 64-bit.
- Do not allocate more than 6144 MiB.

**Crash mentions OptiFine, Oculus, Rubidium, or an extra mod**

- The clean pack uses its own renderer stack. Do not add OptiFine or individual mods.
- Reimport a clean instance instead of deleting random jars.

**First launch appears frozen**

- Watch Prism's Minecraft log. If new lines continue appearing, wait.
- Windows Defender may scan every jar on the first run. Do not disable antivirus globally.
- If no new log line appears for five minutes, capture the log before ending the process.

### The main menu opens, but joining fails

| Message | Meaning and fix |
|---|---|
| Connection timed out/refused | Server is asleep or still starting. Ask the host to start it and confirm READY. |
| You are not whitelisted | Send the host your exact current Java Edition username, including capitalization. |
| Failed to verify username / invalid session | In Prism, sign out of the Microsoft account, restart Prism, and sign in again. |
| Missing mods / incompatible mod set / channel mismatch | Close Minecraft and relaunch the new instance so Packwiz runs. Never update one mod manually. |
| Packet Fixer required / Immersive Furniture requires Packet Fixer | You launched an old or incomplete instance. Relaunch the new instance; if it repeats, reimport the bootstrap. |
| Internal exception / connection lost during fresh exploration | Record the exact time and action. Send `latest.log`; the host must check the server too. |

### The game joins but runs badly

Change only client video settings first:

- Render distance: 8–12 chunks.
- Simulation distance: 6 chunks.
- Disable shaders and third-party resource packs.
- Cap FPS to your monitor refresh rate.
- Close browser video, recording, and overlays.
- Keep memory within the limits above.

Do not install OptiFine, replace Embeddium, or remove creature/world-generation mods.

### Maps, waypoints, or controls are missing

- Copy `XaeroWorldMap` and `XaeroWaypoints` from the backed-up old `minecraft` folder while Prism is closed.
- For controls, either copy `options.txt` or set keys again manually.
- Press **K** in game for Mythic's searchable keybind screen.
- If copying `options.txt` creates conflicts, restore the clean new file and rebind manually.

## What to send for help

Include all four:

1. What you clicked or did.
2. What you expected and what happened instead.
3. Approximate local time of the failure.
4. The relevant log:
   - Updater failure: copy the complete text from Prism's console.
   - Minecraft opened: right-click instance → **Folder** → `minecraft\logs\latest.log`.
   - Crash report created: newest file in `minecraft\crash-reports`.

Do not post account tokens or Microsoft login details. Do not edit the log before sending it privately to the host.

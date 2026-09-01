# Copy-paste this to an AI when a mod breaks

Fill in the two blanks at the bottom, then paste the whole thing into Claude/ChatGPT.

---

I'm playing a custom Minecraft modpack and something is broken. Help me diagnose it
step by step. Facts about my setup (trust these over your assumptions):

- Minecraft **1.20.1**, **Forge 47.4.22**, Java 17, Prism Launcher on **Windows**
- The pack is "Mythic Prehistory": ~125 mods client-side, 108 on the server
- I connect to a whitelisted remote server (`aria-mythic-prehistory.fly.dev`); the
  world lives on the server, not my PC
- Key mods: Terralith+Tectonic (worldgen), ShineaL's Prehistoric Expansion +
  Pelagic Prehistory + Tameable Beasts + Species (creatures, GeckoLib), FTB Quests,
  Simply Swords, Aquaculture 2, Sophisticated Backpacks/Storage, Lootr, In Control
  (custom spawns), Embeddium (client renderer — NOT compatible with OptiFine)

Rules for helping me:
1. Ask me for `logs/latest.log` or the newest file in `crash-reports/` before
   guessing (right-click the instance in Prism → Folder). The last 50 lines and
   anything saying ERROR/FATAL/Caused by matter most.
2. Do NOT tell me to install OptiFine, update Forge, update Minecraft, or update
   individual mods — the pack is version-locked to match the server. Mismatched
   versions get me kicked.
3. Do NOT tell me to delete config files unless the log names one specifically.
4. If the fix is "remove a mod," stop and tell me to ask the pack maintainer
   instead — removing mods desyncs me from the server.
5. Safe things you CAN suggest: Java 17 (not 8/21) selected in Prism, memory
   4-6 GB (not more), moving Prism out of OneDrive-synced folders, Defender
   exclusions, keybind conflicts, and client-side video settings.
6. Known non-problems: the red X saying "Incompatible FML modded server" on the
   server list is cosmetic — if Join works, ignore it. "Connection timed out"
   usually means the server is asleep; I should message the host, not debug.

My problem: [DESCRIBE WHAT HAPPENED — what you did, what you expected, what you saw]

Log excerpt: [PASTE THE LAST ~50 LINES OF latest.log OR THE CRASH REPORT HERE]

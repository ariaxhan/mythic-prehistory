# Keybind conflicts in this pack (and fixing the backpack)

## The pack-wide problem

This pack ships **23 keys with more than one binding**. Many are harmless: Forge gives
each binding a *conflict context*, so JEI's bindings only fire while a JEI screen is open
and do not really fight `attack` or `sneak`. The ones below share the **in-game** context
and genuinely interfere.

| Key | Fighting over it | Symptom |
|---|---|---|
| `B` | Sophisticated Backpacks *open_backpack*, Immersive Aircraft *boost*, Tom's Storage *open_terminal*, CoFH *mode_change_decrement* | backpack will not open |
| `L` | vanilla *Advancements*, OreExcavation *shape_edit*, Xaero *new_waypoint* | waypoint dialog opens instead of Advancements |
| `R` | Immersive Aircraft *dismount*, Lost Trinkets *trinket*, OreExcavation *excavate* | unpredictable |
| `G` | Curios *open*, BlockPreview *toggle*, SimplyTooltips *cycle_tab* | Curios screen may not open |
| `U` | Corpse *death_history*, Xaero *waypoints_key* | wrong screen |
| `C` | vanilla *saveToolbarActivator*, Backpacks *inventory_interaction* | |
| `X` | vanilla *loadToolbarActivator*, Tiny Dragons *open_menu* | |
| `Z` | Block Factory Bosses *dodge_roll*, Xaero *enlarge_map* | dodge may open the map |
| `V` | OreExcavation *shape_toggle*, CoFH *mode_change_increment* | |
| `K` | CraftingTweaks *compress_stack*, KeybindAtlas *open_keyboard* | |
| `SPACE` | *jump*, Hippocampus *up*, Triceratops *ram* | matters while riding |

Menus that need no keybind at all, when a key is fighting you:

- **Advancements**: `Esc` then the **Advancements** button
- **A backpack**: take it off and right-click it in hand

Regenerate this table any time from `options.txt` by grouping `key_*` lines by their key
value and listing any key with more than one entry.

# Fixing the backpack keybind (Sophisticated Backpacks)

Short version: **four different mods in this pack all bind to `B` by default.** When
several keybinds share a key, Minecraft marks them as conflicting and the one you want
often loses. Rebinding to another key does not help if the real problem is elsewhere,
which is why moving it to `` ` `` did nothing.

## The conflicts on `B`

Straight out of this pack's `options.txt`:

| Keybind | Mod | Default |
|---|---|---|
| `sophisticatedbackpacks.open_backpack` | Sophisticated Backpacks | `B` |
| `immersive_aircraft.boost` | Immersive Aircraft | `B` |
| `toms_storage.open_terminal` | Tom's Simple Storage | `B` |
| `cofh.mode_change_decrement` | CoFH Core | `B` |

Goal: keep the first one on `B`, clear the other three.

## Method 1: in-game (safe while playing)

Note: the vanilla **Key Binds** screen in 1.20.1 has **no search box**. Bindings are listed
under category headers and you scroll to the one you want. This pack does ship
**KeybindAtlas** (client-side), which is the easier route.

**With KeybindAtlas (press `K`):** it opens a visual keyboard. Use its **Filter** button to
show only Sophisticated Backpacks bindings, and it will show you what else sits on a key.

**Vanilla route:** `Esc` then **Options → Controls → Key Binds**, and scroll down to the
**Sophisticated Backpacks** category header.

1. Set **Open Backpack** to `B`
2. Scroll to the **Immersive Aircraft**, **Tom's Simple Storage**, and **CoFH Core**
   categories and clear their `B` bindings (highlight the binding, press `Esc` to unbind)
3. Anything still showing in **red** is still conflicting, so clear that too

Only the binding named exactly **Open Backpack** opens the bag. *Inventory Interaction*
(default `C`), *Tool Swap*, and the five *Toggle Upgrade* entries are different actions,
and rebinding one of those by mistake looks exactly like the key not working.

## Method 2: edit options.txt (must quit Minecraft first)

Minecraft rewrites `options.txt` when it closes, so **fully quit the game first** or your
edit gets wiped.

The file lives in the instance folder, under `minecraft/options.txt`. In Prism Launcher,
right-click the instance and choose **Folder** to get there.

Find and set these four lines exactly:

```
key_key.sophisticatedbackpacks.open_backpack:key.keyboard.b
key_key.immersive_aircraft.boost:key.keyboard.unknown
key_key.toms_storage.open_terminal:key.keyboard.unknown
key_key.cofh.mode_change_decrement:key.keyboard.unknown
```

`key.keyboard.unknown` is how the game stores "not bound". Save, then launch.

## If `B` still does nothing

The keybind is not broken, it just has nothing to open. Sophisticated Backpacks' open
key only fires when it can actually find a backpack:

- the backpack must be **in your inventory**, or equipped in the **Curios "back" slot**
- a backpack in a chest, an ender chest, or on the ground will not respond
- make sure the bind you changed is **Open Backpack**, not *Inventory Interaction*
  (default `C`) or *Tool Swap*, which are different actions

Craft or grab a backpack, put it in your inventory, then press `B`.

## Why `` ` `` specifically was a bad test

Nothing else in this pack binds the grave/backtick key, so it should have been free.
That it still did nothing points at the "no backpack reachable" case above rather than a
conflict. Some keyboard layouts also do not report grave to GLFW the way you would
expect, which makes it a poor key to debug with. Use `B` and confirm the conflicts are
cleared.

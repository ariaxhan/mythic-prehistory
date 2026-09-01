# Taming guide (Mythic Prehistory)

Pulled from the mod jars themselves, not from a wiki, so it matches the versions this
server actually runs.

Creatures come from several different mods and **each one tames differently**. There is no
single "tame" item.

## Do this in game instead of reading this file

**Press `L` to open Advancements, then the Tameable Beasts tab.**

That mod ships **34 advancements** whose descriptions *are* the taming manual. Everything
in the table below was read out of them. They are not hidden (`hidden: false`), so they
show up greyed out before you earn them and you can read the description either way.

One catch: the tree unfolds as you go. The Argentavis entry has `big_bird_bait` as its
parent, so you need the bait before that node appears. Craft the food first, then the
creature's entry shows you how to use it.

Alongside that:

- **JEI** tells you how to craft the food. Hover an item, press `R` for its recipe and `U`
  for what it makes.
- **Jade** puts the mob's health on your HUD when you look at it, which matters a lot here
  because several creatures only accept food **under 10 health**. Watch the number.
- There is **no Patchouli guidebook** in this pack, so do not go hunting for one.

## The one trick that changes everything

Most of the big flyers only accept food when they are **under 10 health**, which is
miserable on something that flies away. The mods ship an alternative:

> "Even better put some Pteranodon Meal in arrows to try to tame some pteras
> **without any health restrictions**."

**Put the taming food in an arrow and shoot them.** No health requirement at all. This
works for the pteranodon family and for the big birds. Shoot carefully, the tooltip warns
you can still kill them.

## Tameable Beasts

| Creature | Exact taming item | Rideable? |
|---|---|---|
| **Quetzalcoatlus** | Ptera Meal below 10 health, or a Ptera Meal Arrow at any health | Yes: regular Saddle |
| **Grapteranodon** | Ptera Meal below 10 health, or a Ptera Meal Arrow at any health | Yes: regular Saddle |
| **Argentavis** | Big Bird Bait below 10 health, or a Big Bird Bait Arrow at any health | Yes: regular Saddle |
| **Chikote** | Potato or Big Bird Bait | Yes: regular Saddle |
| **Crested Gecko** | Spider eye, fermented spider eye, arthropod pieces, or arthropod eggs | Yes: regular Saddle |
| **Giant Grasshopper** | Bug Salad | Yes: regular Saddle |
| **Giant Roly Poly** | Bug Salad | Yes: regular Saddle |
| **Penguin** | Frozen Fish | Yes: Ice Chestplate acts as its saddle |
| **Shiny/Flying Beetle** | Honey Bottle | No |
| **Ground Beetle** | Honey Bottle; Raw Iron upgrades it after taming | No |
| **Raccoon** | Melon Slice | No |
| **Scarecrow Allay** | Put a Purple Allay into a Scarecrow Block, then interact | No |

There is no separate Tameable Beasts Pteranodon entity in this installed version. The
**Pteranodon Meal** is the bait used for Grapteranodon and Quetzalcoatlus. ShineaL's
Pteranodon is a different creature and uses the pack's fish-bonding system below.

### Riding Tameable Beasts

1. Tame the creature first.
2. Right-click it normally to open its equipment screen.
3. Put a normal **Saddle** in its saddle slot. The Penguin uses an **Ice Chestplate**
   instead.
4. Right-click again without sneaking to mount. Use normal movement keys and the bound
   dismount key.

| Mount | Extra controls and equipment |
|---|---|
| **Argentavis** | Jump key ascends; crouch key dives. Flight uses a stamina bar. |
| **Grapteranodon** | Jump ascends; crouch dives; left-click while flying grabs a nearby mob. A Flying Helmet removes its rider-safety speed penalty. |
| **Quetzalcoatlus** | Jump ascends; crouch dives. A Flying Helmet restores full speed. Quetzal Stand Gear permits up to three additional passengers. |
| **Grasshopper** | Hold and release Jump for a charged leap. |
| **Roly Poly** | Normal ground controls. Wearing a Poly Biker Helmet removes its rider-safety speed penalty; asphalt improves grip and speed. |
| **Chikote / Crested Gecko** | Normal ground controls. |
| **Penguin** | Normal ground/water controls after equipping its Ice Chestplate. |

The mount displays its currently bound controls when you get on. Trust that prompt over
hard-coded key names if a player changed their controls.

### Sitting Tameable Beasts

Sneak-right-click your tamed beast. It cycles its native state between sitting,
following, and wandering. Do this without mounting it. These creatures have native sit
state and animation support.

### Eggs and hatching

Place a creature egg as a block in a loaded chunk. Pack `1.3.1` reduces hatching from the
mod's accidental 6 hours 40 minutes to 10 minutes. Keep block light above 11 and fence the
egg off: a player or ordinary living mob landing on it has a 1-in-3 chance to crush it.
Tameable Beasts and Fur Golems cannot crush eggs. **Egg Rests** are crafting loot dropped
when an egg block is broken; they are not an incubator.

## Mythic dinosaur companions

Pack `1.1.0` adds companion behavior to every eligible prehistoric creature that does not
already have native ownership. Feed them repeatedly; calm small animals bond quickly while
apex predators demand more food. Once bonded, they do not attack players, follow their owner,
defend against mobs, and persist through relogs.

**Sneak-right-click with an empty hand** to toggle follow/sit. Sitting freezes all movement,
cancels defense, and prevents following until the owner sneak-right-clicks again. The state
persists through relogs. Most original dinosaur models do not contain a sitting animation,
so they remain visually standing while functionally sitting. Feed the same diet again to
heal four health.

| Diet | Accepted food |
|---|---|
| **Herbivore** | wheat, carrot, apple, beetroot, melon slice, sweet berries, kelp, seagrass, juniper berries |
| **Carnivore** | raw beef, porkchop, chicken, mutton, rabbit, dodo meat, raw mammoth meat |
| **Fish-eater** | cod, salmon, tropical fish, pufferfish, raw cuttlefish |

Each accepted feeding independently rolls the listed chance. A failed roll shows smoke
and “is interested”; keep feeding. A success shows hearts and “bonded with you.”

| Creature | Diet | Chance per food | Rideable? |
|---|---|---:|---|
| Ammonite, Dodo | Herbivore | 1 in 2 | No |
| Amargasaurus | Herbivore | 1 in 3 | No |
| Mammoth, Therizinosaurus | Herbivore | 1 in 4 | No |
| Wild Triceratops | Herbivore | 1 in 4 | Not directly; convert it as described below |
| Rideable Trike | Herbivore | 1 in 3 | **Yes** |
| Dugong, Henodus | Herbivore | 1 in 3 | No |
| Opabinia | Fish | 1 in 2 | No |
| Anomalocaris, Diplocaulus, Swimming Diplocaulus | Fish | 1 in 3 | No |
| Dimorphodon | Fish | 1 in 4 | No |
| Jaekelopterus, ShineaL's Pteranodon | Fish | 1 in 5 | No |
| ShineaL's Dunkleosteus, ShineaL's Spinosaurus | Fish | 1 in 6 | No |
| Phorusrhacos | Carnivore | 1 in 4 | No |
| Utahraptor | Carnivore | 1 in 5 | No |
| Carnotaurus | Carnivore | 1 in 6 | No |
| Cuttlefish, Lepidotes | Fish | 1 in 2 | No |
| Cladoselache | Fish | 1 in 3 | No |
| Bawitius, Irritator, Orthacanthus | Fish | 1 in 4 | No |
| Eurhinosaurus, Plesiosaurus, Shonisaurus | Fish | 1 in 5 | No |
| Pelagic Dunkleosteus, Pelagic Spinosaurus, Pliosaurus, Prognathodon | Fish | 1 in 6 | No |

Bond odds range from **1-in-2** for small/passive creatures to **1-in-6** for apex predators.
JEI carries the diet overview on every food and exact odds on each spawn egg. Hover and press
**U**. Aquatic companions only follow or teleport while their owner is swimming; this prevents
them from stranding themselves on land.

## ShineaL's native taming and mounts

| Creature | How to tame |
|---|---|
| **Hippocampus** | Feed cod, cooked cod, salmon, cooked salmon, pufferfish, or tropical fish. Each fish has a 10% chance to make it saddle-ready. Then right-click it with a normal Saddle; this converts it into the rideable Hippocampus. Right-click to mount. `Space` rises and `Left Control` descends by default; both appear as “Mob Vertical Movement” in Controls. |
| **Triceratops** | Feed Grass Blocks until the 10% rider-trust roll succeeds. Right-click with a **Woolly Saddle**; this converts it into the Rideable Trike. Right-click to mount. Normal movement steers it; `Space` uses its damaging ram/charge and has a cooldown. Feed the Rideable Trike herbivore food to bond it to an owner. |
| **Anurognathus** | Juniper berries, 1-in-3 chance. It has native ownership and sitting, but is not rideable. |
| **Mammoth** | Bond with herbivore food. It is a companion, not a mount in this installed version; the Woolly Saddle is for the Triceratops conversion. |

Only the **Rideable Trike** and **saddled Hippocampus** are rideable among ShineaL's
prehistoric creatures. Diet bonding adds ownership, follow, defense, healing, and stay;
it does not invent riding support for the other entity classes. Every Mythic-bonded species
in the table supports the same sneak-right-click sit command.

Non-dinosaur creatures remain unchanged.

## Tiny Dragons

Separate mod again. It uses a **capture cage** item rather than food, and the starter
quest hands you an `open_capture_cage`.

## When in doubt, use JEI

The quest book says it plainly, and it is right: *"Every species has its own taming food
and its own opinion of you. JEI plus patience wins."*

Hover any creature's egg or meal item and press **U** to see what it makes, or **R** for
its recipe. That is faster than guessing, and it is accurate for the exact mod versions
installed here.

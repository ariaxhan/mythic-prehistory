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

## Tameable Beasts (the main rideable ones)

| Creature | How to tame |
|---|---|
| **Quetzalcoatlus** | Ptera Meal while under 10 health, or Ptera Meal in an arrow |
| **Grapteranodon** | Ptera Meal under 10 health, or in an arrow. Fast, and can pick up other mobs |
| **Pteranodon** | Pteranodon Meal, same rules, arrow version removes the health limit |
| **Argentavis** | Big Bird Bait under 10 health, or Big Bird Bait in arrows |
| **Crested Gecko** | Offer arthropod pieces |
| **Giant Grasshopper** | Offer salad |
| **Giant Roly Poly** | Salad as well |
| **Beetles** (shiny, etc.) | Honey-related items, they have "a huge sweet tooth" |
| **Ground Beetle** | Feed enough **Raw Iron**, they absorb its properties |
| **Scarecrow Allay** | Put a Purple Allay into a Scarecrow Block, then interact with it |

### Eggs and hatching

Spawn eggs exist for Argentavis, Chikote, Crested Gecko, Giant Grasshopper, Giant Roly
Poly, Grapteranodon, Ground Beetle, Penguin, Quetzalcoatlus, Racoon, Scarecrow and Shiny
Beetle.

Eggs hatch into a baby "if you are a good parent" (the mod's words), and failing that you
get told "You are a bad parent." **Egg Rests** are looted from eggs you bred or found on
nests, and are what you incubate on.

## Mythic dinosaur companions

Pack `1.1.0` adds companion behavior to every eligible prehistoric creature that does not
already have native ownership. Feed them repeatedly; calm small animals bond quickly while
apex predators demand more food. Once bonded, they do not attack players, follow their owner,
defend against mobs, and persist through relogs.

**Sneak-right-click with an empty hand** to toggle follow/stay. Feed the same diet again to
heal four health.

| Diet | Dinosaurs | Food |
|---|---|---|
| **Herbivore** | Amargasaurus, Ammonite, Dodo, Mammoth, Therizinosaurus, both Triceratops forms, Dugong, Henodus | wheat, carrot, apple, beetroot, melon, berries, kelp, seagrass, juniper berries |
| **Carnivore** | Carnotaurus, Utahraptor, Phorusrhacos | raw vanilla meat, dodo meat, mammoth meat |
| **Fish-eater** | Every other ShineaL's or Pelagic prehistoric creature, including both Spinosauruses and the marine reptiles | cod, salmon, tropical fish, pufferfish, raw cuttlefish |

Bond odds range from **1-in-2** for small/passive creatures to **1-in-6** for apex predators.
JEI carries the diet overview on every food and exact odds on each spawn egg. Hover and press
**U**. Aquatic companions only follow or teleport while their owner is swimming; this prevents
them from stranding themselves on land.

## ShineaL's native taming

| Creature | How to tame |
|---|---|
| **Hippocampus** | Fish: cod, cooked cod, salmon, cooked salmon, pufferfish, tropical fish |
| **Mammoth** | Uses the **Wooly Saddle** (`fur_saddle`) once tamed |
| **Triceratops** | Grass block gives a 10% chance to accept riders; then use a Woolly Saddle. Feed the resulting rideable Trike herbivore food to bond it as a companion |
| **Anurognathus** | Juniper berries, 1-in-3 chance; already uses native ownership |

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

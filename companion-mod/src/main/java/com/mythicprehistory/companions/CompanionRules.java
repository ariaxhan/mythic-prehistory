package com.mythicprehistory.companions;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

public final class CompanionRules {
    public enum Diet {
        HERBIVORE,
        CARNIVORE,
        PISCIVORE
    }

    public enum Habitat {
        TERRESTRIAL,
        AQUATIC
    }

    public record Species(String entityId, String displayName, Diet diet, Habitat habitat, int bondDenominator) {}

    private static final List<Species> SPECIES = List.of(
        species("shineals_prehistoric_expansion:amargasaurus", "Amargasaurus", Diet.HERBIVORE, Habitat.TERRESTRIAL, 3),
        species("shineals_prehistoric_expansion:ammonite", "Ammonite", Diet.HERBIVORE, Habitat.AQUATIC, 2),
        species("shineals_prehistoric_expansion:anomalocaris", "Anomalocaris", Diet.PISCIVORE, Habitat.AQUATIC, 3),
        species("shineals_prehistoric_expansion:carnotaurus", "Carnotaurus", Diet.CARNIVORE, Habitat.TERRESTRIAL, 6),
        species("shineals_prehistoric_expansion:dimorphodon", "Dimorphodon", Diet.PISCIVORE, Habitat.TERRESTRIAL, 4),
        species("shineals_prehistoric_expansion:diplocaulus", "Diplocaulus", Diet.PISCIVORE, Habitat.AQUATIC, 3),
        species("shineals_prehistoric_expansion:dodo", "Dodo", Diet.HERBIVORE, Habitat.TERRESTRIAL, 2),
        species("shineals_prehistoric_expansion:dunkleosteus", "ShineaL's Dunkleosteus", Diet.PISCIVORE, Habitat.AQUATIC, 6),
        species("shineals_prehistoric_expansion:jaekelopterus", "Jaekelopterus", Diet.PISCIVORE, Habitat.AQUATIC, 5),
        species("shineals_prehistoric_expansion:mammoth", "Mammoth", Diet.HERBIVORE, Habitat.TERRESTRIAL, 4),
        species("shineals_prehistoric_expansion:opabinia", "Opabinia", Diet.PISCIVORE, Habitat.AQUATIC, 2),
        species("shineals_prehistoric_expansion:phorusrhacos", "Phorusrhacos", Diet.CARNIVORE, Habitat.TERRESTRIAL, 4),
        species("shineals_prehistoric_expansion:pteranodon", "Pteranodon", Diet.PISCIVORE, Habitat.TERRESTRIAL, 5),
        species("shineals_prehistoric_expansion:spinosaurus", "ShineaL's Spinosaurus", Diet.PISCIVORE, Habitat.TERRESTRIAL, 6),
        species("shineals_prehistoric_expansion:therizinosaurus", "Therizinosaurus", Diet.HERBIVORE, Habitat.TERRESTRIAL, 4),
        species("shineals_prehistoric_expansion:triceratops", "Triceratops", Diet.HERBIVORE, Habitat.TERRESTRIAL, 4),
        species("shineals_prehistoric_expansion:trike_tamed", "Rideable Trike", Diet.HERBIVORE, Habitat.TERRESTRIAL, 3),
        species("shineals_prehistoric_expansion:utahraptor", "Utahraptor", Diet.CARNIVORE, Habitat.TERRESTRIAL, 5),
        species("shineals_prehistoric_expansion:water_diplocaulus", "Swimming Diplocaulus", Diet.PISCIVORE, Habitat.AQUATIC, 3),
        species("pelagic_prehistory:bawitius", "Bawitius", Diet.PISCIVORE, Habitat.AQUATIC, 4),
        species("pelagic_prehistory:cladoselache", "Cladoselache", Diet.PISCIVORE, Habitat.AQUATIC, 3),
        species("pelagic_prehistory:cuttlefish", "Cuttlefish", Diet.PISCIVORE, Habitat.AQUATIC, 2),
        species("pelagic_prehistory:dugong", "Dugong", Diet.HERBIVORE, Habitat.AQUATIC, 3),
        species("pelagic_prehistory:dunkleosteus", "Pelagic Dunkleosteus", Diet.PISCIVORE, Habitat.AQUATIC, 6),
        species("pelagic_prehistory:eurhinosaurus", "Eurhinosaurus", Diet.PISCIVORE, Habitat.AQUATIC, 5),
        species("pelagic_prehistory:henodus", "Henodus", Diet.HERBIVORE, Habitat.AQUATIC, 3),
        species("pelagic_prehistory:irritator", "Irritator", Diet.PISCIVORE, Habitat.TERRESTRIAL, 4),
        species("pelagic_prehistory:lepidotes", "Lepidotes", Diet.PISCIVORE, Habitat.AQUATIC, 2),
        species("pelagic_prehistory:orthacanthus", "Orthacanthus", Diet.PISCIVORE, Habitat.AQUATIC, 4),
        species("pelagic_prehistory:plesiosaurus", "Plesiosaurus", Diet.PISCIVORE, Habitat.AQUATIC, 5),
        species("pelagic_prehistory:pliosaurus", "Pliosaurus", Diet.PISCIVORE, Habitat.AQUATIC, 6),
        species("pelagic_prehistory:prognathodon", "Prognathodon", Diet.PISCIVORE, Habitat.AQUATIC, 6),
        species("pelagic_prehistory:shonisaurus", "Shonisaurus", Diet.PISCIVORE, Habitat.AQUATIC, 5),
        species("pelagic_prehistory:spinosaurus", "Pelagic Spinosaurus", Diet.PISCIVORE, Habitat.TERRESTRIAL, 6)
    );

    private static final Map<String, Species> BY_ID = SPECIES.stream()
        .collect(Collectors.toUnmodifiableMap(Species::entityId, entry -> entry));

    private static final Map<Diet, Set<String>> FOODS = Map.of(
        Diet.HERBIVORE, Set.of(
            "minecraft:wheat", "minecraft:carrot", "minecraft:apple",
            "minecraft:beetroot", "minecraft:melon_slice", "minecraft:sweet_berries",
            "minecraft:kelp", "minecraft:seagrass",
            "shineals_prehistoric_expansion:juniper_berries"
        ),
        Diet.CARNIVORE, Set.of(
            "minecraft:beef", "minecraft:porkchop", "minecraft:chicken",
            "minecraft:mutton", "minecraft:rabbit",
            "shineals_prehistoric_expansion:dodo_meat",
            "shineals_prehistoric_expansion:raw_mammoth_meat"
        ),
        Diet.PISCIVORE, Set.of(
            "minecraft:cod", "minecraft:salmon", "minecraft:tropical_fish",
            "minecraft:pufferfish", "pelagic_prehistory:raw_cuttlefish"
        )
    );

    private CompanionRules() {}

    public static List<Species> species() {
        return SPECIES;
    }

    public static Optional<Diet> dietFor(String entityId) {
        return speciesFor(entityId).map(Species::diet);
    }

    public static Optional<Habitat> habitatFor(String entityId) {
        return speciesFor(entityId).map(Species::habitat);
    }

    public static Optional<Species> speciesFor(String entityId) {
        return Optional.ofNullable(BY_ID.get(entityId));
    }

    public static Set<String> foodsFor(Diet diet) {
        return FOODS.get(diet);
    }

    public static boolean accepts(String entityId, String itemId) {
        return dietFor(entityId).map(diet -> foodsFor(diet).contains(itemId)).orElse(false);
    }

    public static int bondDenominator(String entityId) {
        return speciesFor(entityId).map(Species::bondDenominator).orElse(Integer.MAX_VALUE);
    }

    public static boolean bondSucceeds(String entityId, int roll) {
        return roll == 0 && bondDenominator(entityId) != Integer.MAX_VALUE;
    }

    public static boolean canFollowOwner(String entityId, boolean ownerInWater) {
        return habitatFor(entityId).map(habitat -> habitat != Habitat.AQUATIC || ownerInWater).orElse(false);
    }

    public static boolean isOwner(String storedOwner, UUID playerId) {
        return storedOwner != null && storedOwner.equals(playerId.toString());
    }

    public static boolean shouldCancelFriendlyFire(String victimOwner, UUID attackerId) {
        return isOwner(victimOwner, attackerId);
    }

    public static boolean shouldFollow(boolean staying, boolean hasDefenseTarget, double distanceSquared) {
        return !staying && !hasDefenseTarget && distanceSquared > 36.0D;
    }

    public static boolean toggleStay(boolean staying) {
        return !staying;
    }

    private static Species species(
        String entityId,
        String displayName,
        Diet diet,
        Habitat habitat,
        int bondDenominator
    ) {
        return new Species(entityId, displayName, diet, habitat, bondDenominator);
    }
}

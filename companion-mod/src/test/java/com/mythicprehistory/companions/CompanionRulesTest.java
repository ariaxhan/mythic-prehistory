package com.mythicprehistory.companions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;

class CompanionRulesTest {
    @Test
    void coversEveryEligiblePrehistoricCreatureWithoutReplacingNativeTames() {
        Set<String> ids = CompanionRules.species().stream()
            .map(CompanionRules.Species::entityId)
            .collect(Collectors.toSet());

        assertEquals(34, ids.size());
        assertTrue(ids.contains("shineals_prehistoric_expansion:carnotaurus"));
        assertTrue(ids.contains("pelagic_prehistory:irritator"));
        assertTrue(ids.contains("shineals_prehistoric_expansion:mammoth"));
        assertTrue(ids.contains("pelagic_prehistory:plesiosaurus"));
        assertTrue(ids.contains("shineals_prehistoric_expansion:dodo"));
        assertTrue(ids.contains("pelagic_prehistory:shonisaurus"));
        assertFalse(ids.contains("shineals_prehistoric_expansion:anurognathus"));
        assertFalse(ids.contains("shineals_prehistoric_expansion:hippocampus"));
        assertFalse(ids.contains("shineals_prehistoric_expansion:harpy"));
    }

    @Test
    void foodsMatchDiet() {
        assertTrue(CompanionRules.accepts("shineals_prehistoric_expansion:amargasaurus", "minecraft:wheat"));
        assertFalse(CompanionRules.accepts("shineals_prehistoric_expansion:amargasaurus", "minecraft:beef"));
        assertTrue(CompanionRules.accepts("shineals_prehistoric_expansion:carnotaurus", "minecraft:beef"));
        assertTrue(CompanionRules.accepts("pelagic_prehistory:spinosaurus", "minecraft:salmon"));
        assertTrue(CompanionRules.accepts("shineals_prehistoric_expansion:dodo", "minecraft:wheat"));
        assertTrue(CompanionRules.accepts("pelagic_prehistory:dugong", "minecraft:seagrass"));
        assertTrue(CompanionRules.accepts("pelagic_prehistory:pliosaurus", "pelagic_prehistory:raw_cuttlefish"));
    }

    @Test
    void bondDifficultyScalesWithCreatureThreat() {
        assertTrue(CompanionRules.bondSucceeds("shineals_prehistoric_expansion:dodo", 0));
        assertFalse(CompanionRules.bondSucceeds("shineals_prehistoric_expansion:dodo", 1));
        assertFalse(CompanionRules.bondSucceeds("shineals_prehistoric_expansion:carnotaurus", 5));
        assertEquals(2, CompanionRules.bondDenominator("shineals_prehistoric_expansion:dodo"));
        assertEquals(6, CompanionRules.bondDenominator("shineals_prehistoric_expansion:carnotaurus"));
    }

    @Test
    void aquaticCreaturesOnlyFollowOwnersInWater() {
        assertEquals(
            CompanionRules.Habitat.AQUATIC,
            CompanionRules.habitatFor("pelagic_prehistory:plesiosaurus").orElseThrow()
        );
        assertFalse(CompanionRules.canFollowOwner("pelagic_prehistory:plesiosaurus", false));
        assertTrue(CompanionRules.canFollowOwner("pelagic_prehistory:plesiosaurus", true));
        assertTrue(CompanionRules.canFollowOwner("shineals_prehistoric_expansion:utahraptor", false));
    }

    @Test
    void ownershipAndFriendlyFireUseExactOwnerUuid() {
        UUID owner = UUID.randomUUID();
        UUID stranger = UUID.randomUUID();

        assertTrue(CompanionRules.isOwner(owner.toString(), owner));
        assertFalse(CompanionRules.isOwner(owner.toString(), stranger));
        assertTrue(CompanionRules.shouldCancelFriendlyFire(owner.toString(), owner));
        assertFalse(CompanionRules.shouldCancelFriendlyFire(owner.toString(), stranger));
    }

    @Test
    void stayAndDefenseSuppressFollowing() {
        assertTrue(CompanionRules.shouldFollow(false, false, 37.0D));
        assertFalse(CompanionRules.shouldFollow(true, false, 100.0D));
        assertFalse(CompanionRules.shouldFollow(false, true, 100.0D));
        assertFalse(CompanionRules.shouldFollow(false, false, 36.0D));
        assertTrue(CompanionRules.toggleStay(false));
        assertFalse(CompanionRules.toggleStay(true));
    }
}

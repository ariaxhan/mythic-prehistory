package com.mythicprehistory.companions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Random;
import java.util.Set;
import org.junit.jupiter.api.Test;

class LootCatalogTest {
    @Test
    void bundledCatalogHasEveryTierAndNoVanillaFiller() {
        LootCatalog catalog = LootCatalog.bundled();
        for (LootCatalog.Tier tier : LootCatalog.Tier.values()) {
            assertFalse(catalog.entries(tier).isEmpty());
            assertTrue(catalog.entries(tier).stream().noneMatch(entry -> entry.itemId().startsWith("minecraft:")));
        }
        assertFalse(catalog.entries(LootCatalog.Tier.JACKPOT).stream()
            .anyMatch(entry -> entry.itemId().equals("losttrinkets:magical_feathers")));
    }

    @Test
    void weightedSelectionReachesEveryDiscoveryEntry() {
        LootCatalog catalog = LootCatalog.bundled();
        Set<String> selected = new HashSet<>();
        for (int roll = 0; roll < catalog.totalWeight(LootCatalog.Tier.DISCOVERY); roll++) {
            selected.add(catalog.pick(LootCatalog.Tier.DISCOVERY, roll).itemId());
        }
        assertEquals(catalog.entries(LootCatalog.Tier.DISCOVERY).size(), selected.size());
    }

    @Test
    void malformedCatalogFailsClosed() {
        String malformed = "discovery\t0\tbad id\n";
        assertThrows(RuntimeException.class, () -> LootCatalog.parse(
            new ByteArrayInputStream(malformed.getBytes(StandardCharsets.UTF_8))
        ));
    }

    @Test
    void dangerTablesHaveHigherButBoundedRareAndJackpotRates() {
        assertTrue(LootBalance.isDangerous("dungeons_arise:chests/palace_treasure"));
        assertFalse(LootBalance.isDangerous("jvs:chest/fishing"));
        assertTrue(LootBalance.rareChance(true) > LootBalance.rareChance(false));
        assertTrue(LootBalance.jackpotChance(true) > LootBalance.jackpotChance(false));

        Random random = new Random(20260830L);
        int normalRare = 0;
        int dangerRare = 0;
        int normalJackpot = 0;
        int dangerJackpot = 0;
        for (int i = 0; i < 100_000; i++) {
            if (random.nextFloat() < LootBalance.rareChance(false)) normalRare++;
            if (random.nextFloat() < LootBalance.rareChance(true)) dangerRare++;
            if (random.nextFloat() < LootBalance.jackpotChance(false)) normalJackpot++;
            if (random.nextFloat() < LootBalance.jackpotChance(true)) dangerJackpot++;
        }
        assertTrue(normalRare > 17_000 && normalRare < 19_000);
        assertTrue(dangerRare > 34_000 && dangerRare < 36_000);
        assertTrue(normalJackpot > 1_300 && normalJackpot < 1_700);
        assertTrue(dangerJackpot > 3_700 && dangerJackpot < 4_300);
    }
}

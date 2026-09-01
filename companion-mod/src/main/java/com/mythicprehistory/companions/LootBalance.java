package com.mythicprehistory.companions;

import java.util.List;

public final class LootBalance {
    public static final float NORMAL_RARE_CHANCE = 0.18F;
    public static final float NORMAL_JACKPOT_CHANCE = 0.015F;
    public static final float DANGER_RARE_CHANCE = 0.35F;
    public static final float DANGER_JACKPOT_CHANCE = 0.04F;

    private static final List<String> DANGER_MARKERS = List.of(
        "ancient_city", "bastion", "boss", "castle", "crypt", "elite",
        "fortress", "hoard", "mansion", "palace", "pyramid", "rare",
        "stronghold", "temple", "tomb", "top_treasure", "treasure", "vault"
    );

    private LootBalance() {
    }

    public static boolean isDangerous(String tableId) {
        return DANGER_MARKERS.stream().anyMatch(tableId::contains);
    }

    public static float rareChance(boolean dangerous) {
        return dangerous ? DANGER_RARE_CHANCE : NORMAL_RARE_CHANCE;
    }

    public static float jackpotChance(boolean dangerous) {
        return dangerous ? DANGER_JACKPOT_CHANCE : NORMAL_JACKPOT_CHANCE;
    }
}

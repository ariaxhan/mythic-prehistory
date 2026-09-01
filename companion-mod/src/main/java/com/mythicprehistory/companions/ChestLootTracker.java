package com.mythicprehistory.companions;

import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.storage.loot.parameters.LootContextParamSets;
import net.minecraftforge.event.LootTableLoadEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = MythicCompanions.MOD_ID, bus = Mod.EventBusSubscriber.Bus.FORGE)
public final class ChestLootTracker {
    private static final Set<ResourceLocation> CHEST_TABLES = ConcurrentHashMap.newKeySet();
    private static final Set<String> FORCED_ALIAS_TABLES = Set.of(
        "minecraft:jvs/fishing",
        "minecraft:jvs/interior",
        "minecraft:jvs/exterior",
        "jvs:chest/fmob",
        "mansions:mansion_common"
    );

    private ChestLootTracker() {
    }

    @SubscribeEvent
    public static void onLootTableLoad(LootTableLoadEvent event) {
        if (event.getTable().getParamSet() == LootContextParamSets.CHEST) {
            CHEST_TABLES.add(event.getName());
        }
    }

    public static boolean isChestTable(ResourceLocation tableId) {
        return CHEST_TABLES.contains(tableId) || FORCED_ALIAS_TABLES.contains(tableId.toString());
    }
}

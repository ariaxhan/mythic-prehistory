package com.mythicprehistory.companions;

import com.mojang.serialization.Codec;
import net.minecraftforge.common.loot.IGlobalLootModifier;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;

public final class LootModifierRegistry {
    private static final DeferredRegister<Codec<? extends IGlobalLootModifier>> MODIFIERS =
        DeferredRegister.create(ForgeRegistries.Keys.GLOBAL_LOOT_MODIFIER_SERIALIZERS, MythicCompanions.MOD_ID);

    static {
        MODIFIERS.register("exploration_loot", () -> MythicLootModifier.CODEC);
    }

    private LootModifierRegistry() {
    }

    public static void register(IEventBus eventBus) {
        MODIFIERS.register(eventBus);
    }
}

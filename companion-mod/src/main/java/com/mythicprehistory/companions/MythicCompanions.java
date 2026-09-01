package com.mythicprehistory.companions;

import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(MythicCompanions.MOD_ID)
public final class MythicCompanions {
    public static final String MOD_ID = "mythic_companions";

    public MythicCompanions() {
        LootModifierRegistry.register(FMLJavaModLoadingContext.get().getModEventBus());
    }
}

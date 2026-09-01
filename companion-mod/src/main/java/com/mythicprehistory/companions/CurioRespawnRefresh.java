package com.mythicprehistory.companions;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.player.PlayerEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import top.theillusivec4.curios.api.CuriosApi;
import top.theillusivec4.curios.api.type.inventory.IDynamicStackHandler;

@Mod.EventBusSubscriber(modid = MythicCompanions.MOD_ID)
public final class CurioRespawnRefresh {
    private static final int REFRESH_DELAY_TICKS = 2;
    private static final Map<UUID, Integer> PENDING = new HashMap<>();

    private CurioRespawnRefresh() {
    }

    @SubscribeEvent
    public static void onRespawn(PlayerEvent.PlayerRespawnEvent event) {
        if (event.getEntity() instanceof ServerPlayer player) {
            PENDING.put(player.getUUID(), REFRESH_DELAY_TICKS);
        }
    }

    @SubscribeEvent
    public static void onLogout(PlayerEvent.PlayerLoggedOutEvent event) {
        PENDING.remove(event.getEntity().getUUID());
    }

    @SubscribeEvent
    public static void onPlayerTick(TickEvent.PlayerTickEvent event) {
        if (event.phase != TickEvent.Phase.END || !(event.player instanceof ServerPlayer player)) {
            return;
        }

        UUID playerId = player.getUUID();
        Integer ticksLeft = PENDING.get(playerId);
        if (ticksLeft == null) {
            return;
        }
        if (ticksLeft > 1) {
            PENDING.put(playerId, ticksLeft - 1);
            return;
        }

        PENDING.remove(playerId);
        refreshEquippedCurios(player);
    }

    private static void refreshEquippedCurios(ServerPlayer player) {
        CuriosApi.getCuriosInventory(player).ifPresent(handler ->
            handler.getCurios().values().forEach(stacks -> refresh(stacks.getStacks()))
        );
    }

    private static void refresh(IDynamicStackHandler stacks) {
        boolean[] occupied = new boolean[stacks.getSlots()];
        for (int slot = 0; slot < stacks.getSlots(); slot++) {
            occupied[slot] = !stacks.getStackInSlot(slot).isEmpty();
        }
        for (int slot : CurioRefreshRules.occupiedSlots(occupied)) {
            var previous = stacks.getStackInSlot(slot).copy();
            previous.setCount(CurioRefreshRules.refreshPreviousCount(previous.getCount()));
            stacks.setPreviousStackInSlot(slot, previous);
        }
    }
}

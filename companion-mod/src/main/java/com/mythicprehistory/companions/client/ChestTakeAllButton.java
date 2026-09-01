package com.mythicprehistory.companions.client;

import com.mythicprehistory.companions.MythicCompanions;
import com.mythicprehistory.companions.TakeAllRules;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.screens.inventory.ContainerScreen;
import net.minecraft.network.chat.Component;
import net.minecraft.world.inventory.ChestMenu;
import net.minecraft.world.inventory.ClickType;
import net.minecraft.world.inventory.Slot;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.ScreenEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = MythicCompanions.MOD_ID, value = Dist.CLIENT)
public final class ChestTakeAllButton {
    private static final int BUTTON_WIDTH = 52;
    private static final int BUTTON_HEIGHT = 16;

    private ChestTakeAllButton() {
    }

    @SubscribeEvent
    public static void onScreenInit(ScreenEvent.Init.Post event) {
        if (!(event.getScreen() instanceof ContainerScreen screen)) {
            return;
        }

        int preferredX = screen.getGuiLeft() + screen.getXSize() + 4;
        int x = Math.min(preferredX, screen.width - BUTTON_WIDTH - 4);
        int y = screen.getGuiTop() + 4;
        event.addListener(Button.builder(
                Component.translatable("button.mythic_companions.take_all"),
                button -> takeAll(screen)
            )
            .bounds(x, y, BUTTON_WIDTH, BUTTON_HEIGHT)
            .build());
    }

    private static void takeAll(ContainerScreen screen) {
        Minecraft minecraft = Minecraft.getInstance();
        if (minecraft.player == null || minecraft.gameMode == null) {
            return;
        }

        ChestMenu menu = screen.getMenu();
        for (int slotIndex : TakeAllRules.sourceSlots(menu.getRowCount())) {
            Slot slot = menu.getSlot(slotIndex);
            if (!slot.getItem().isEmpty()) {
                minecraft.gameMode.handleInventoryMouseClick(
                    menu.containerId,
                    slotIndex,
                    0,
                    ClickType.QUICK_MOVE,
                    minecraft.player
                );
            }
        }
    }
}

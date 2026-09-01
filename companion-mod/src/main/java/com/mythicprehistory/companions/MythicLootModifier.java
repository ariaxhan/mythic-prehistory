package com.mythicprehistory.companions;

import com.mojang.serialization.Codec;
import com.mojang.serialization.codecs.RecordCodecBuilder;
import it.unimi.dsi.fastutil.objects.ObjectArrayList;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.storage.loot.LootContext;
import net.minecraft.world.level.storage.loot.predicates.LootItemCondition;
import net.minecraftforge.common.loot.IGlobalLootModifier;
import net.minecraftforge.common.loot.LootModifier;
import net.minecraftforge.registries.ForgeRegistries;
import org.jetbrains.annotations.NotNull;
import org.slf4j.Logger;
import com.mojang.logging.LogUtils;

public final class MythicLootModifier extends LootModifier {
    public static final Codec<MythicLootModifier> CODEC = RecordCodecBuilder.create(
        instance -> codecStart(instance).apply(instance, MythicLootModifier::new)
    );

    private static final Logger LOGGER = LogUtils.getLogger();
    private static final LootCatalog CATALOG = LootCatalog.bundled();
    private static final Set<String> REPORTED_MISSING_ITEMS = ConcurrentHashMap.newKeySet();

    public MythicLootModifier(LootItemCondition[] conditions) {
        super(conditions);
    }

    @Override
    protected @NotNull ObjectArrayList<ItemStack> doApply(
        ObjectArrayList<ItemStack> generatedLoot,
        LootContext context
    ) {
        ResourceLocation tableId = context.getQueriedLootTableId();
        if (tableId == null || !ChestLootTracker.isChestTable(tableId)) {
            return generatedLoot;
        }

        addOne(generatedLoot, context, LootCatalog.Tier.DISCOVERY);
        boolean dangerous = LootBalance.isDangerous(tableId.toString());
        if (context.getRandom().nextFloat() < LootBalance.rareChance(dangerous)) {
            addOne(generatedLoot, context, LootCatalog.Tier.RARE);
        }
        if (context.getRandom().nextFloat() < LootBalance.jackpotChance(dangerous)) {
            addOne(generatedLoot, context, LootCatalog.Tier.JACKPOT);
        }
        return generatedLoot;
    }

    private static void addOne(
        ObjectArrayList<ItemStack> generatedLoot,
        LootContext context,
        LootCatalog.Tier tier
    ) {
        LootCatalog.Entry entry = CATALOG.pick(tier, context.getRandom().nextInt(CATALOG.totalWeight(tier)));
        ResourceLocation itemId = new ResourceLocation(entry.itemId());
        if (!ForgeRegistries.ITEMS.containsKey(itemId)) {
            if (REPORTED_MISSING_ITEMS.add(entry.itemId())) {
                LOGGER.error("Mythic loot catalog item is not registered: {}", entry.itemId());
            }
            return;
        }
        Item item = ForgeRegistries.ITEMS.getValue(itemId);
        if (item != null) {
            generatedLoot.add(new ItemStack(item));
        }
    }

    @Override
    public Codec<? extends IGlobalLootModifier> codec() {
        return CODEC;
    }
}

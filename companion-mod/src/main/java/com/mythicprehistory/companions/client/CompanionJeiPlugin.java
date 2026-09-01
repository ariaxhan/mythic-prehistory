package com.mythicprehistory.companions.client;

import com.mythicprehistory.companions.CompanionRules;
import com.mythicprehistory.companions.MythicCompanions;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.registries.ForgeRegistries;
import mezz.jei.api.IModPlugin;
import mezz.jei.api.JeiPlugin;
import mezz.jei.api.registration.IRecipeRegistration;

@JeiPlugin
public final class CompanionJeiPlugin implements IModPlugin {
    private static final ResourceLocation UID = ResourceLocation.fromNamespaceAndPath(
        MythicCompanions.MOD_ID, "diet_guide"
    );

    @Override
    public ResourceLocation getPluginUid() {
        return UID;
    }

    @Override
    public void registerRecipes(IRecipeRegistration registration) {
        for (CompanionRules.Diet diet : CompanionRules.Diet.values()) {
            List<ItemStack> foods = CompanionRules.foodsFor(diet).stream()
                .sorted()
                .map(ResourceLocation::parse)
                .map(ForgeRegistries.ITEMS::getValue)
                .filter(Objects::nonNull)
                .map(ItemStack::new)
                .toList();

            String species = CompanionRules.species().stream()
                .filter(entry -> entry.diet() == diet)
                .sorted(Comparator.comparing(CompanionRules.Species::displayName))
                .map(CompanionRules.Species::displayName)
                .reduce((left, right) -> left + ", " + right)
                .orElse("");

            registration.addItemStackInfo(
                foods,
                Component.translatable("jei.mythic_companions." + diet.name().toLowerCase()),
                Component.translatable("jei.mythic_companions.tames", species),
                Component.translatable("jei.mythic_companions.instructions")
            );
        }

        CompanionRules.species().forEach(entry -> addSpeciesInfo(registration, entry));

        addInfo(
            registration,
            "shineals_prehistoric_expansion:juniper_berries",
            "jei.mythic_companions.anurognathus"
        );
        addInfo(registration, "minecraft:cod", "jei.mythic_companions.hippocampus");
        addInfo(registration, "minecraft:grass_block", "jei.mythic_companions.triceratops");
        addInfo(
            registration,
            "shineals_prehistoric_expansion:fur_saddle",
            "jei.mythic_companions.triceratops"
        );
    }

    private static void addInfo(IRecipeRegistration registration, String itemId, String translationKey) {
        Item item = ForgeRegistries.ITEMS.getValue(ResourceLocation.parse(itemId));
        if (item != null) {
            registration.addItemStackInfo(new ItemStack(item), Component.translatable(translationKey));
        }
    }

    private static void addSpeciesInfo(IRecipeRegistration registration, CompanionRules.Species species) {
        ResourceLocation entityId = ResourceLocation.parse(species.entityId());
        ResourceLocation eggId = ResourceLocation.fromNamespaceAndPath(
            entityId.getNamespace(), entityId.getPath() + "_spawn_egg"
        );
        Item egg = ForgeRegistries.ITEMS.getValue(eggId);
        if (egg == null) {
            return;
        }
        registration.addItemStackInfo(
            new ItemStack(egg),
            Component.translatable(
                "jei.mythic_companions.species",
                species.displayName(),
                species.bondDenominator(),
                Component.translatable("jei.mythic_companions.habitat." + species.habitat().name().toLowerCase())
            )
        );
    }
}

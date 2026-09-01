package com.mythicprehistory.companions;

import java.util.Optional;
import java.util.UUID;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.Tag;
import net.minecraft.world.entity.Entity;

public final class CompanionData {
    private static final String ROOT = "MythicCompanion";
    private static final String OWNER = "Owner";
    private static final String STAYING = "Staying";
    private static final String DEFENSE_TARGET = "DefenseTarget";

    private CompanionData() {}

    public static boolean isCompanion(Entity entity) {
        return existingData(entity).map(tag -> tag.hasUUID(OWNER)).orElse(false);
    }

    public static Optional<UUID> owner(Entity entity) {
        return existingData(entity)
            .filter(tag -> tag.hasUUID(OWNER))
            .map(tag -> tag.getUUID(OWNER));
    }

    public static void bond(Entity entity, UUID owner) {
        CompoundTag data = data(entity);
        data.putUUID(OWNER, owner);
        data.putBoolean(STAYING, false);
        data.remove(DEFENSE_TARGET);
    }

    public static boolean isOwner(Entity entity, UUID playerId) {
        return owner(entity).map(playerId::equals).orElse(false);
    }

    public static boolean isStaying(Entity entity) {
        return existingData(entity).map(tag -> tag.getBoolean(STAYING)).orElse(false);
    }

    public static boolean toggleStaying(Entity entity) {
        boolean staying = CompanionRules.toggleStay(isStaying(entity));
        data(entity).putBoolean(STAYING, staying);
        return staying;
    }

    public static Optional<UUID> defenseTarget(Entity entity) {
        return existingData(entity)
            .filter(tag -> tag.hasUUID(DEFENSE_TARGET))
            .map(tag -> tag.getUUID(DEFENSE_TARGET));
    }

    public static void setDefenseTarget(Entity entity, UUID target) {
        data(entity).putUUID(DEFENSE_TARGET, target);
    }

    public static void clearDefenseTarget(Entity entity) {
        existingData(entity).ifPresent(tag -> tag.remove(DEFENSE_TARGET));
    }

    private static Optional<CompoundTag> existingData(Entity entity) {
        CompoundTag persistent = entity.getPersistentData();
        return persistent.contains(ROOT, Tag.TAG_COMPOUND)
            ? Optional.of(persistent.getCompound(ROOT))
            : Optional.empty();
    }

    private static CompoundTag data(Entity entity) {
        CompoundTag persistent = entity.getPersistentData();
        if (!persistent.contains(ROOT, Tag.TAG_COMPOUND)) {
            persistent.put(ROOT, new CompoundTag());
        }
        return persistent.getCompound(ROOT);
    }
}

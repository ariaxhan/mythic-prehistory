package com.mythicprehistory.companions;

import java.util.Optional;
import java.util.UUID;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.tags.FluidTags;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.AABB;
import net.minecraftforge.event.entity.living.LivingAttackEvent;
import net.minecraftforge.event.entity.living.LivingChangeTargetEvent;
import net.minecraftforge.event.entity.living.LivingEvent;
import net.minecraftforge.event.entity.living.LivingHurtEvent;
import net.minecraftforge.event.entity.player.AttackEntityEvent;
import net.minecraftforge.event.entity.player.PlayerInteractEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.registries.ForgeRegistries;

@Mod.EventBusSubscriber(modid = MythicCompanions.MOD_ID, bus = Mod.EventBusSubscriber.Bus.FORGE)
public final class CompanionEvents {
    private static final double COMMAND_RANGE = 32.0D;
    private static final double TELEPORT_RANGE_SQUARED = 24.0D * 24.0D;

    private CompanionEvents() {}

    @SubscribeEvent
    public static void onInteract(PlayerInteractEvent.EntityInteract event) {
        if (event.getLevel().isClientSide() || !(event.getEntity() instanceof ServerPlayer player)) {
            return;
        }

        Entity target = event.getTarget();
        String entityId = registryId(ForgeRegistries.ENTITY_TYPES.getKey(target.getType()));
        Optional<CompanionRules.Diet> diet = dietFor(target);
        if (diet.isEmpty() || !(target instanceof Mob mob)) {
            return;
        }

        ItemStack stack = event.getItemStack();
        if (CompanionData.isCompanion(target)) {
            handleOwnedInteraction(event, player, mob, diet.get(), stack);
            return;
        }

        String itemId = registryId(ForgeRegistries.ITEMS.getKey(stack.getItem()));
        if (!CompanionRules.foodsFor(diet.get()).contains(itemId)) {
            return;
        }

        consumeOne(player, stack);
        int denominator = CompanionRules.bondDenominator(entityId);
        if (CompanionRules.bondSucceeds(entityId, mob.getRandom().nextInt(denominator))) {
            CompanionData.bond(mob, player.getUUID());
            mob.setPersistenceRequired();
            mob.setTarget(null);
            particles((ServerLevel) event.getLevel(), mob, true);
            player.displayClientMessage(
                Component.translatable("message.mythic_companions.bonded", mob.getDisplayName()), true
            );
        } else {
            particles((ServerLevel) event.getLevel(), mob, false);
            player.displayClientMessage(
                Component.translatable("message.mythic_companions.bond_failed", mob.getDisplayName()), true
            );
        }
        consumeEvent(event);
    }

    private static void handleOwnedInteraction(
        PlayerInteractEvent.EntityInteract event,
        ServerPlayer player,
        Mob mob,
        CompanionRules.Diet diet,
        ItemStack stack
    ) {
        if (!CompanionData.isOwner(mob, player.getUUID())) {
            if (CompanionRules.foodsFor(diet).contains(registryId(ForgeRegistries.ITEMS.getKey(stack.getItem())))) {
                player.displayClientMessage(
                    Component.translatable("message.mythic_companions.owned", mob.getDisplayName()), true
                );
                consumeEvent(event);
            }
            return;
        }

        if (player.isShiftKeyDown() && stack.isEmpty()) {
            boolean staying = CompanionData.toggleStaying(mob);
            mob.getNavigation().stop();
            player.displayClientMessage(
                Component.translatable(
                    staying ? "message.mythic_companions.staying" : "message.mythic_companions.following",
                    mob.getDisplayName()
                ),
                true
            );
            consumeEvent(event);
            return;
        }

        if (mob.getHealth() < mob.getMaxHealth()
            && CompanionRules.foodsFor(diet).contains(registryId(ForgeRegistries.ITEMS.getKey(stack.getItem())))) {
            consumeOne(player, stack);
            mob.heal(4.0F);
            particles((ServerLevel) event.getLevel(), mob, true);
            consumeEvent(event);
        }
    }

    @SubscribeEvent
    public static void onTargetChange(LivingChangeTargetEvent event) {
        if (!(event.getEntity() instanceof Mob mob) || !CompanionData.isCompanion(mob)) {
            return;
        }
        LivingEntity next = event.getNewTarget();
        if (next == null) {
            return;
        }
        Optional<UUID> allowed = CompanionData.defenseTarget(mob);
        if (allowed.isEmpty() || !allowed.get().equals(next.getUUID())) {
            event.setNewTarget(null);
        }
    }

    @SubscribeEvent
    public static void onLivingAttack(LivingAttackEvent event) {
        Entity attacker = event.getSource().getEntity();
        LivingEntity victim = event.getEntity();

        if (attacker instanceof Player player
            && CompanionData.isCompanion(victim)
            && CompanionRules.shouldCancelFriendlyFire(
                CompanionData.owner(victim).map(UUID::toString).orElse(null), player.getUUID()
            )) {
            event.setCanceled(true);
            return;
        }

        if (attacker != null && CompanionData.isCompanion(attacker)) {
            if (victim instanceof Player) {
                event.setCanceled(true);
                return;
            }
            Optional<UUID> attackerOwner = CompanionData.owner(attacker);
            Optional<UUID> victimOwner = CompanionData.owner(victim);
            if (attackerOwner.isPresent() && attackerOwner.equals(victimOwner)) {
                event.setCanceled(true);
            }
        }
    }

    @SubscribeEvent
    public static void onOwnerAttacks(AttackEntityEvent event) {
        if (event.getEntity().level().isClientSide() || !(event.getTarget() instanceof LivingEntity target)
            || target instanceof Player) {
            return;
        }
        commandCompanions(event.getEntity(), target);
    }

    @SubscribeEvent
    public static void onOwnerHurt(LivingHurtEvent event) {
        if (!(event.getEntity() instanceof ServerPlayer player)) {
            return;
        }
        Entity attacker = event.getSource().getEntity();
        if (attacker instanceof LivingEntity target && !(target instanceof Player)) {
            commandCompanions(player, target);
        }
    }

    @SubscribeEvent
    public static void onLivingTick(LivingEvent.LivingTickEvent event) {
        if (!(event.getEntity() instanceof Mob mob) || mob.level().isClientSide()
            || !CompanionData.isCompanion(mob)) {
            return;
        }

        if (mob.tickCount % 10 != 0) {
            return;
        }

        Optional<UUID> defense = CompanionData.defenseTarget(mob);
        if (defense.isPresent()) {
            LivingEntity target = mob.getTarget();
            if (target == null || !target.isAlive() || !defense.get().equals(target.getUUID())
                || mob.distanceToSqr(target) > COMMAND_RANGE * COMMAND_RANGE) {
                CompanionData.clearDefenseTarget(mob);
                mob.setTarget(null);
                defense = Optional.empty();
            }
        }

        if (CompanionData.isStaying(mob)) {
            mob.getNavigation().stop();
            mob.setDeltaMovement(0.0D, mob.getDeltaMovement().y, 0.0D);
            return;
        }

        Optional<UUID> ownerId = CompanionData.owner(mob);
        if (ownerId.isEmpty() || !(mob.level() instanceof ServerLevel level)) {
            return;
        }
        Player owner = level.getPlayerByUUID(ownerId.get());
        String entityId = registryId(ForgeRegistries.ENTITY_TYPES.getKey(mob.getType()));
        if (owner == null || !CompanionRules.canFollowOwner(entityId, owner.isInWaterOrBubble())
            || !CompanionRules.shouldFollow(false, defense.isPresent(), mob.distanceToSqr(owner))) {
            return;
        }

        if (mob.distanceToSqr(owner) > TELEPORT_RANGE_SQUARED) {
            tryTeleportNearOwner(mob, owner, CompanionRules.habitatFor(entityId).orElseThrow());
        }
        mob.getNavigation().moveTo(owner, 1.15D);
    }

    private static void commandCompanions(Player owner, LivingEntity target) {
        if (!(owner.level() instanceof ServerLevel level)) {
            return;
        }
        AABB area = owner.getBoundingBox().inflate(COMMAND_RANGE);
        for (Mob mob : level.getEntitiesOfClass(
            Mob.class,
            area,
            candidate -> CompanionData.isOwner(candidate, owner.getUUID()) && !CompanionData.isStaying(candidate)
        )) {
            CompanionData.setDefenseTarget(mob, target.getUUID());
            mob.setTarget(target);
        }
    }

    private static void tryTeleportNearOwner(Mob mob, Player owner, CompanionRules.Habitat habitat) {
        for (int attempt = 0; attempt < 8; attempt++) {
            double x = owner.getX() + mob.getRandom().nextInt(9) - 4;
            double y = owner.getY() + (habitat == CompanionRules.Habitat.AQUATIC
                ? mob.getRandom().nextInt(5) - 2
                : 0);
            double z = owner.getZ() + mob.getRandom().nextInt(9) - 4;
            BlockPos destination = BlockPos.containing(x, y, z);
            if (habitat == CompanionRules.Habitat.AQUATIC
                && !mob.level().getFluidState(destination).is(FluidTags.WATER)) {
                continue;
            }
            if (mob.randomTeleport(x, y, z, true)) {
                return;
            }
        }
    }

    private static Optional<CompanionRules.Diet> dietFor(Entity entity) {
        return CompanionRules.dietFor(registryId(ForgeRegistries.ENTITY_TYPES.getKey(entity.getType())));
    }

    private static String registryId(ResourceLocation id) {
        return id == null ? "" : id.toString();
    }

    private static void consumeOne(Player player, ItemStack stack) {
        if (!player.getAbilities().instabuild) {
            stack.shrink(1);
        }
    }

    private static void consumeEvent(PlayerInteractEvent.EntityInteract event) {
        event.setCancellationResult(InteractionResult.SUCCESS);
        event.setCanceled(true);
    }

    private static void particles(ServerLevel level, Mob mob, boolean success) {
        level.sendParticles(
            success ? ParticleTypes.HEART : ParticleTypes.SMOKE,
            mob.getX(), mob.getY() + mob.getBbHeight() * 0.65D, mob.getZ(),
            success ? 7 : 5,
            mob.getBbWidth() * 0.35D, mob.getBbHeight() * 0.25D, mob.getBbWidth() * 0.35D,
            0.05D
        );
    }
}

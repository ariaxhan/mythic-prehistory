package com.mythicprehistory.companions;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class LootCatalog {
    public enum Tier {
        DISCOVERY,
        RARE,
        JACKPOT
    }

    public record Entry(String itemId, int weight) {
        public Entry {
            if (!itemId.matches("[a-z0-9_.-]+:[a-z0-9_./-]+")) {
                throw new IllegalArgumentException("Invalid item id: " + itemId);
            }
            if (weight < 1) {
                throw new IllegalArgumentException("Weight must be positive: " + weight);
            }
        }
    }

    private final Map<Tier, List<Entry>> entries;

    private LootCatalog(Map<Tier, List<Entry>> entries) {
        this.entries = entries;
    }

    public static LootCatalog bundled() {
        InputStream stream = LootCatalog.class.getResourceAsStream("/mythic-loot-catalog.tsv");
        if (stream == null) {
            throw new IllegalStateException("Missing mythic-loot-catalog.tsv");
        }
        try (stream) {
            return parse(stream);
        } catch (IOException exception) {
            throw new IllegalStateException("Could not load mythic loot catalog", exception);
        }
    }

    static LootCatalog parse(InputStream stream) throws IOException {
        Map<Tier, List<Entry>> parsed = new EnumMap<>(Tier.class);
        for (Tier tier : Tier.values()) {
            parsed.put(tier, new ArrayList<>());
        }
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
            String line;
            int lineNumber = 0;
            while ((line = reader.readLine()) != null) {
                lineNumber++;
                String trimmed = line.trim();
                if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                    continue;
                }
                String[] fields = trimmed.split("\\t");
                if (fields.length != 3) {
                    throw new IllegalArgumentException("Catalog line " + lineNumber + " must have three tab-separated fields");
                }
                Tier tier = Tier.valueOf(fields[0].toUpperCase(Locale.ROOT));
                Entry entry = new Entry(fields[2], Integer.parseInt(fields[1]));
                if (parsed.get(tier).stream().anyMatch(existing -> existing.itemId().equals(entry.itemId()))) {
                    throw new IllegalArgumentException("Duplicate " + tier + " item: " + entry.itemId());
                }
                parsed.get(tier).add(entry);
            }
        }
        for (Tier tier : Tier.values()) {
            if (parsed.get(tier).isEmpty()) {
                throw new IllegalArgumentException("Catalog tier is empty: " + tier);
            }
            parsed.put(tier, List.copyOf(parsed.get(tier)));
        }
        return new LootCatalog(Map.copyOf(parsed));
    }

    public List<Entry> entries(Tier tier) {
        return entries.get(tier);
    }

    public Entry pick(Tier tier, int roll) {
        List<Entry> pool = entries(tier);
        int total = pool.stream().mapToInt(Entry::weight).sum();
        if (roll < 0 || roll >= total) {
            throw new IllegalArgumentException("Roll " + roll + " outside 0.." + (total - 1));
        }
        int cursor = roll;
        for (Entry entry : pool) {
            cursor -= entry.weight();
            if (cursor < 0) {
                return entry;
            }
        }
        throw new IllegalStateException("Weighted selection exhausted unexpectedly");
    }

    public int totalWeight(Tier tier) {
        return entries(tier).stream().mapToInt(Entry::weight).sum();
    }
}

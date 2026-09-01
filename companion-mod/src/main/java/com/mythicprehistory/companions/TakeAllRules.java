package com.mythicprehistory.companions;

import java.util.stream.IntStream;

public final class TakeAllRules {
    private TakeAllRules() {
    }

    public static int[] sourceSlots(int rowCount) {
        if (rowCount < 1 || rowCount > 6) {
            throw new IllegalArgumentException("Chest row count must be between 1 and 6");
        }
        return IntStream.range(0, rowCount * 9).toArray();
    }
}

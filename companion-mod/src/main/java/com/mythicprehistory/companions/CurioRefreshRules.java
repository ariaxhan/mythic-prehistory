package com.mythicprehistory.companions;

import java.util.stream.IntStream;

public final class CurioRefreshRules {
    private CurioRefreshRules() {
    }

    public static int[] occupiedSlots(boolean... occupied) {
        return IntStream.range(0, occupied.length).filter(index -> occupied[index]).toArray();
    }

    public static int refreshPreviousCount(int currentCount) {
        if (currentCount < 1) {
            throw new IllegalArgumentException("Only occupied slots can be refreshed");
        }
        return currentCount == Integer.MAX_VALUE ? currentCount - 1 : currentCount + 1;
    }
}

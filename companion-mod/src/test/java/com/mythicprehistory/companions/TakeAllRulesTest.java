package com.mythicprehistory.companions;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

final class TakeAllRulesTest {
    @Test
    void selectsOnlyChestSlotsForThreeRows() {
        assertArrayEquals(range(27), TakeAllRules.sourceSlots(3));
    }

    @Test
    void supportsSingleAndDoubleChestMenus() {
        assertArrayEquals(range(9), TakeAllRules.sourceSlots(1));
        assertArrayEquals(range(54), TakeAllRules.sourceSlots(6));
    }

    @Test
    void rejectsImpossibleChestRows() {
        assertThrows(IllegalArgumentException.class, () -> TakeAllRules.sourceSlots(0));
        assertThrows(IllegalArgumentException.class, () -> TakeAllRules.sourceSlots(7));
    }

    private static int[] range(int size) {
        int[] values = new int[size];
        for (int index = 0; index < size; index++) {
            values[index] = index;
        }
        return values;
    }
}

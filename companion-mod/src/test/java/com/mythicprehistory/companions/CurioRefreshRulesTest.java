package com.mythicprehistory.companions;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

final class CurioRefreshRulesTest {
    @Test
    void refreshesOnlyOccupiedEquipmentSlots() {
        assertArrayEquals(new int[] {0, 2, 4}, CurioRefreshRules.occupiedSlots(true, false, true, false, true));
    }

    @Test
    void emptyHandlersRequireNoRefresh() {
        assertArrayEquals(new int[0], CurioRefreshRules.occupiedSlots(false, false));
    }

    @Test
    void previousCopyUsesDifferentCountToTriggerNormalReequip() {
        assertEquals(2, CurioRefreshRules.refreshPreviousCount(1));
        assertThrows(IllegalArgumentException.class, () -> CurioRefreshRules.refreshPreviousCount(0));
    }
}

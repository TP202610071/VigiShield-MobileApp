package com.vigishield.app.validation

import org.junit.Assert.*
import org.junit.Test

/** Host-only: never creates a phone Intent or calls an Android service. */
class TestCallGateTest {
    @Test fun cannotArmOrConsumeWhileNotResumed() {
        val gate = TestCallGate()
        assertFalse(gate.armed)
        assertFalse(gate.setArmed(true, permission = true))
        assertFalse(gate.consume(permission = true))
    }
    @Test fun armingRequiresPermissionAndIsOneShot() {
        val gate = TestCallGate()
        gate.setResumed(true)
        assertFalse(gate.setArmed(true, permission = false))
        assertTrue(gate.setArmed(true, permission = true))
        assertTrue(gate.consume(permission = true))
        assertFalse(gate.consume(permission = true))
    }
    @Test fun pauseDisarmsAndResumeDoesNotRearm() {
        val gate = TestCallGate()
        gate.setResumed(true)
        gate.setArmed(true, permission = true)
        gate.setResumed(false)
        gate.setResumed(true)
        assertFalse(gate.armed)
        assertFalse(gate.consume(permission = true))
    }
    @Test fun revokedPermissionConsumesTheOptInWithoutCalling() {
        val gate = TestCallGate()
        gate.setResumed(true)
        gate.setArmed(true, permission = true)
        assertFalse(gate.consume(permission = false))
        assertFalse(gate.consume(permission = true))
    }
}

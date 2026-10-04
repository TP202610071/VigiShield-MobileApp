package com.vigishield.app.validation

import org.junit.Assert.*
import org.junit.Test

class CaptureSessionGateTest {
    @Test fun consentCanStartOnlyOneCapture() {
        val gate = CaptureSessionGate()
        val id = gate.begin()
        assertTrue(gate.claim(id))
        assertFalse(gate.claim(id))
    }
    @Test fun cancellationRejectsAnAlreadyQueuedServiceStart() {
        val gate = CaptureSessionGate()
        val id = gate.begin()
        gate.cancel()
        assertFalse(gate.claim(id))
        assertFalse(gate.isCurrent(id))
    }
    @Test fun staleServiceCannotCancelNewConsent() {
        val gate = CaptureSessionGate()
        val old = gate.begin()
        gate.cancel()
        val fresh = gate.begin()
        gate.cancel(old)
        assertFalse(gate.claim(old))
        assertTrue(gate.isCurrent(fresh))
        assertTrue(gate.claim(fresh))
    }
}

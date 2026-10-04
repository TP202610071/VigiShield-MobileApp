package com.vigishield.app.validation

import org.junit.Assert.*
import org.junit.Test

class ValidationCoreTest {
    @Test fun onlyExactAllowlistedNumberCanBeCalled() {
        assertEquals("+51986913791", TestCallPolicy.NUMBER)
        assertTrue(TestCallPolicy.allowed("+51986913791", true, true))
        listOf("105", "+51105", "tel:+51986913791", "+51986913791;105", "").forEach {
            assertFalse(TestCallPolicy.allowed(it, true, true))
        }
        assertFalse(TestCallPolicy.allowed(TestCallPolicy.NUMBER, false, true))
        assertFalse(TestCallPolicy.allowed(TestCallPolicy.NUMBER, true, false))
    }

    @Test fun oldKeyframeCannotKeepAnUnboundedTimeWindowAlive() {
        val ring = SampleRing(10_000_000, 100)
        ring.add(EncodedSample(0, byteArrayOf(1), true))
        ring.add(EncodedSample(30_000_000, byteArrayOf(2), false))
        assertTrue(ring.before(30_000_000).isEmpty())
    }

    @Test fun eventTimeAlsoBoundsPreRollAfterEncoderStalls() {
        val ring = SampleRing(10_000_000, 100)
        ring.add(EncodedSample(0, byteArrayOf(1), true))
        assertTrue(ring.before(30_000_000).isEmpty())
    }

    @Test fun ringStartsAtKeyframeAndReportsShortWarmup() {
        val ring = SampleRing(10_000_000, 100)
        ring.add(EncodedSample(8_000_000, byteArrayOf(1), true))
        ring.add(EncodedSample(9_000_000, byteArrayOf(2), false))
        val selected = ring.before(10_000_000)
        assertEquals(8_000_000, selected.first().ptsUs)
        assertEquals(2_000_000, 10_000_000 - selected.first().ptsUs)
    }
}

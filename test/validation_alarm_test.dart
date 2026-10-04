import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/providers/validation_alarm.dart';

void main() {
  test('cancel latches incident until fresh normal', () {
    final a = ValidationAlarm(sustainSeconds: 2);
    a.sample(now: 0, timestamp: 0, risky: true);
    a.sample(now: 2, timestamp: 2, risky: true);
    a.cancel();
    a.sample(now: 4, timestamp: 4, risky: true);
    expect(a.counting, false);
    a.sample(now: 6, timestamp: 6, risky: false);
    a.sample(now: 8, timestamp: 8, risky: true);
    a.sample(now: 10, timestamp: 10, risky: true);
    expect(a.counting, true);
  });
  test('timer fires once and never when unarmed; mute disarms', () {
    final a = ValidationAlarm(sustainSeconds: 2, countdownSeconds: 2);
    a.sample(now: 0, timestamp: 0, risky: true);
    a.sample(now: 2, timestamp: 2, risky: true);
    expect(a.tick(4, armed: false), false);
    expect(a.tick(4, armed: true), false);
    final b = ValidationAlarm(sustainSeconds: 2, countdownSeconds: 2);
    b.sample(now: 0, timestamp: 0, risky: true);
    b.sample(now: 2, timestamp: 2, risky: true);
    expect(b.tick(4, armed: true), true);
    expect(b.tick(4, armed: true), false);
    b.cancel();
    expect(b.counting, false);
  });
  test('missing feed cancels countdown even with no new sample', () {
    final a = ValidationAlarm(sustainSeconds: 2);
    a.sample(now: 0, timestamp: 0, risky: true);
    a.sample(now: 2, timestamp: 2, risky: true);
    expect(a.tick(13, armed: true), false);
    expect(a.counting, false);
  });
  test('stale and duplicate samples cannot accumulate risk', () {
    final a = ValidationAlarm();
    a.sample(now: 0, timestamp: 0, risky: true);
    a.sample(now: 31, timestamp: 0, risky: true);
    expect(a.counting, false);
    a.sample(now: 32, timestamp: 32, risky: true);
    expect(a.counting, false);
  });
  test('only continuous fresh suspect intent opens a countdown', () {
    final alarm = ValidationAlarm();
    for (var t = 0.0; t < 30; t += 2) {
      alarm.sample(now: t, timestamp: t, risky: true);
      expect(alarm.counting, false);
    }
    alarm.sample(now: 30, timestamp: 30, risky: true);
    expect(alarm.counting, true);
    expect(alarm.remaining(30), 30);
  });
}

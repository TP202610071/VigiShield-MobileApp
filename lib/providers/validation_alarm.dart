/// Pure, per-camera foreground risk accumulator. Times are seconds.
class ValidationAlarm {
  ValidationAlarm({this.sustainSeconds = 30, this.countdownSeconds = 30});
  final int sustainSeconds;
  final int countdownSeconds;
  double? _since;
  double? _deadline;
  double? _last;
  bool _latched = false;
  void cancel() { _latched = true; _since = null; _deadline = null; }
  void missing() { _since = null; _deadline = null; }
  bool tick(double now, {required bool armed}) {
    if (_last == null || now - _last! > 5) { missing(); return false; }
    if (_deadline == null || now < _deadline!) return false;
    cancel();
    return armed;
  }
  bool get counting => _deadline != null;
  void sample({required double now, required double timestamp, required bool risky}) {
    if (now - timestamp > 10 || timestamp > now + 2) { _since = null; _deadline = null; return; }
    if (_last != null && timestamp <= _last!) return;
    if (_last != null && timestamp - _last! > 5) { _since = null; _deadline = null; }
    _last = timestamp;
    if (!risky) { _latched = false; _since = null; _deadline = null; return; }
    if (_latched) return;
    _since ??= timestamp;
    if (timestamp - _since! >= sustainSeconds) _deadline ??= now + countdownSeconds;
  }
  int remaining(double now) => _deadline == null ? 0 : (_deadline! - now).ceil().clamp(0, countdownSeconds);
}

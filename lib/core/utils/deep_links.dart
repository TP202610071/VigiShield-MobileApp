/// Holds a deep-link target captured at cold start (before the router/auth are
/// ready) so the splash can route to it once the user is authenticated. Warm
/// links (app already running) are navigated immediately in main.dart.
class DeepLinks {
  static String? pendingEventId;
}

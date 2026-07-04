import 'dart:async';
import 'dart:io';

/// A camera found on the local network.
class FoundCamera {
  final String ip;
  final bool hasWebUi; // port 80 open too (likely an IP camera / NVR web page)
  const FoundCamera(this.ip, this.hasWebUi);
}

/// Scans the phone's local /24 subnet for devices with the RTSP port (554) open —
/// i.e. likely IP cameras — so the user can add one without typing the IP by hand.
/// Package-free: derives the subnet from the device's own LAN interface and does
/// concurrent TCP connects.
class LanScanner {
  static const int rtspPort = 554;
  static const int httpPort = 80;

  /// The device's private LAN /24 base, e.g. "192.168.1", or null if not on a LAN.
  static Future<String?> localSubnet() async {
    try {
      final ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (_isPrivate(ip)) {
            final p = ip.split('.');
            return '${p[0]}.${p[1]}.${p[2]}';
          }
        }
      }
    } catch (_) {/* fall through */}
    return null;
  }

  /// Scan the whole /24 for RTSP hosts. Returns found cameras (deduped, sorted).
  static Future<List<FoundCamera>> scan({
    Duration timeout = const Duration(milliseconds: 500),
    void Function(int done, int total)? onProgress,
  }) async {
    final base = await localSubnet();
    if (base == null) return [];

    const total = 254;
    var done = 0;
    final results = <FoundCamera>[];

    Future<void> probe(int i) async {
      final ip = '$base.$i';
      final rtsp = await _isOpen(ip, rtspPort, timeout);
      if (rtsp) {
        final web = await _isOpen(ip, httpPort, const Duration(milliseconds: 300));
        results.add(FoundCamera(ip, web));
      }
      done++;
      onProgress?.call(done, total);
    }

    await Future.wait([for (var i = 1; i <= total; i++) probe(i)]);
    results.sort((a, b) => _ipKey(a.ip).compareTo(_ipKey(b.ip)));
    return results;
  }

  static Future<bool> _isOpen(String host, int port, Duration timeout) async {
    Socket? s;
    try {
      s = await Socket.connect(host, port, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      s?.destroy();
    }
  }

  static bool _isPrivate(String ip) {
    if (ip.startsWith('192.168.') || ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final second = int.tryParse(ip.split('.')[1]) ?? 0;
      return second >= 16 && second <= 31;
    }
    return false;
  }

  static int _ipKey(String ip) => int.parse(ip.split('.').last);
}

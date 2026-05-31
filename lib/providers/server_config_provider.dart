import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/storage/auth_storage.dart';

class ServerConfigProvider extends ChangeNotifier {
  final AuthStorage _storage;
  final ApiClient _api;

  String _serverUrl;
  bool _isSaving = false;

  ServerConfigProvider(this._storage, this._api, String initialUrl)
      : _serverUrl = initialUrl;

  String get serverUrl => _serverUrl;
  bool get isSaving => _isSaving;

  bool get isEmulatorDefault => _serverUrl == AppConstants.defaultEmulatorUrl;

  /// Change the backend URL. Returns true on success.
  /// Caller is responsible for logging out the user afterwards if needed.
  Future<bool> updateServerUrl(String rawUrl) async {
    final url = _normalise(rawUrl);
    if (url.isEmpty) return false;

    _isSaving = true;
    notifyListeners();

    try {
      _api.updateBaseUrl(url);
      await _storage.saveServerUrl(url);
      _serverUrl = url;
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  static String _normalise(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return '';
    // Add http:// if no scheme provided
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    // Strip trailing slash
    return url.replaceAll(RegExp(r'/$'), '');
  }

  /// Nice label for display (strips http://)
  String get displayUrl => _serverUrl.replaceAll(RegExp(r'^https?://'), '');
}

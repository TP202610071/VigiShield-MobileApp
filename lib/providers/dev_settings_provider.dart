import 'package:flutter/foundation.dart';
import '../core/storage/auth_storage.dart';
import '../data/models/user_model.dart';

/// Holds the admin-only "role preview" overlay used for demos. The real account
/// role (from [AuthProvider]) is never changed — this only alters what the UI
/// shows so an administrator can present the app as a Primary/Secondary user.
/// Only effective when the real user is an Admin.
class DevSettingsProvider extends ChangeNotifier {
  final AuthStorage _storage;
  String? _previewRole; // null | 'Admin' | 'Primary' | 'Secondary'

  DevSettingsProvider(this._storage, this._previewRole);

  String? get previewRole => _previewRole;

  Future<void> setPreviewRole(String? role) async {
    _previewRole = role;
    notifyListeners();
    await _storage.savePreviewRole(role);
  }

  /// Role the UI should behave as for [user]. Preview only applies to admins.
  String? effectiveRole(UserModel? user) {
    if (user == null) return null;
    if (user.isAdmin && _previewRole != null) return _previewRole;
    return user.role;
  }

  bool isPrimaryEffective(UserModel? user) {
    final r = effectiveRole(user);
    return r == 'Primary' || r == 'Admin';
  }

  /// True while a real admin is actively previewing a non-admin role.
  bool isPreviewing(UserModel? user) =>
      (user?.isAdmin ?? false) && _previewRole != null && _previewRole != 'Admin';

  static Future<String?> load(AuthStorage storage) => storage.getPreviewRole();
}

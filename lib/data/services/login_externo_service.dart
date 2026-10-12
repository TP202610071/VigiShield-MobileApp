import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/network/api_client.dart';
import '../models/user_model.dart';

/// Lo que hace falta para «Continuar con Apple» en Android, que va por la web
/// de Apple. Lo da el backend solo si el Services ID está configurado.
class AppleAndroid {
  final String serviceId;
  final Uri redirectUri;
  const AppleAndroid(this.serviceId, this.redirectUri);
}

/// Iniciar sesión con Apple (y, cuando se configure, con Google).
class LoginExternoService {
  LoginExternoService(this._api);
  final ApiClient _api;

  static bool get esIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get esAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Null si Android no puede ofrecer Apple (o si no hay red).
  Future<AppleAndroid?> configAndroid() async {
    try {
      final data = await _api.get<Map<String, dynamic>>('/api/auth/externo/config');
      final a = data['appleAndroid'];
      if (a is Map && a['serviceId'] is String && a['redirectUri'] is String) {
        return AppleAndroid(a['serviceId'] as String, Uri.parse(a['redirectUri'] as String));
      }
    } catch (_) {}
    return null;
  }

  /// Pide a Apple que el usuario confirme quién es. Lanza
  /// [SignInWithAppleAuthorizationException] si cancela.
  Future<({AuthorizationCredentialAppleID credencial, String nonce})> _credencial(AppleAndroid? android) async {
    final nonce = _nonce();
    final credencial = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      // Apple guarda el SHA-256; el backend recibe el original y lo compara.
      nonce: sha256.convert(utf8.encode(nonce)).toString(),
      webAuthenticationOptions: android == null
          ? null
          : WebAuthenticationOptions(clientId: android.serviceId, redirectUri: android.redirectUri),
    );
    if (credencial.identityToken == null) {
      throw const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.failed, message: 'Apple no devolvió el token');
    }
    return (credencial: credencial, nonce: nonce);
  }

  Future<({String token, UserModel user})> conApple({AppleAndroid? android}) async {
    final (:credencial, :nonce) = await _credencial(android);
    final nombre = [credencial.givenName, credencial.familyName]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');
    final data = await _api.post<Map<String, dynamic>>('/api/auth/apple', body: {
      'identityToken': credencial.identityToken,
      'authorizationCode': credencial.authorizationCode,
      'nonce': nonce,
      'nombre': nombre.isEmpty ? null : nombre,
      'plataforma': android == null ? 'ios' : 'android',
    });
    return (token: data['token'] as String, user: UserModel.fromJson(data['user'] as Map<String, dynamic>));
  }

  /// Con qué está vinculada la cuenta. Ante un error, como si no tuviera nada.
  Future<({bool apple, bool google, bool tieneContrasena})> estado() async {
    try {
      final d = await _api.get<Map<String, dynamic>>('/api/auth/externo');
      return (
        apple: d['apple'] == true,
        google: d['google'] == true,
        tieneContrasena: d['tieneContrasena'] != false,
      );
    } catch (_) {
      return (apple: false, google: false, tieneContrasena: true);
    }
  }

  /// Borra la cuenta confirmando con Apple (para quien no tiene contraseña).
  Future<void> eliminarConApple({AppleAndroid? android}) async {
    final (:credencial, :nonce) = await _credencial(android);
    await _api.post<Map<String, dynamic>>('/api/auth/delete-account/apple', body: {
      'identityToken': credencial.identityToken,
      'nonce': nonce,
    });
  }

  static String _nonce([int largo = 32]) {
    const letras = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(largo, (_) => letras[r.nextInt(letras.length)]).join();
  }
}

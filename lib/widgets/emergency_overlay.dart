import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_localizations.dart';
import '../providers/emergency_provider.dart';

/// Encima del router, no como ruta: cambiar de pestaña o volver atrás no puede
/// esconder el botón de desactivar.
class EmergencyOverlay extends StatelessWidget {
  const EmergencyOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EmergencyProvider>();
    final l10n = context.l10n;
    final number = p.settings.willCall ? p.settings.callableNumber : null;
    return Stack(fit: StackFit.expand, children: [
      child,
      if (p.counting)
        Positioned.fill(
          child: BlockSemantics(
            child: Material(
              color: const Color(0xFF3A0D0D),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.warning_amber_rounded, size: 88, color: Colors.amber),
                      const SizedBox(height: 12),
                      Text(p.testing ? l10n.emergencyTestTitle : l10n.emergencyTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(p.cameraName == null
                              ? l10n.emergencyRisk
                              : '${p.cameraName}: ${l10n.emergencyRisk}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.white70)),
                      const SizedBox(height: 24),
                      Text('${p.remaining}',
                          style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w300,
                              color: Colors.white, height: 1)),
                      const SizedBox(height: 16),
                      Text(
                        p.testing || number == null
                            ? l10n.emergencyNoCall
                            : l10n.emergencyWillCall(number),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF3A0D0D),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          onPressed: p.dismiss,
                          child: Text(l10n.emergencyDismiss),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

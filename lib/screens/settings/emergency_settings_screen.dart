import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emergency_settings.dart';
import '../../providers/emergency_provider.dart';

class EmergencySettingsScreen extends StatefulWidget {
  const EmergencySettingsScreen({super.key});

  @override
  State<EmergencySettingsScreen> createState() => _EmergencySettingsScreenState();
}

class _EmergencySettingsScreenState extends State<EmergencySettingsScreen> {
  late final TextEditingController _phone;
  double? _volume; // mientras se arrastra el control, sin guardar cada paso

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: context.read<EmergencyProvider>().settings.phone);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save(EmergencySettings next) => context.read<EmergencyProvider>().update(next);

  /// Al poner un número válido con la llamada activada se pide ya el permiso:
  /// sin él Android solo abre el marcador y no llama.
  Future<void> _guardarNumero(EmergencySettings s, String valor) async {
    final next = s.copyWith(phone: valor.trim());
    await _save(next);
    if (next.willCall && mounted) await context.read<EmergencyProvider>().requestCallPermission();
  }

  Future<void> _setAutoCall(EmergencySettings s, bool value) async {
    // En Android se pide el permiso al activarlo, no en mitad de una alerta.
    if (value) await context.read<EmergencyProvider>().requestCallPermission();
    await _save(s.copyWith(autoCall: value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.watch<EmergencyProvider>();
    final s = p.settings;
    final phoneError = _phone.text.trim().isNotEmpty && normalizePhone(_phone.text) == null;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 6),
          child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.emergencyAlert)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text(l10n.emergencyAlertHint, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.emergencyEnabled),
          subtitle: Text(l10n.emergencyForegroundNote),
          value: s.enabled,
          onChanged: (v) => _save(s.copyWith(enabled: v)),
        ),
        label(l10n.emergencyPhone),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: InputDecoration(
            hintText: l10n.emergencyPhoneHint,
            errorText: phoneError ? l10n.emergencyPhoneInvalid : null,
            errorMaxLines: 3,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) => _guardarNumero(s, v),
          onTapOutside: (_) {
            if (_phone.text.trim() != s.phone) _guardarNumero(s, _phone.text);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.emergencyAutoCall),
          subtitle: Platform.isIOS ? Text(l10n.emergencyIosCallNote) : null,
          value: s.autoCall,
          onChanged: (v) => _setAutoCall(s, v),
        ),
        label(l10n.emergencyVolume),
        Row(children: [
          const Icon(Icons.volume_mute, color: AppColors.textSecondary),
          Expanded(
            child: Slider(
              value: _volume ?? s.volume,
              min: EmergencySettings.minVolume,
              max: 1,
              onChanged: (v) => setState(() => _volume = v),
              onChangeEnd: (v) async {
                await _save(s.copyWith(volume: v));
                if (mounted) setState(() => _volume = null);
              },
            ),
          ),
          const Icon(Icons.volume_up, color: AppColors.textSecondary),
        ]),
        label(l10n.emergencySustain),
        _Options(
          values: EmergencySettings.sustainOptions,
          selected: s.sustainSeconds,
          text: l10n.seconds,
          onSelected: (v) => _save(s.copyWith(sustainSeconds: v)),
        ),
        label(l10n.emergencyCountdown),
        _Options(
          values: EmergencySettings.countdownOptions,
          selected: s.countdownSeconds,
          text: l10n.seconds,
          onSelected: (v) => _save(s.copyWith(countdownSeconds: v)),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text(l10n.emergencyTest),
          onPressed: () {
            // Un número escrito pero aún sin guardar también cuenta.
            if (_phone.text.trim() != s.phone) {
              _guardarNumero(s, _phone.text).then((_) => p.test());
            } else {
              p.test();
            }
          },
        ),
        const SizedBox(height: 6),
        Text(l10n.emergencyTestHint,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ]),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.values, required this.selected,
      required this.text, required this.onSelected});
  final List<int> values;
  final int selected;
  final String Function(int) text;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, children: [
        for (final v in values)
          ChoiceChip(
            label: Text(text(v)),
            selected: v == selected,
            onSelected: (_) => onSelected(v),
          ),
      ]);
}

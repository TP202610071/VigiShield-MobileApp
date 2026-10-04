import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/validation_provider.dart';

class ValidationScreen extends StatelessWidget {
  const ValidationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<ValidationProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Validación en primer plano')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Prueba voluntaria. Solo funciona con la app visible. Pausar, salir o cerrar sesión cancela la alarma y desarma la llamada. No sustituye un servicio de emergencia.'),
        const SizedBox(height: 16),
        FilledButton(onPressed: p.busy ? null : (p.active ? p.stop : p.start), child: Text(p.active ? 'Detener sesión' : 'Iniciar sesión de validación')),
        DropdownButtonFormField<int>(
          initialValue: p.sustainSeconds,
          decoration: const InputDecoration(labelText: 'Intención sospechosa sostenida'),
          items: [30, 60, 90, 120, 180, 300].map((s) => DropdownMenuItem(value:s, child:Text('$s segundos'))).toList(),
          onChanged: p.active ? null : (s) => p.configure(sustain:s!,countdown:30)),
        SwitchListTile(title: const Text('Alarma de prueba'), subtitle: const Text('Personas presentes + intención suspect/high_risk fresca. Sonido bajo y 30 segundos para cancelar.'), value:p.alarmOptIn, onChanged:p.active ? p.setAlarm : null),
        SwitchListTile(title: const Text('Autorizar UNA llamada de prueba'), subtitle: const Text('Solo +51986913791. Nunca 105. Desactivada por defecto; se consume una vez.'), value:p.callOptIn, onChanged:p.active && p.alarmOptIn && p.platform.supported && !p.busy ? p.setCallOptIn : null),
        if (!p.platform.supported) const Text('iOS y otras plataformas: grabación y llamadas no compatibles. Requiere Android.'),
        const Divider(),
        const Text('Grabación de pantalla independiente de la alarma. Android solicitará consentimiento del sistema. Puede capturar información privada de toda la pantalla; sin audio. Búfer nativo: hasta 10 s antes y 10 s después de recibir el evento (no de la hora de detección).'),
        SwitchListTile(title: const Text('Grabar pantalla con consentimiento'), value:p.recording, onChanged:p.active && !p.busy && p.platform.supported ? p.setRecording : null),
        OutlinedButton(onPressed:p.recording ? p.manualMarker : null, child:const Text('Marcador manual de PRUEBA — no llama')),
        if (p.error != null) Text(p.error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
        const Divider(),
        TextButton(onPressed:p.platform.supported ? p.refreshClips : null,child:const Text('Actualizar clips finalizados')),
        for (final clip in p.clips) ListTile(
          title:Text('${clip['eventId'] ?? 'Clip de validación'}'),
          subtitle:Text('${clip['status'] ?? ''} · antes ${clip['preMs'] ?? 0} ms / después ${clip['postMs'] ?? 0} ms\n${clip['reason'] ?? ''}'),
          trailing: clip['path'] is String ? IconButton(tooltip:'Compartir clip',icon:const Icon(Icons.share),onPressed:() async {
            try { await Share.shareXFiles([XFile(clip['path'] as String)],text:'Validación: marcador por llegada del evento, no instante de detección.'); }
            catch (e) { if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('No se pudo compartir: $e'))); }
          }) : null),
      ]),
    );
  }
}

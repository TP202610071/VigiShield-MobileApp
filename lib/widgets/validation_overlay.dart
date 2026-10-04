import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/validation_provider.dart';

/// Above the router, not a route: changing tabs cannot hide the cancel action.
class ValidationOverlay extends StatelessWidget {
  const ValidationOverlay({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<ValidationProvider>();
    return Stack(fit:StackFit.expand, children:[
      child,
      if(p.active && p.banner != null && !p.counting) Positioned(top:0,left:0,right:0,child:SafeArea(child:IgnorePointer(child:Material(color:Colors.black87,child:Padding(padding:const EdgeInsets.all(12),child:Text('EVENTO RECIBIDO EN VIVO\n${p.banner}\nMarcador por llegada, no hora de detección.',style:const TextStyle(color:Colors.white))))))),
      if(p.counting) Positioned.fill(child:BlockSemantics(child:Material(color:const Color(0xff321313),child:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.warning_amber,size:72,color:Colors.amber),
        const Text('ALARMA DE PRUEBA',style:TextStyle(fontSize:26,color:Colors.white)),
        Text('${p.remaining} s',style:const TextStyle(fontSize:64,color:Colors.white)),
        Text(p.callOptIn ? 'Una llamada a +51986913791 al terminar. Nunca 105.' : 'Llamada desarmada. No se llamará a nadie.',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white)),
        const SizedBox(height:24),
        FilledButton(onPressed:p.cancelAlarm,child:const Text('CANCELAR ALARMA Y LLAMADA')),
        const Text('No se repetirá este incidente hasta recibir estado normal fresco.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white70)),
      ]))))))),
    ]);
  }
}

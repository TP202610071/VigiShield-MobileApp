import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/providers/validation_provider.dart';
import 'package:vigishield_mobile_app/data/services/validation_platform.dart';
import 'package:vigishield_mobile_app/screens/settings/validation_screen.dart';
import 'package:vigishield_mobile_app/widgets/validation_overlay.dart';
class UnsupportedHardware extends ValidationPlatform {
 @override bool get supported => false;
}
void main() {
 testWidgets('validation defaults off, unsupported explicit, router child preserved', (tester) async {
  final p=ValidationProvider(platform:UnsupportedHardware(),canMonitor:()=>true,loadPaused:() async=>false,loadCameras:() async=>[],loadEvents:(_) async=>[],loadStatus:(_) async=>{});
  await tester.pumpWidget(ChangeNotifierProvider.value(value:p,child:MaterialApp(builder:(_,child)=>ValidationOverlay(child:child!),home:const ValidationScreen())));
  expect(find.text('Iniciar sesión de validación'),findsOneWidget);
  expect(p.active,false); expect(p.callOptIn,false); expect(p.recording,false);
  expect(find.textContaining('iOS'),findsOneWidget);
  await tester.pumpWidget(const SizedBox()); p.dispose(); await tester.pump();
 });
}

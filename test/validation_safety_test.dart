import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/providers/validation_provider.dart';
import 'package:vigishield_mobile_app/data/services/validation_platform.dart';
import 'package:vigishield_mobile_app/data/models/camera_config_model.dart';
class Hardware extends ValidationPlatform {
  final calls=<String>[];
  Completer<dynamic>? consent;
  @override bool get supported=>true;
  @override Future<dynamic> invoke(String method,[Map<String,dynamic>? args]) async {
    calls.add(method);
    if(method=='startScreenBuffer') return consent?.future ?? {'running':true};
    return true;
  }
}
class PermissionHardware extends Hardware {
  final permission=Completer<bool>();
  @override Future<dynamic> invoke(String method,[Map<String,dynamic>? args]) => method=='requestTestCallPermission' ? permission.future : super.invoke(method,args);
}
void main(){
  testWidgets('normal and unhealthy feeds disarm optional call', (tester) async {
    final h=Hardware();
    final p=ValidationProvider(platform:h,canMonitor:()=>true,loadPaused:() async=>false,
      loadCameras:() async=>[CameraConfigModel.fromJson({'id':'cam','isConfigured':true,'hlsViewUrl':'https://example.test/cam'})],
      loadEvents:(_) async=>[],loadStatus:(_) async=>{'ts':DateTime.now().millisecondsSinceEpoch/1000,'state':'ok','persons':0,'intent':{'state':'suspect'}});
    await p.start(); await tester.pump(); p.setAlarm(true);
    await p.setCallOptIn(true); await p.poll(); await tester.pump();
    expect(p.callOptIn,false);
    p.dispose(); await tester.pump();
  });
  testWidgets('cancel while permission pending cannot rearm', (tester) async {
    final h=PermissionHardware();
    final p=ValidationProvider(platform:h,canMonitor:()=>true,loadPaused:() async=>false,loadCameras:() async=>[],loadEvents:(_) async=>[],loadStatus:(_) async=>{});
    await p.start(); await tester.pump(); p.setAlarm(true);
    final arm=p.setCallOptIn(true); await tester.pump();
    p.cancelAlarm(); h.permission.complete(true); await arm; await tester.pump();
    expect(p.callOptIn,false);
    p.dispose(); await tester.pump();
  });
  testWidgets('native running response and consent inactive are supported', (tester) async {
    final h=Hardware()..consent=Completer<dynamic>();
    final p=ValidationProvider(platform:h,canMonitor:()=>true,loadPaused:() async=>false,
      loadCameras:() async=>[],loadEvents:(_) async=>[],loadStatus:(_) async=>{});
    await p.start(); await tester.pump();
    final start=p.setRecording(true); await tester.pump();
    p.didChangeAppLifecycleState(AppLifecycleState.inactive);
    p.didChangeAppLifecycleState(AppLifecycleState.resumed);
    h.consent!.complete({'running':true}); await start;
    expect(p.recording,true);
    await p.manualMarker(); expect(h.calls.contains('placeTestCall'),false);
    p.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(p.active,false); expect(p.recording,false);
    p.dispose(); await tester.pump();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/services/camera_service.dart';
import 'package:vigishield_mobile_app/providers/camera_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/screens/camera/device_camera_screen.dart';
import 'mobile_camera_publisher_test.dart' show Capture, Transport;
import 'package:vigishield_mobile_app/data/services/mobile_camera_publisher.dart';
void main() {
  testWidgets('background during registration cancels start even after resume', (tester) async {
    final api = ApiClient(AuthStorage());
    RequestInterceptorHandler? pending;
    RequestOptions? request;
    api.dio.interceptors.clear();
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'POST') {
        pending = handler;
        request = options;
      } else {
        handler.resolve(Response(requestOptions: options, statusCode: 200, data: []));
      }
    }));
    final nativeCalls = <String>[];
    const channel = MethodChannel('FlutterWebRTC.Method');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call.method);
      throw PlatformException(code: 'unexpected capture');
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(MultiProvider(providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider(create: (_) => CameraProvider(CameraDataService(api))),
    ], child: const MaterialApp(home: DeviceCameraScreen())));
    await tester.tap(find.text('Iniciar transmisión'));
    await tester.pumpAndSettle();
    expect(pending, isNotNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    pending!.resolve(Response(requestOptions: request!, statusCode: 200,
      data: {'id': 'created', 'name': 'Phone', 'streamMode': 'MobileWebRtc'}));
    await tester.pumpAndSettle();
    expect(nativeCalls, isEmpty);
    expect(find.text('Iniciar transmisión'), findsOneWidget);
    api.dio.close();
  });
  testWidgets('background stops publication and resume never restarts it', (tester) async {
    final transport = Transport();
    final capture = Capture();
    final publisher = MobileCameraPublisher(transport: transport, capture: capture);
    await publisher.start('camera', front: false);
    await tester.pumpWidget(MaterialApp(home: DeviceCameraScreen(publisher: publisher)));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(publisher.isPublishing, isFalse);
    expect(transport.events.last, 'delete:camera:session');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(capture.events.where((e) => e.startsWith('open')), hasLength(1));
    expect(find.text('Iniciar transmisión'), findsOneWidget);
  });
  testWidgets('lens change warns about ROI and stops without restarting', (tester) async {
    final transport = Transport();
    final publisher = MobileCameraPublisher(transport: transport, capture: Capture());
    await publisher.start('camera', front: false);
    await tester.pumpWidget(MaterialApp(home: DeviceCameraScreen(publisher: publisher)));
    await tester.tap(find.text('Frontal'));
    await tester.pumpAndSettle();
    expect(find.textContaining('invalida la calibración'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(publisher.isPublishing, isTrue);
    await tester.tap(find.text('Frontal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    expect(publisher.isPublishing, isFalse);
    expect(transport.events.last, 'delete:camera:session');
    expect(find.text('Iniciar transmisión'), findsOneWidget);
  });
  testWidgets('leaving device screen stops capture and deletes session', (tester) async {
    final transport = Transport();
    final capture = Capture();
    final publisher = MobileCameraPublisher(transport: transport, capture: capture);
    await publisher.start('camera', front: false);
    await tester.pumpWidget(MaterialApp(home: DeviceCameraScreen(publisher: publisher)));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(capture.events.last, 'close');
    expect(transport.events.last, 'delete:camera:session');
  });
  testWidgets('device screen requires explicit start and offers both lenses', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeviceCameraScreen()));
    expect(find.text('Iniciar transmisión'), findsOneWidget);
    expect(find.text('Trasera'), findsOneWidget);
    expect(find.text('Frontal'), findsOneWidget);
    expect(find.textContaining('sin audio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/models/camera_config_model.dart';
import 'package:vigishield_mobile_app/data/models/user_model.dart';
import 'package:vigishield_mobile_app/data/services/auth_service.dart';
import 'package:vigishield_mobile_app/data/services/camera_service.dart';
import 'package:vigishield_mobile_app/providers/auth_provider.dart';
import 'package:vigishield_mobile_app/providers/camera_provider.dart';
import 'package:vigishield_mobile_app/screens/settings/cameras_list_screen.dart';
class TestAuth extends AuthProvider {
  final String role;
  TestAuth(this.role):super(AuthService(ApiClient(AuthStorage())), AuthStorage());
  @override UserModel get user => UserModel(id:'u',email:'x',name:'User',role:role,householdId:'h',createdAt:DateTime(2026));
}
class TestCameras extends CameraProvider {
  TestCameras():super(CameraDataService(ApiClient(AuthStorage())));
  @override Future<void> fetchCameras() async {}
  @override List<CameraConfigModel> get cameras => [CameraConfigModel.fromJson({'id':'c','name':'Phone','streamMode':'MobileWebRtc'})];
}
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final role in ['Primary','Admin','Secondary']) {
    testWidgets('camera list role $role controls mute and device creation', (tester) async {
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => TestAuth(role)),
        ChangeNotifierProvider<CameraProvider>(create: (_) => TestCameras()),
      ], child: const MaterialApp(home: CamerasListScreen())));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), role == 'Secondary' ? findsNothing : findsOneWidget);
      expect(find.text('Cámara del dispositivo'), findsOneWidget);
      if (role != 'Secondary') {
        await tester.tap(find.text('Agregar'));
        await tester.pumpAndSettle();
        expect(find.text('Usar este dispositivo como cámara'), findsOneWidget);
        expect(find.text('Agregar cámara IP'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

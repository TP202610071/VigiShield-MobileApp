import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/services/camera_service.dart';
import 'package:vigishield_mobile_app/providers/camera_provider.dart';

void main() {
  test('failed notification PATCH leaves existing camera and selection intact', () async {
    final api = ApiClient(AuthStorage());
    api.dio.interceptors.clear();
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'GET') {
        handler.resolve(Response(requestOptions: options, statusCode: 200, data: [
          {'id': 'first'}, {'id': 'second', 'notificationsEnabled': true},
        ]));
      } else {
        handler.reject(DioException(requestOptions: options,
          response: Response(requestOptions: options, statusCode: 403),
          type: DioExceptionType.badResponse));
      }
    }));
    final provider = CameraProvider(CameraDataService(api));
    await provider.fetchCameras();
    provider.selectCameraById('second');
    expect(await provider.setNotificationsEnabled('second', false), isFalse);
    expect(provider.selectedCamera!.id, 'second');
    expect(provider.selectedCamera!.notificationsEnabled, isTrue);
    expect(provider.cameras, hasLength(2));
    expect(provider.isSaving, isFalse);
    expect(provider.error, isNotNull);
    provider.dispose();
    api.dio.close();
  });
  test('mute PATCH preserves camera and publisher signaling uses contract', () async {
    final api = ApiClient(AuthStorage());
    final calls = <RequestOptions>[];
    api.dio.interceptors.clear();
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls.add(options);
      final data = options.method == 'GET' ? [{'id': 'c', 'name': 'Phone'}]
        : options.path.endsWith('/notifications') ? {'id': 'c', 'name': 'Phone', 'notificationsEnabled': false}
        : options.method == 'POST' ? {'sessionId': 's', 'sdp': 'answer'} : null;
      handler.resolve(Response(requestOptions: options, data: data, statusCode: 200));
    }));
    final service = CameraDataService(api);
    final provider = CameraProvider(service);
    await provider.fetchCameras();
    expect(await provider.setNotificationsEnabled('c', false), isTrue);
    expect(provider.cameras.single.notificationsEnabled, isFalse);
    expect(calls[1].method, 'PATCH');
    expect(calls[1].path, '/api/stream/cameras/c/notifications');
    expect(calls[1].data, {'enabled': false});
    final answer = await service.publish('c', 'offer');
    expect(answer.sessionId, 's');
    expect(answer.sdp, 'answer');
    expect(calls.last.method, 'POST');
    expect(calls.last.path, '/api/stream/cameras/c/publish');
    expect(calls.last.data, {'sdp': 'offer'});
    await service.unpublish('c', 's');
    expect(calls.last.method, 'DELETE');
    expect(calls.last.path, '/api/stream/cameras/c/publish/s');
  });
}

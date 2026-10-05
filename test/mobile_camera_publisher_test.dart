import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vigishield_mobile_app/data/services/mobile_camera_publisher.dart';

class Capture implements MobileCameraCapture {
  final events = <String>[];
  Completer<void>? opening;
  Object? openError, offerError, answerError;
  Duration? offeredTimeout;
  @override MediaStream? get stream => null;
  @override Future<void> open({required bool front}) async {
    events.add('open:$front');
    if (opening != null) await opening!.future;
    if (openError != null) throw openError!;
  }
  @override Future<String> offer(Duration timeout) async {
    offeredTimeout = timeout;
    if (offerError != null) throw offerError!;
    return 'offer';
  }
  @override Future<void> answer(String sdp) async {
    events.add(sdp);
    if (answerError != null) throw answerError!;
  }
  @override Future<void> close() async { events.add('close'); }
}
class Transport implements MobilePublishTransport {
  final events = <String>[];
  Completer<MobilePublishAnswer>? pending;
  bool failDelete = false;
  @override Future<MobilePublishAnswer> publish(String id, String sdp) async {
    events.add('$id:$sdp');
    return pending == null ? const MobilePublishAnswer('session', 'answer') : await pending!.future;
  }
  @override Future<void> unpublish(String id, String sessionId) async {
    events.add('delete:$id:$sessionId');
    if (failDelete) throw StateError('offline');
  }
}
void main() {
  test('permission failure closes capture without publishing', () async {
    final capture = Capture()..openError = StateError('permission denied');
    final transport = Transport();
    final publisher = MobileCameraPublisher(transport: transport, capture: capture, observarCicloDeVida: false);
    await publisher.start('camera', front: false);
    expect(publisher.error, contains('permission denied'));
    expect(capture.events.last, 'close');
    expect(transport.events, isEmpty);
    publisher.dispose();
  });
  test('ICE timeout releases capture and never sends partial SDP', () async {
    final capture = Capture()..offerError = TimeoutException('ICE');
    final transport = Transport();
    final publisher = MobileCameraPublisher(transport: transport, capture: capture,
      iceTimeout: const Duration(milliseconds: 50), observarCicloDeVida: false);
    await publisher.start('camera', front: false);
    expect(capture.offeredTimeout, const Duration(milliseconds: 50));
    expect(publisher.error, contains('ICE'));
    expect(capture.events.last, 'close');
    expect(transport.events, isEmpty);
    publisher.dispose();
  });
  test('remote answer failure deletes the allocated session', () async {
    final capture = Capture()..answerError = StateError('bad SDP');
    final transport = Transport();
    final publisher = MobileCameraPublisher(transport: transport, capture: capture, observarCicloDeVida: false);
    await publisher.start('camera', front: false);
    expect(publisher.isPublishing, isFalse);
    expect(publisher.error, contains('bad SDP'));
    expect(transport.events.last, 'delete:camera:session');
    publisher.dispose();
  });
  test('dispose while permission pending closes late capture without signaling', () async {
    final capture = Capture()..opening = Completer<void>();
    final transport = Transport();
    final publisher = MobileCameraPublisher(transport: transport, capture: capture, observarCicloDeVida: false);
    final starting = publisher.start('camera', front: false);
    publisher.dispose();
    capture.opening!.complete();
    await starting;
    await publisher.stop();
    expect(capture.events.last, 'close');
    expect(transport.events, isEmpty);
    expect(publisher.isStarting, isFalse);
    await publisher.start('camera', front: true);
    expect(capture.events.where((e) => e.startsWith('open')), hasLength(1));
  });
  test('failed deletion blocks a new camera until old session is cleaned', () async {
    final transport = Transport();
    final publisher = MobileCameraPublisher(transport: transport, capture: Capture(), observarCicloDeVida: false);
    await publisher.start('old', front: false);
    transport.failDelete = true;
    await publisher.stop();
    await publisher.start('new', front: true);
    expect(publisher.isPublishing, isFalse);
    expect(transport.events, isNot(contains('new:offer')));
    transport.failDelete = false;
    await publisher.stop();
    expect(transport.events.last, 'delete:old:session');
    await publisher.start('new', front: true);
    expect(publisher.isPublishing, isTrue);
    await publisher.stop();
    publisher.dispose();
  });
  test('stop during signaling deletes late session without applying answer', () async {
    final capture = Capture();
    final transport = Transport()..pending = Completer<MobilePublishAnswer>();
    final publisher = MobileCameraPublisher(transport: transport, capture: capture, observarCicloDeVida: false);
    final starting = publisher.start('camera', front: true);
    await Future<void>.delayed(Duration.zero);
    final stopping = publisher.stop();
    expect(capture.events, contains('close'));
    transport.pending!.complete(const MobilePublishAnswer('late', 'answer'));
    await Future.wait([starting, stopping]);
    expect(capture.events, isNot(contains('answer')));
    expect(transport.events.where((e) => e == 'delete:camera:late'), hasLength(1));
    expect(publisher.isPublishing, isFalse);
    publisher.dispose();
  });
  test('explicit start publishes and stop releases capture and server session', () async {
    final capture = Capture(); final transport = Transport();
    final publisher = MobileCameraPublisher(transport: transport, capture: capture, observarCicloDeVida: false);
    expect(capture.events, isEmpty);
    await publisher.start('camera', front: false);
    expect(publisher.isPublishing, isTrue);
    expect(transport.events, ['camera:offer']);
    expect(capture.events, ['open:false', 'answer']);
    await publisher.stop();
    expect(publisher.isPublishing, isFalse);
    expect(capture.events.last, 'close');
    expect(transport.events.last, 'delete:camera:session');
    publisher.dispose();
  });
}

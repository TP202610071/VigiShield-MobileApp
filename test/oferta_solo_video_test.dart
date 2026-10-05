import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/data/services/mobile_camera_publisher.dart';

/// Une líneas con CRLF, que es como las entrega libwebrtc.
String _sdp(List<String> lineas) => '${lineas.join('\r\n')}\r\n';

/// Oferta correcta: una sola pista de video, sendonly.
String _buena() => _sdp([
      'v=0',
      'o=- 4611731400430051336 2 IN IP4 127.0.0.1',
      's=-',
      't=0 0',
      'a=group:BUNDLE 0',
      'm=video 36795 UDP/TLS/RTP/SAVPF 96 97',
      'c=IN IP4 0.0.0.0',
      'a=sendonly',
      'a=rtpmap:96 H264/90000',
    ]);

void main() {
  test('una sola pista de video se acepta', () {
    expect(problemaDeOferta(_buena()), isNull);
  });

  test('la oferta real que fallaba en Android se rechaza por el audio', () {
    // Forma exacta que registró el servidor: flutter_webrtc, sin constraints,
    // usa OfferToReceiveAudio/Video = true y añade dos pistas de recepción
    // encima de la nuestra. Una de ellas es audio.
    final conAudio = _sdp([
      'v=0',
      'o=- 1 2 IN IP4 127.0.0.1',
      's=-',
      't=0 0',
      'm=video 41870 UDP/TLS/RTP/SAVPF 100 103',
      'a=recvonly',
      'm=audio 57948 UDP/TLS/RTP/SAVPF 111 63 9 0 8 13 110 126',
      'a=recvonly',
      'm=video 36795 UDP/TLS/RTP/SAVPF 96 97 98 99',
      'a=sendonly',
    ]);

    final problema = problemaDeOferta(conAudio);

    expect(problema, isNotNull);
    // El audio se nombra explícitamente: es la garantía que se le da a quien
    // presta su casa para la validación, no un detalle técnico cualquiera.
    expect(problema, contains('audio'));
  });

  test('dos pistas de video tampoco valen', () {
    final dosVideos = _sdp([
      'v=0',
      'o=- 1 2 IN IP4 127.0.0.1',
      's=-',
      't=0 0',
      'm=video 41870 UDP/TLS/RTP/SAVPF 100',
      'm=video 36795 UDP/TLS/RTP/SAVPF 96',
    ]);

    expect(problemaDeOferta(dosVideos), contains('una sola pista'));
  });

  test('sin ninguna pista se rechaza', () {
    expect(problemaDeOferta(_sdp(['v=0', 'o=- 1 2 IN IP4 127.0.0.1', 's=-', 't=0 0'])),
        isNotNull);
  });

  test('una oferta que no empieza por v=0 se rechaza', () {
    expect(problemaDeOferta('m=video 9 UDP/TLS/RTP/SAVPF 96\r\n'), isNotNull);
  });

  test('acepta saltos de línea sin retorno de carro', () {
    // Algunas implementaciones usan solo \n; el servidor también lo admite.
    final conLf = 'v=0\no=- 1 2 IN IP4 127.0.0.1\ns=-\nt=0 0\n'
        'm=video 36795 UDP/TLS/RTP/SAVPF 96\na=sendonly\n';

    expect(problemaDeOferta(conLf), isNull);
  });
}

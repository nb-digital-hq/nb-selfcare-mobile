import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nb_selfcare/core/network/update_service.dart';

void main() {
  group('compararVersiones', () {
    test('compara por partes e ignora sufijos', () {
      expect(compararVersiones('1.2.0', '1.1.9'), greaterThan(0));
      expect(compararVersiones('1.2.0+5', '1.2.0'), 0);
      expect(compararVersiones('1.10.0', '1.9.3'), greaterThan(0));
      expect(compararVersiones('1.2', '1.2.1'), lessThan(0));
    });
  });

  group('elegirApk', () {
    const ApkPublicado arm64 = ApkPublicado(
      nombre: 'NB-SelfCare-1.2.0-arm64-v8a.apk',
      url: 'u1',
      bytes: 1,
    );
    const ApkPublicado v7 = ApkPublicado(
      nombre: 'NB-SelfCare-1.2.0-armeabi-v7a.apk',
      url: 'u2',
      bytes: 1,
    );
    const ApkPublicado universal = ApkPublicado(
      nombre: 'NB-SelfCare-1.2.0-universal.apk',
      url: 'u3',
      bytes: 1,
    );

    test('prefiere el APK de la ABI del teléfono', () {
      expect(
        elegirApk(<ApkPublicado>[universal, v7, arm64], <String>['arm64-v8a', 'armeabi-v7a']),
        arm64,
      );
    });

    test('con APK por ABI pero ninguno compatible, no instala el universal', () {
      expect(elegirApk(<ApkPublicado>[universal, arm64], <String>['x86_64']), isNull);
    });

    test('sin APK por ABI, usa el universal', () {
      expect(elegirApk(<ApkPublicado>[universal], <String>['x86_64']), universal);
    });
  });

  test('lee la publicación de GitHub y tolera campos raros', () {
    final Publicacion p = Publicacion.fromJson(<String, Object?>{
      'tag_name': 'v1.2.0',
      'body': ' Novedades ',
      'html_url': 'https://github.com/x',
      'assets': <Object?>[
        <String, Object?>{
          'name': 'NB-SelfCare-1.2.0-arm64-v8a.apk',
          'browser_download_url': 'https://d/1',
          'size': 10,
          'digest': 'sha256:ABC',
        },
        <String, Object?>{'name': 'notas.txt'},
        42,
      ],
    });
    expect(p.version, '1.2.0');
    expect(p.notas, 'Novedades');
    expect(p.apks.single.sha256, 'abc');
    expect(Publicacion.fromJson(<String, Object?>{}).apks, isEmpty);
  });

  group('UpdateService', () {
    test('404 = todavía no hay versiones publicadas', () async {
      final UpdateService s = UpdateService(
        client: MockClient((http.Request r) async => http.Response('{}', 404)),
      );
      await expectLater(
        s.ultimaPublicacion(),
        throwsA(
          isA<UpdateError>().having(
            (UpdateError e) => e.motivo,
            'motivo',
            UpdateFailure.sinPublicaciones,
          ),
        ),
      );
    });

    test('descarga y verifica la huella; un archivo alterado se descarta', () async {
      final List<int> bytes = utf8.encode('apk-de-prueba');
      final String digest = sha256.convert(bytes).toString();
      final UpdateService s = UpdateService(
        client: MockClient((http.Request r) async => http.Response.bytes(bytes, 200)),
      );
      final Directory dir = await Directory.systemTemp.createTemp('nb_update');
      addTearDown(() => dir.delete(recursive: true));

      final File ok = await s.descargar(
        ApkPublicado(nombre: 'a.apk', url: 'https://d/a', bytes: bytes.length, sha256: digest),
        File('${dir.path}/ok.apk'),
      );
      expect(await ok.readAsBytes(), bytes);

      await expectLater(
        s.descargar(
          ApkPublicado(nombre: 'a.apk', url: 'https://d/a', bytes: bytes.length, sha256: 'ff'),
          File('${dir.path}/mal.apk'),
        ),
        throwsA(
          isA<UpdateError>().having(
            (UpdateError e) => e.motivo,
            'motivo',
            UpdateFailure.huellaDistinta,
          ),
        ),
      );
      expect(File('${dir.path}/mal.apk').existsSync(), isFalse);
    });
  });
}

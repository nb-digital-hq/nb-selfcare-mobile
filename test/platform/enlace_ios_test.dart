import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android declara el permiso que exige el descubrimiento NSD', () {
    final manifiesto = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifiesto, contains('android.permission.CHANGE_WIFI_MULTICAST_STATE'));
    expect(manifiesto, contains('android:allowBackup="false"'));
  });
  test('el acceso al llavero está configurado en Debug, Release y Profile', () {
    final proyecto = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(
      RegExp(r'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;').allMatches(proyecto),
      hasLength(3),
    );
    final entitlements = File('ios/Runner/Runner.entitlements').readAsStringSync();
    expect(entitlements, matches(RegExp(r'<key>keychain-access-groups</key>\s*<array\s*/>')));
  });
  test('los permisos nativos tienen recursos de localización completos en los tres idiomas', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final claves = RegExp(r'<key>(NS\w+UsageDescription)</key>')
        .allMatches(plist)
        .map((m) => m.group(1)!)
        .toSet();
    expect(claves, contains('NSLocalNetworkUsageDescription'));
    for (final idioma in ['es', 'en', 'pt']) {
      final lineas = File('ios/Runner/$idioma.lproj/InfoPlist.strings').readAsLinesSync();
      final encontradas = <String>{};
      for (final linea in lineas.where((l) => l.isNotEmpty)) {
        final campo = RegExp(r'^"([^"]+)" = (".*");$').firstMatch(linea);
        expect(campo, isNotNull);
        encontradas.add(campo!.group(1)!);
        expect(jsonDecode(campo.group(2)!) as String, isNotEmpty);
      }
      expect(encontradas, claves);
      expect(proyectoContieneLocalizacion(idioma), isTrue);
    }
  });
}

bool proyectoContieneLocalizacion(String idioma) =>
    File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync()
        .contains('$idioma.lproj/InfoPlist.strings');

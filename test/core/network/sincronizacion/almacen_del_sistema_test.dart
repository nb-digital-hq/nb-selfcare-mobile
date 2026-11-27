import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/network/sincronizacion/almacen_del_sistema.dart';
import 'package:nb_selfcare/core/network/sincronizacion/cliente.dart';
import 'package:nb_selfcare/core/network/sincronizacion/credenciales.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final mensajero = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    mensajero.setMockMethodCallHandler(canal, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'el adaptador impide el borrado automático tanto al leer como al escribir en Android',
    () async {
      final operaciones = <String>[];
      mensajero.setMockMethodCallHandler(canal, (llamada) async {
        operaciones.add(llamada.method);
        final argumentos = llamada.arguments as Map<Object?, Object?>;
        final opciones = argumentos['options']! as Map<Object?, Object?>;
        expect(opciones['resetOnError'], 'false');
        expect(argumentos['key'], 'selfcare.enlace.v1');
        return null;
      });
      const almacen = AlmacenDeEnlaceDelSistema();
      await almacen.leer();
      await almacen.escribir('registro sintético');
      expect(operaciones, ['read', 'write']);
    },
  );

  test('un error nativo conserva la identidad sin solicitar escritura ni borrado', () async {
    final operaciones = <String>[];
    mensajero.setMockMethodCallHandler(canal, (llamada) async {
      operaciones.add(llamada.method);
      throw PlatformException(code: 'error_sintetico', message: 'detalle que no se debe propagar');
    });
    final gestor = CredencialesDelEnlace(const AlmacenDeEnlaceDelSistema());
    await expectLater(
      gestor.cargar(),
      throwsA(
        isA<FalloDeEnlace>().having((e) => e.toString(), 'error', 'FalloDeEnlace(STORAGE_FAILURE)'),
      ),
    );
    expect(operaciones, ['read']);
  });
}

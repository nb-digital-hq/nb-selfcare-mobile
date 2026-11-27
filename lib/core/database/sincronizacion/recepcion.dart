import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;

import '../../sync/contrato.dart';
import '../../sync/huella.dart';
import '../app_database.dart';

enum EstadoRecepcion { aplicado, conflicto, epocaCambiada, operacionAlterada, revisionAgotada }

class ReciboDeRecepcion {
  const ReciboDeRecepcion(this.estado, [this.revision]);
  final EstadoRecepcion estado;
  final int? revision;
  @override
  String toString() => 'ReciboDeRecepcion([REDACTADO])';
}

class FalloDeRecepcion implements Exception {
  const FalloDeRecepcion();
  @override
  String toString() => 'SYNC_STORAGE_FAILURE';
}

/// El adaptador valida campos y referencias y devuelve solo la instantánea compartida.
/// Recibe el ejecutor exclusivo en su transacción; no abre otra ni vuelve a dar recompensas.
abstract interface class PropietarioDeRegistro {
  Future<Map<String, Object?>?> comprobar(AppDatabase db, CambioSincronizado cambio);
  Future<void> aplicar(AppDatabase db, CambioSincronizado cambio);
}

/// Componente aislado: requiere tablas instaladas por el propietario y no las crea.
/// El llamador autentica al nodo y verifica consentimiento antes de usarlo.
class BuzonDeRecepcion {
  BuzonDeRecepcion(this._db);
  final AppDatabase _db;

  Future<ReciboDeRecepcion> recibir({
    required String epoca,
    required String nodo,
    required CambioSincronizado cambio,
    required PropietarioDeRegistro propietario,
  }) async {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(epoca)) throw const FormatoDeSincronizacion();
    final hexadecimal = huellaDelCambio(nodo, cambio);
    final huella = Uint8List.fromList(<int>[
      for (var i = 0; i < hexadecimal.length; i += 2)
        int.parse(hexadecimal.substring(i, i + 2), radix: 16),
    ]);
    try {
      final resultado = await _db.exclusively(() async {
        await _db.customStatement('BEGIN IMMEDIATE');
        try {
          final claves = await _db.customSelect('PRAGMA foreign_keys').getSingle();
          if (claves.read<int>('foreign_keys') != 1) throw const FalloDeRecepcion();
          final respuesta = await _procesar(epoca, nodo, cambio, propietario, huella);
          await _db.customStatement('COMMIT');
          return respuesta;
        } catch (_) {
          await _db.customStatement('ROLLBACK');
          rethrow;
        }
      });
      if (resultado.$2) _db.markTablesUpdated(_db.allTables);
      return resultado.$1;
    } on FormatoDeSincronizacion {
      rethrow;
    } on FalloDeRecepcion {
      rethrow;
    } catch (_) {
      throw const FalloDeRecepcion();
    }
  }

  Future<(ReciboDeRecepcion, bool)> _procesar(
    String epoca,
    String nodo,
    CambioSincronizado cambio,
    PropietarioDeRegistro propietario,
    Uint8List huella,
  ) async {
    final contexto = await _db
        .customSelect('SELECT epoca FROM sc_sync_contexto WHERE id=1')
        .getSingle();
    final actual = contexto.read<String>('epoca');
    _identidadPersistida(actual);
    if (actual != epoca) return (const ReciboDeRecepcion(EstadoRecepcion.epocaCambiada), false);
    final previos = await _db
        .customSelect(
          'SELECT epoca,huella,resultado,revision FROM sc_sync_recibos WHERE nodo=? AND operacion=?',
          variables: [Variable<String>(nodo), Variable<String>(cambio.id)],
        )
        .get();
    if (previos.isNotEmpty) {
      final previo = previos.single;
      final epocaPrevia = previo.read<String>('epoca');
      _identidadPersistida(epocaPrevia);
      final huellaPrevia = previo.read<Uint8List>('huella');
      final revision = previo.read<int>('revision');
      _revisionPersistida(revision);
      if (huellaPrevia.length != 32) throw const FalloDeRecepcion();
      if (epocaPrevia != actual) {
        return (const ReciboDeRecepcion(EstadoRecepcion.epocaCambiada), false);
      }
      if (!_iguales(huella, huellaPrevia)) {
        return (const ReciboDeRecepcion(EstadoRecepcion.operacionAlterada), false);
      }
      final estado = previo.read<String>('resultado');
      if (estado == 'aplicado' && revision > 0) {
        return (ReciboDeRecepcion(EstadoRecepcion.aplicado, revision), false);
      }
      if (estado == 'conflicto') {
        final conflictos = await _db
            .customSelect(
              'SELECT 1 FROM sc_sync_conflictos WHERE nodo=? AND operacion=?',
              variables: [Variable<String>(nodo), Variable<String>(cambio.id)],
            )
            .get();
        if (conflictos.isEmpty) throw const FalloDeRecepcion();
        return (ReciboDeRecepcion(EstadoRecepcion.conflicto, revision), false);
      }
      throw const FalloDeRecepcion();
    }
    final filas = await _db
        .customSelect(
          'SELECT revision FROM sc_sync_revisiones WHERE entidad=? AND registro=?',
          variables: [Variable<String>(cambio.entidad.codigo), Variable<String>(cambio.registro)],
        )
        .get();
    final revision = filas.isEmpty ? 0 : filas.single.read<int>('revision');
    _revisionPersistida(revision);
    final actualDelPropietario = await propietario.comprobar(_db, cambio);
    final Map<String, Object?>? instantanea;
    if (actualDelPropietario != null) {
      try {
        instantanea = CambioSincronizado.desdeJson({
          ...cambio.aJson(),
          'operacion': 'guardar',
          'datos': actualDelPropietario,
        }).datos;
      } on FormatoDeSincronizacion {
        throw const FalloDeRecepcion();
      }
    } else {
      instantanea = null;
    }
    if (cambio.base != revision) {
      await _guardarRecibo(nodo, cambio, epoca, huella, 'conflicto', revision);
      await _db.customStatement(
        'INSERT INTO sc_sync_conflictos(nodo,operacion,actual,propuesta) VALUES(?,?,?,?)',
        [
          nodo,
          cambio.id,
          instantanea == null ? null : jsonEncode(instantanea),
          jsonEncode(cambio.aJson()),
        ],
      );
      return (ReciboDeRecepcion(EstadoRecepcion.conflicto, revision), false);
    }
    if (revision == maxRevisionCompartida) {
      return (const ReciboDeRecepcion(EstadoRecepcion.revisionAgotada), false);
    }
    final nueva = revision + 1;
    await propietario.aplicar(_db, cambio);
    await _db.customStatement(
      'INSERT INTO sc_sync_revisiones(entidad,registro,revision) VALUES(?,?,?) '
      'ON CONFLICT(entidad,registro) DO UPDATE SET revision=excluded.revision',
      [cambio.entidad.codigo, cambio.registro, nueva],
    );
    await _guardarRecibo(nodo, cambio, epoca, huella, 'aplicado', nueva);
    return (ReciboDeRecepcion(EstadoRecepcion.aplicado, nueva), true);
  }

  Future<void> _guardarRecibo(
    String nodo,
    CambioSincronizado cambio,
    String epoca,
    Uint8List huella,
    String resultado,
    int revision,
  ) => _db.customStatement(
    'INSERT INTO sc_sync_recibos(nodo,operacion,epoca,huella,resultado,revision) VALUES(?,?,?,?,?,?)',
    [nodo, cambio.id, epoca, huella, resultado, revision],
  );
}

void _identidadPersistida(String valor) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(valor)) throw const FalloDeRecepcion();
}

void _revisionPersistida(int revision) {
  if (revision < 0 || revision > maxRevisionCompartida) throw const FalloDeRecepcion();
}

bool _iguales(Uint8List a, Uint8List b) {
  var diferencia = 0;
  for (var i = 0; i < a.length; i++) {
    diferencia |= a[i] ^ b[i];
  }
  return diferencia == 0;
}

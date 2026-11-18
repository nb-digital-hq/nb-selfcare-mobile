import 'dart:convert';
import 'dart:io';

import 'comun.dart';

// Los textos de la interfaz viven en lib/core/l10n/arb/: español es la
// plantilla y inglés y portugués deben tener exactamente las mismas claves,
// con los mismos marcadores. Una clave que el código ya no usa también es un
// fallo: los catálogos solo contienen lo que la app muestra.
const String _dir = 'lib/core/l10n/arb';

Map<String, String> _leer(String idioma) {
  final Object? json = jsonDecode(File('$_dir/app_$idioma.arb').readAsStringSync());
  final Map<String, String> m = <String, String>{};
  if (json is Map<String, Object?>) {
    for (final MapEntry<String, Object?> e in json.entries) {
      if (!e.key.startsWith('@') && e.value is String) {
        m[e.key] = e.value! as String;
      }
    }
  }
  return m;
}

/// Marcadores de primer nivel de un mensaje ICU: `{nombre}` y `{n, plural, …}`.
Set<String> _marcadores(String texto) {
  final Set<String> s = <String>{};
  int nivel = 0;
  for (int i = 0; i < texto.length; i++) {
    final String c = texto[i];
    if (c == '{') {
      if (nivel == 0) {
        final RegExpMatch? m = RegExp(r'^\{(\w+)\s*[,}]').firstMatch(texto.substring(i));
        if (m != null) {
          s.add(m.group(1)!);
        }
      }
      nivel++;
    } else if (c == '}') {
      nivel--;
    }
  }
  return s;
}

void main() {
  final Informe inf = Informe('i18n');
  final Map<String, String> es = _leer('es');
  for (final String idioma in <String>['en', 'pt']) {
    final Map<String, String> otro = _leer(idioma);
    for (final String k in es.keys) {
      final String? t = otro[k];
      if (t == null) {
        inf.fallo('app_$idioma.arb', 'falta "$k"');
        continue;
      }
      final Set<String> a = _marcadores(es[k]!);
      final Set<String> b = _marcadores(t);
      if (a.length != b.length || !a.containsAll(b)) {
        inf.fallo('app_$idioma.arb', '"$k" con marcadores distintos: $a ≠ $b');
      }
      if (emoji.hasMatch(t)) {
        inf.fallo('app_$idioma.arb', '"$k" contiene emoji');
      }
    }
    for (final String k in otro.keys) {
      if (!es.containsKey(k)) {
        inf.fallo('app_$idioma.arb', 'sobra "$k"');
      }
    }
  }
  final StringBuffer codigo = StringBuffer();
  for (final File f in archivos(<String>['lib/'], <String>['.dart'])) {
    if (!f.path.startsWith('lib/core/l10n/generated/')) {
      codigo.writeln(f.readAsStringSync());
    }
  }
  final Set<String> usados = RegExp(r'\b[a-z]\w*\b')
      .allMatches(codigo.toString())
      .map((RegExpMatch m) => m.group(0)!)
      .toSet();
  for (final String k in es.keys) {
    if (emoji.hasMatch(es[k]!)) {
      inf.fallo('app_es.arb', '"$k" contiene emoji');
    }
    if (!usados.contains(k)) {
      inf.fallo('app_es.arb', '"$k" no se usa en lib/');
    }
  }
  exit(inf.cerrar());
}

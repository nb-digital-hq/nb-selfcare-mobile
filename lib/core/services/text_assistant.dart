import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/metabolic_phase.dart';
import '../l10n/l10n.dart';

/// Alimento y gramos extraídos de una frase en lenguaje natural.
class ParsedMealItem {
  const ParsedMealItem({
    required this.searchTerm,
    required this.grams,
    required this.fallbackKcal,
    required this.fallbackP,
    required this.fallbackC,
    required this.fallbackF,
  });

  final String searchTerm;
  final double grams;
  final double fallbackKcal;
  final double fallbackP;
  final double fallbackC;
  final double fallbackF;
}

/// Resultado de extracción sintáctica de comida.
class ParsedMealResult {
  const ParsedMealResult({required this.items});

  final List<ParsedMealItem> items;
}

/// Ánimo, energía, estrés y etiquetas sugeridos para una entrada del diario.
class JournalTextAnalysis {
  const JournalTextAnalysis({
    required this.moodScore,
    required this.energyLevel,
    required this.stressLevel,
    required this.tags,
    required this.oneLineInsight,
  });

  final int moodScore;
  final int energyLevel;
  final int stressLevel;

  /// Códigos estables (`calma_interior`…); la interfaz los traduce.
  final List<String> tags;
  final String oneLineInsight;
}

/// Pieza contable que se convierte a gramos ("2 huevos").
class _Pieza {
  const _Pieza(this.raices, this.gramos, this.nombre);

  final List<String> raices;
  final double gramos;

  /// Nombre con el que se busca en el catálogo de ese idioma.
  final String nombre;
}

/// Macros por 100 g de respaldo si el alimento no está en el catálogo.
class _Categoria {
  const _Categoria(this.raices, this.kcal, this.p, this.c, this.f);

  final List<String> raices;
  final double kcal;
  final double p;
  final double c;
  final double f;
}

/// Vocabulario de un idioma para leer comidas y entradas del diario.
class _Lexico {
  const _Lexico({
    required this.conectores,
    required this.con,
    required this.modificadores,
    required this.unidades,
    required this.de,
    required this.articulos,
    required this.piezas,
    required this.categorias,
    required this.positivas,
    required this.negativas,
    required this.energiaAlta,
    required this.energiaBaja,
    required this.estres,
    required this.calma,
  });

  final List<String> conectores;
  final String con;
  final List<String> modificadores;
  final List<String> unidades;
  final List<String> de;
  final List<String> articulos;
  final List<_Pieza> piezas;
  final List<_Categoria> categorias;
  final List<String> positivas;
  final List<String> negativas;
  final List<String> energiaAlta;
  final List<String> energiaBaja;
  final List<String> estres;
  final List<String> calma;
}

const List<_Categoria> _categoriasEs = <_Categoria>[
  _Categoria(<String>['pollo', 'pavo'], 165, 31, 0, 3.6),
  _Categoria(<String>['carne', 'res', 'lomo'], 210, 26, 0, 11),
  _Categoria(<String>['huevo'], 155, 13, 1.1, 11),
  _Categoria(<String>['arroz'], 130, 2.7, 28, 0.3),
  _Categoria(<String>['avena'], 375, 13.5, 68, 7),
  _Categoria(<String>['atun', 'atún', 'salmon', 'salmón', 'pescado'], 180, 24, 0, 9),
  _Categoria(<String>['aguacate'], 160, 2, 8.5, 14.7),
  _Categoria(<String>['yogur', 'leche'], 65, 4.5, 5, 3.2),
];

const Map<String, _Lexico> _lexicos = <String, _Lexico>{
  'es': _Lexico(
    conectores: <String>['y', 'e'],
    con: 'con',
    modificadores: <String>[
      'piel',
      'cáscara',
      'cascara',
      'hueso',
      'sal',
      'azúcar',
      'azucar',
      'agua',
    ],
    unidades: <String>['g', 'gr', 'gramos', 'ml', 'mililitros'],
    de: <String>['de'],
    articulos: <String>['un', 'una', 'unos', 'unas', 'el', 'la', 'los', 'las'],
    piezas: <_Pieza>[
      _Pieza(<String>['huevo'], 55, 'huevo cocido'),
      _Pieza(<String>['platano', 'plátano', 'banano'], 120, 'platano banano'),
      _Pieza(<String>['manzana'], 150, 'manzana fresca'),
      _Pieza(<String>['naranja'], 130, 'naranja'),
      _Pieza(<String>['rebanada', 'pan'], 35, 'pan integral'),
      _Pieza(<String>['arepa'], 100, 'arepa'),
    ],
    categorias: _categoriasEs,
    positivas: <String>[
      'feliz',
      'contento',
      'tranquilo',
      'paz',
      'motivado',
      'alegría',
      'logro',
      'orgullo',
      'bien',
      'excelente',
    ],
    negativas: <String>[
      'triste',
      'desanimado',
      'mal',
      'enojado',
      'frustrado',
      'tristeza',
      'difícil',
      'duda',
    ],
    energiaAlta: <String>[
      'energía',
      'fuerza',
      'vitalidad',
      'activo',
      'ágil',
      'imparable',
      'entrené',
    ],
    energiaBaja: <String>[
      'cansado',
      'agotado',
      'fatiga',
      'pesado',
      'sueño',
      'exhausto',
      'sin fuerza',
    ],
    estres: <String>[
      'estrés',
      'estresado',
      'agobio',
      'presión',
      'tensión',
      'urgente',
      'ansiedad',
      'sobrecarga',
    ],
    calma: <String>['relajado', 'descanso', 'tranquilidad'],
  ),
  'en': _Lexico(
    conectores: <String>['and'],
    con: 'with',
    modificadores: <String>['skin', 'peel', 'bone', 'salt', 'sugar', 'water'],
    unidades: <String>['g', 'gr', 'grams', 'gram', 'ml', 'milliliters'],
    de: <String>['of'],
    articulos: <String>['a', 'an', 'the', 'some'],
    piezas: <_Pieza>[
      _Pieza(<String>['egg'], 55, 'boiled egg'),
      _Pieza(<String>['banana'], 120, 'banana'),
      _Pieza(<String>['apple'], 150, 'apple'),
      _Pieza(<String>['orange'], 130, 'orange'),
      _Pieza(<String>['slice', 'bread', 'toast'], 35, 'whole wheat bread'),
    ],
    categorias: <_Categoria>[
      _Categoria(<String>['chicken', 'turkey'], 165, 31, 0, 3.6),
      _Categoria(<String>['beef', 'steak', 'meat', 'pork'], 210, 26, 0, 11),
      _Categoria(<String>['egg'], 155, 13, 1.1, 11),
      _Categoria(<String>['rice'], 130, 2.7, 28, 0.3),
      _Categoria(<String>['oat'], 375, 13.5, 68, 7),
      _Categoria(<String>['tuna', 'salmon', 'fish'], 180, 24, 0, 9),
      _Categoria(<String>['avocado'], 160, 2, 8.5, 14.7),
      _Categoria(<String>['yogurt', 'yoghurt', 'milk'], 65, 4.5, 5, 3.2),
    ],
    positivas: <String>[
      'happy',
      'glad',
      'calm',
      'peace',
      'motivated',
      'joy',
      'proud',
      'good',
      'great',
      'excellent',
    ],
    negativas: <String>[
      'sad',
      'down',
      'bad',
      'angry',
      'frustrated',
      'sadness',
      'hard',
      'difficult',
      'doubt',
    ],
    energiaAlta: <String>[
      'energy',
      'strong',
      'vitality',
      'active',
      'unstoppable',
      'trained',
      'workout',
    ],
    energiaBaja: <String>['tired', 'exhausted', 'fatigue', 'heavy', 'sleepy', 'drained'],
    estres: <String>[
      'stress',
      'stressed',
      'overwhelmed',
      'pressure',
      'tension',
      'urgent',
      'anxiety',
      'overload',
    ],
    calma: <String>['relaxed', 'rest', 'rested', 'tranquil'],
  ),
  'pt': _Lexico(
    conectores: <String>['e'],
    con: 'com',
    modificadores: <String>['pele', 'casca', 'osso', 'sal', 'açúcar', 'acucar', 'água', 'agua'],
    unidades: <String>['g', 'gr', 'gramas', 'ml', 'mililitros'],
    de: <String>['de', 'do', 'da'],
    articulos: <String>['um', 'uma', 'uns', 'umas', 'o', 'a', 'os', 'as'],
    piezas: <_Pieza>[
      _Pieza(<String>['ovo'], 55, 'ovo cozido'),
      _Pieza(<String>['banana'], 120, 'banana'),
      _Pieza(<String>['maçã', 'maca'], 150, 'maçã'),
      _Pieza(<String>['laranja'], 130, 'laranja'),
      _Pieza(<String>['fatia', 'pão', 'pao'], 35, 'pão integral'),
    ],
    categorias: <_Categoria>[
      _Categoria(<String>['frango', 'peru'], 165, 31, 0, 3.6),
      _Categoria(<String>['carne', 'bife', 'lombo'], 210, 26, 0, 11),
      _Categoria(<String>['ovo'], 155, 13, 1.1, 11),
      _Categoria(<String>['arroz'], 130, 2.7, 28, 0.3),
      _Categoria(<String>['aveia'], 375, 13.5, 68, 7),
      _Categoria(<String>['atum', 'salmão', 'salmao', 'peixe'], 180, 24, 0, 9),
      _Categoria(<String>['abacate'], 160, 2, 8.5, 14.7),
      _Categoria(<String>['iogurte', 'leite'], 65, 4.5, 5, 3.2),
    ],
    positivas: <String>[
      'feliz',
      'contente',
      'tranquilo',
      'paz',
      'motivado',
      'alegria',
      'conquista',
      'orgulho',
      'bem',
      'ótimo',
      'excelente',
    ],
    negativas: <String>[
      'triste',
      'desanimado',
      'mal',
      'irritado',
      'frustrado',
      'tristeza',
      'difícil',
      'dúvida',
    ],
    energiaAlta: <String>[
      'energia',
      'força',
      'vitalidade',
      'ativo',
      'ágil',
      'imparável',
      'treinei',
    ],
    energiaBaja: <String>[
      'cansado',
      'esgotado',
      'fadiga',
      'pesado',
      'sono',
      'exausto',
      'sem força',
    ],
    estres: <String>[
      'estresse',
      'stress',
      'estressado',
      'sobrecarregado',
      'pressão',
      'tensão',
      'urgente',
      'ansiedade',
    ],
    calma: <String>['relaxado', 'descanso', 'tranquilidade'],
  ),
};

/// Asistente de texto 100 % local y determinista (ADR-03).
///
/// * Extrae alimentos y gramos de una frase ("200 g de pollo y una manzana").
/// * Sugiere ánimo, energía, estrés y etiquetas para una entrada del diario.
/// * Redacta el saludo contextual de Nibi.
///
/// Entiende español, inglés y portugués; no usa ningún modelo de lenguaje.
class TextAssistant {
  const TextAssistant();

  static _Lexico _lexico(String idioma) => _lexicos[idioma] ?? _lexicos['es']!;

  /// Extrae los componentes de una comida a partir de texto libre en [idioma].
  Future<ParsedMealResult> parseMealText(String rawText, {String idioma = 'es'}) async {
    final String trimmed = rawText.trim();
    if (trimmed.isEmpty) return const ParsedMealResult(items: <ParsedMealItem>[]);
    return ParsedMealResult(items: _parseMeal(trimmed, _lexico(idioma)));
  }

  /// Sugiere ánimo, energía, estrés y etiquetas para una entrada del diario.
  Future<JournalTextAnalysis> analyzeJournal(String text, AppLocalizations l10n) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return JournalTextAnalysis(
        moodScore: 3,
        energyLevel: 3,
        stressLevel: 2,
        tags: const <String>['calma'],
        oneLineInsight: l10n.journalInsightEmpty,
      );
    }
    return _analyzeJournal(trimmed, _lexico(l10n.localeName), l10n);
  }

  static String _alternativa(List<String> palabras) => palabras.map(RegExp.escape).join('|');

  List<ParsedMealItem> _parseMeal(String text, _Lexico lx) {
    final List<ParsedMealItem> items = <ParsedMealItem>[];

    // Separa por conectores y por "con", salvo cuando "con" introduce un
    // modificador culinario ("con piel", "con sal") que forma parte del alimento.
    final List<String> segments = text
        .replaceAll(
          RegExp('\\s+(?:${_alternativa(lx.conectores)})\\s+', caseSensitive: false),
          ', ',
        )
        .replaceAll(
          RegExp(
            '\\s+${lx.con}\\s+(?!(?:${_alternativa(lx.modificadores)})\\b)',
            caseSensitive: false,
          ),
          ', ',
        )
        .replaceAll('\n', ', ')
        .split(',');

    final RegExp regexGrams = RegExp(
      '(\\d+(?:[\\.,]\\d+)?)\\s*(?:${_alternativa(lx.unidades)})\\s+(?:(?:${_alternativa(lx.de)})\\s+)?(.+)',
      caseSensitive: false,
    );
    final RegExp regexQuantity = RegExp(
      '(\\d+)\\s*(?:x\\s*)?([^\\d\\s]\\S*)(?:\\s+(.*))?',
      caseSensitive: false,
    );
    final RegExp articulo = RegExp('^(?:${_alternativa(lx.articulos)})\\s+', caseSensitive: false);

    for (final String rawSegment in segments) {
      final String seg = rawSegment.trim();
      if (seg.isEmpty) continue;

      double grams = 100.0;
      String name = seg;

      final RegExpMatch? matchGrams = regexGrams.firstMatch(seg);
      final RegExpMatch? matchQty = matchGrams == null ? regexQuantity.firstMatch(seg) : null;

      if (matchGrams != null) {
        grams = double.tryParse(matchGrams.group(1)!.replaceAll(',', '.')) ?? 100.0;
        name = matchGrams.group(2)!.trim();
      } else if (matchQty != null) {
        final int count = int.tryParse(matchQty.group(1)!) ?? 1;
        final String noun = matchQty.group(2)!.toLowerCase();
        _Pieza? pieza;
        for (final _Pieza p in lx.piezas) {
          if (p.raices.any(noun.startsWith)) {
            pieza = p;
            break;
          }
        }
        if (pieza != null) {
          grams = count * pieza.gramos;
          name = pieza.nombre;
        } else {
          grams = count * 100.0;
          name = <String>[noun, if (matchQty.group(3) != null) matchQty.group(3)!].join(' ');
        }
      }

      // "0 g de arroz" no es una comida; cantidades enormes son errores de dictado.
      if (!grams.isFinite || grams <= 0) continue;
      grams = grams.clamp(1.0, 5000.0);

      name = name
          .replaceAll(articulo, '')
          .replaceAll(RegExp(r'[^\w\sáéíóúüñãõâêôçàÁÉÍÓÚÜÑÃÕÂÊÔÇÀ]'), '')
          .trim();
      if (name.isEmpty) continue;

      final String lower = name.toLowerCase();
      _Categoria? categoria;
      for (final _Categoria c in lx.categorias) {
        if (c.raices.any(lower.contains)) {
          categoria = c;
          break;
        }
      }
      items.add(
        ParsedMealItem(
          searchTerm: name,
          grams: grams,
          fallbackKcal: categoria?.kcal ?? 130.0,
          fallbackP: categoria?.p ?? 4.0,
          fallbackC: categoria?.c ?? 20.0,
          fallbackF: categoria?.f ?? 3.0,
        ),
      );
    }
    return items;
  }

  JournalTextAnalysis _analyzeJournal(String text, _Lexico lx, AppLocalizations l10n) {
    final String lower = text.toLowerCase();
    bool contiene(String palabra) =>
        RegExp('(^|[^\\p{L}])${RegExp.escape(palabra)}', unicode: true).hasMatch(lower);

    int mood = 3;
    int energy = 3;
    int stress = 2;
    final List<String> tags = <String>[];

    final int posCount = lx.positivas.where(contiene).length;
    final int negCount = lx.negativas.where(contiene).length;
    if (posCount > negCount) {
      mood = (3 + posCount).clamp(1, 5);
      tags.add('calma_interior');
    } else if (negCount > posCount) {
      mood = (3 - negCount).clamp(1, 5);
      tags.add('gestion_emocional');
    }

    if (lx.energiaAlta.any(contiene)) {
      energy = 5;
      tags.add('alta_energia');
    } else if (lx.energiaBaja.any(contiene)) {
      energy = 2;
      tags.add('recuperacion_fisica');
    }

    if (lx.estres.any(contiene)) {
      stress = 4;
      tags.add('sobrecarga_mental');
    } else if (lx.calma.any(contiene)) {
      stress = 1;
      tags.add('descanso_reparador');
    }

    if (tags.isEmpty) tags.add('reflexion_personal');

    final String insight;
    if (mood >= 4 && energy >= 4) {
      insight = l10n.journalInsightGreat;
    } else if (stress >= 4) {
      insight = l10n.journalInsightStress;
    } else if (energy <= 2) {
      insight = l10n.journalInsightTired;
    } else {
      insight = l10n.journalInsightDefault;
    }

    return JournalTextAnalysis(
      moodScore: mood,
      energyLevel: energy,
      stressLevel: stress,
      tags: tags.take(3).toList(),
      oneLineInsight: insight,
    );
  }

  /// Saludo de Nibi en Inicio, elegido por el estado del día y por la hora.
  ///
  /// [variationSeed] cambia en cada visita a Inicio para que el mensaje varíe
  /// sin dejar de corresponder al estado de la persona.
  static String buildNibiGreeting({
    required AppLocalizations l10n,
    double? sleepHours,
    double? fastingHours,
    int? waterMl,
    int? waterGoalMl,
    double? weightTrendDelta7d,
    int? streak,
    required int hourOfDay,
    int variationSeed = 0,
  }) {
    final int safeSeed = variationSeed.abs();
    final int h = hourOfDay;
    String pick(List<String> pool) => pool[safeSeed % pool.length];

    final MetabolicPhase? phase = fastingHours == null
        ? null
        : MetabolicPhase.forHours(fastingHours);
    if (phase == MetabolicPhase.autophagy) {
      return pick(<String>[l10n.nibiGreetAutophagy0, l10n.nibiGreetAutophagy1]);
    }
    if (phase == MetabolicPhase.ketosis) {
      return pick(<String>[l10n.nibiGreetKetosis0, l10n.nibiGreetKetosis1]);
    }
    if (phase == MetabolicPhase.fatBurning) {
      return pick(<String>[
        l10n.nibiGreetFatBurning0,
        l10n.nibiGreetFatBurning1,
        l10n.nibiGreetFatBurning2,
      ]);
    }
    if (waterMl != null && waterGoalMl != null && waterMl >= waterGoalMl) {
      return pick(<String>[
        l10n.nibiGreetWater0,
        l10n.nibiGreetWater1,
        l10n.nibiGreetWater2,
        l10n.nibiGreetWater3,
      ]);
    }
    if (sleepHours != null && sleepHours >= 7.5) {
      return pick(<String>[
        l10n.nibiGreetSleep0,
        l10n.nibiGreetSleep1,
        l10n.nibiGreetSleep2,
        l10n.nibiGreetSleep3,
      ]);
    }
    if (streak != null && streak >= 5) {
      return pick(<String>[
        l10n.nibiGreetStreak0(streak),
        l10n.nibiGreetStreak1(streak),
        l10n.nibiGreetStreak2(streak),
        l10n.nibiGreetStreak3(streak),
      ]);
    }
    if (weightTrendDelta7d != null && weightTrendDelta7d < -0.2) {
      return pick(<String>[l10n.nibiGreetTrend0, l10n.nibiGreetTrend1, l10n.nibiGreetTrend2]);
    }
    if (variationSeed == 0) {
      return l10n.nibiGreetHello;
    }
    if (h >= 5 && h < 12) {
      return pick(<String>[
        l10n.nibiGreetMorning0,
        l10n.nibiGreetMorning1,
        l10n.nibiGreetMorning2,
        l10n.nibiGreetMorning3,
      ]);
    } else if (h >= 12 && h < 19) {
      return pick(<String>[
        l10n.nibiGreetAfternoon0,
        l10n.nibiGreetAfternoon1,
        l10n.nibiGreetAfternoon2,
        l10n.nibiGreetAfternoon3,
      ]);
    }
    return pick(<String>[
      l10n.nibiGreetNight0,
      l10n.nibiGreetNight1,
      l10n.nibiGreetNight2,
      l10n.nibiGreetNight3,
    ]);
  }
}

final textAssistantProvider = Provider<TextAssistant>((Ref ref) => const TextAssistant());

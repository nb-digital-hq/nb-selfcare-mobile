/// Catálogo de "Libre": hábitos que la persona quiere dejar, lo que gana su
/// cuerpo con el tiempo y los hitos de cada racha.
///
/// Los beneficios salen de fuentes de salud pública (OMS, CDC, NHS, Sociedad
/// Americana del Cáncer) y de estudios citados en `docs/13_QUIT.md`. Se
/// redactan como "suele", "puede": cada cuerpo va a su ritmo.
library;

/// Cómo se mide lo que se deja: por unidades (cigarrillos, bebidas…) o por
/// tiempo (redes, videojuegos). Decide qué preguntas hace el formulario.
enum QuitMeasure { units, time, none }

/// Un beneficio que llega al cumplir [after] sin el hábito. El texto visible
/// vive en el ARB (`quitBenefit_<key>`).
class QuitBenefit {
  const QuitBenefit(this.after, this.key);

  final Duration after;
  final String key;
}

/// Hábito del catálogo. El nombre visible vive en el ARB (`quitPreset_<key>`).
class QuitPreset {
  const QuitPreset({
    required this.key,
    required this.measure,
    this.benefits = const <QuitBenefit>[],
    this.medicalNote = false,
  });

  final String key;
  final QuitMeasure measure;
  final List<QuitBenefit> benefits;

  /// Dejarlo de golpe puede requerir acompañamiento médico (alcohol).
  final bool medicalNote;

  static const String customKey = 'custom';

  static const QuitPreset tobacco = QuitPreset(
    key: 'tobacco',
    measure: QuitMeasure.units,
    benefits: <QuitBenefit>[
      QuitBenefit(Duration(minutes: 20), 'tobacco_20m'),
      QuitBenefit(Duration(hours: 12), 'tobacco_12h'),
      QuitBenefit(Duration(days: 2), 'tobacco_2d'),
      QuitBenefit(Duration(days: 3), 'tobacco_3d'),
      QuitBenefit(Duration(days: 14), 'tobacco_2w'),
      QuitBenefit(Duration(days: 30), 'tobacco_1m'),
      QuitBenefit(Duration(days: 365), 'tobacco_1y'),
      QuitBenefit(Duration(days: 365 * 5), 'tobacco_5y'),
      QuitBenefit(Duration(days: 365 * 10), 'tobacco_10y'),
    ],
  );

  static const QuitPreset vape = QuitPreset(
    key: 'vape',
    measure: QuitMeasure.units,
    benefits: <QuitBenefit>[
      QuitBenefit(Duration(minutes: 20), 'vape_20m'),
      QuitBenefit(Duration(days: 3), 'vape_3d'),
      QuitBenefit(Duration(days: 14), 'vape_2w'),
      QuitBenefit(Duration(days: 28), 'vape_4w'),
      QuitBenefit(Duration(days: 90), 'vape_3m'),
    ],
  );

  static const QuitPreset alcohol = QuitPreset(
    key: 'alcohol',
    measure: QuitMeasure.units,
    medicalNote: true,
    benefits: <QuitBenefit>[
      QuitBenefit(Duration(days: 1), 'alcohol_1d'),
      QuitBenefit(Duration(days: 3), 'alcohol_3d'),
      QuitBenefit(Duration(days: 7), 'alcohol_1w'),
      QuitBenefit(Duration(days: 14), 'alcohol_2w'),
      QuitBenefit(Duration(days: 30), 'alcohol_1m'),
      QuitBenefit(Duration(days: 90), 'alcohol_3m'),
      QuitBenefit(Duration(days: 365), 'alcohol_1y'),
    ],
  );

  static const QuitPreset sugar = QuitPreset(
    key: 'sugar',
    measure: QuitMeasure.units,
    benefits: _sugarBenefits,
  );

  static const QuitPreset soda = QuitPreset(
    key: 'soda',
    measure: QuitMeasure.units,
    benefits: _sugarBenefits,
  );

  static const QuitPreset junkFood = QuitPreset(
    key: 'junk_food',
    measure: QuitMeasure.units,
    benefits: _sugarBenefits,
  );

  static const QuitPreset caffeine = QuitPreset(
    key: 'caffeine',
    measure: QuitMeasure.units,
    benefits: <QuitBenefit>[
      QuitBenefit(Duration(days: 1), 'caffeine_1d'),
      QuitBenefit(Duration(days: 2), 'caffeine_2d'),
      QuitBenefit(Duration(days: 9), 'caffeine_9d'),
      QuitBenefit(Duration(days: 14), 'caffeine_2w'),
    ],
  );

  static const QuitPreset socialMedia = QuitPreset(
    key: 'social_media',
    measure: QuitMeasure.time,
    benefits: _screenBenefits,
  );

  static const QuitPreset gaming = QuitPreset(
    key: 'gaming',
    measure: QuitMeasure.time,
    benefits: _screenBenefits,
  );

  static const QuitPreset gambling = QuitPreset(
    key: 'gambling',
    measure: QuitMeasure.none,
    benefits: <QuitBenefit>[
      QuitBenefit(Duration(days: 1), 'gambling_1d'),
      QuitBenefit(Duration(days: 7), 'gambling_1w'),
      QuitBenefit(Duration(days: 30), 'gambling_1m'),
      QuitBenefit(Duration(days: 90), 'gambling_3m'),
    ],
  );

  static const QuitPreset cannabis = QuitPreset(
    key: 'cannabis',
    measure: QuitMeasure.units,
    benefits: <QuitBenefit>[
      QuitBenefit(Duration(days: 2), 'cannabis_2d'),
      QuitBenefit(Duration(days: 7), 'cannabis_1w'),
      QuitBenefit(Duration(days: 14), 'cannabis_2w'),
      QuitBenefit(Duration(days: 28), 'cannabis_4w'),
    ],
  );

  static const QuitPreset adultContent = QuitPreset(
    key: 'adult_content',
    measure: QuitMeasure.time,
  );

  static const QuitPreset nailBiting = QuitPreset(
    key: 'nail_biting',
    measure: QuitMeasure.none,
    benefits: <QuitBenefit>[
      QuitBenefit(Duration(days: 7), 'nails_1w'),
      QuitBenefit(Duration(days: 30), 'nails_1m'),
      QuitBenefit(Duration(days: 120), 'nails_4m'),
    ],
  );

  static const QuitPreset custom = QuitPreset(key: customKey, measure: QuitMeasure.units);

  static const List<QuitBenefit> _sugarBenefits = <QuitBenefit>[
    QuitBenefit(Duration(days: 3), 'sugar_3d'),
    QuitBenefit(Duration(days: 14), 'sugar_2w'),
    QuitBenefit(Duration(days: 30), 'sugar_1m'),
    QuitBenefit(Duration(days: 90), 'sugar_3m'),
  ];

  static const List<QuitBenefit> _screenBenefits = <QuitBenefit>[
    QuitBenefit(Duration(days: 1), 'screen_1d'),
    QuitBenefit(Duration(days: 7), 'screen_1w'),
    QuitBenefit(Duration(days: 21), 'screen_3w'),
  ];

  /// Orden en el que se ofrecen al crear un contador.
  static const List<QuitPreset> all = <QuitPreset>[
    tobacco,
    vape,
    alcohol,
    sugar,
    soda,
    junkFood,
    caffeine,
    socialMedia,
    gaming,
    gambling,
    cannabis,
    adultContent,
    nailBiting,
    custom,
  ];

  /// Preset por clave; una clave desconocida (datos antiguos) se trata como propio.
  static QuitPreset byKey(String key) {
    for (final QuitPreset p in all) {
      if (p.key == key) return p;
    }
    return custom;
  }
}

/// Hitos de racha comunes a todos los hábitos: se celebran y dan monedas.
abstract final class QuitMilestones {
  static const List<Duration> all = <Duration>[
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
    Duration(days: 14),
    Duration(days: 30),
    // Mediana de días hasta que un hábito se vuelve automático (Lally et al., 2010).
    Duration(days: 66),
    Duration(days: 90),
    Duration(days: 180),
    Duration(days: 365),
    Duration(days: 730),
  ];

  /// Índice del hito de 66 días, que tiene un mensaje propio.
  static const int automaticityIndex = 5;

  /// Cuántos hitos se alcanzaron con [streak] (0 = ninguno).
  static int reachedCount(Duration streak) {
    int n = 0;
    for (final Duration d in all) {
      if (streak >= d) n++;
    }
    return n;
  }

  /// Siguiente hito o `null` si ya se superaron todos.
  static Duration? next(Duration streak) {
    for (final Duration d in all) {
      if (streak < d) return d;
    }
    return null;
  }

  /// Hito anterior a [streak] (cero si aún no hay ninguno).
  static Duration previous(Duration streak) {
    Duration last = Duration.zero;
    for (final Duration d in all) {
      if (streak >= d) last = d;
    }
    return last;
  }
}

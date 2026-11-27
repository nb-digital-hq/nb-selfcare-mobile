import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/services/text_assistant.dart';

import '../support/l10n_es.dart';

/// Texto libre del dictado, del teclado y del OCR de etiquetas: emojis, otros
/// alfabetos, cifras absurdas, textos enormes y basura de reconocimiento.
const List<String> _weird = <String>[
  '',
  '   \n\t  ',
  '\u{1F355}\u{1F355}\u{1F355} y \u{1F37A}',
  '0 g de arroz',
  '-200 g de pollo',
  '999999999 gramos de pasta',
  '1e10 g de azúcar',
  '200000 huevos',
  '1,5,6 g de avena',
  '...,,,;;;',
  'y y y y y con con con',
  '200 g de',
  'g de',
  'Ελληνικά 200 γραμμάρια',
  '日本語のご飯 300g',
  'سلطة 100 g de lechuga',
  'DROP TABLE food_items; --',
  "200 g de pollo'); DELETE FROM food_logs; --",
  r'\u0000 nulo \x00',
];

void main() {
  const TextAssistant assistant = TextAssistant();

  group('Dictado / texto de comida', () {
    test('casos raros: nunca lanza y cada alimento es registrable', () async {
      for (final String input in _weird) {
        final ParsedMealResult r = await assistant.parseMealText(input);
        for (final ParsedMealItem item in r.items) {
          expect(item.searchTerm.trim(), isNotEmpty, reason: input);
          expect(item.grams, inInclusiveRange(1, 5000), reason: '"$input" → ${item.grams} g');
          for (final double v in <double>[
            item.fallbackKcal,
            item.fallbackP,
            item.fallbackC,
            item.fallbackF,
          ]) {
            expect(v.isFinite && v >= 0, isTrue, reason: input);
          }
        }
      }
    });

    test('2 000 frases aleatorias con números y unidades', () async {
      final Random rng = Random(7);
      const List<String> words = <String>[
        '200',
        'g',
        'gr',
        'gramos',
        'de',
        'y',
        'con',
        'pollo',
        'arroz',
        '3',
        'huevos',
        'manzana',
        ',',
        'ml',
        'leche',
        '0',
        '-5',
        '1.5',
        '\u{1F600}',
        'piel',
        'una',
        'x',
      ];
      for (int i = 0; i < 2000; i++) {
        final String input = List<String>.generate(
          rng.nextInt(14),
          (_) => words[rng.nextInt(words.length)],
        ).join(' ');
        final ParsedMealResult r = await assistant.parseMealText(input);
        for (final ParsedMealItem item in r.items) {
          expect(item.grams, inInclusiveRange(1, 5000), reason: '"$input"');
        }
      }
    });

    test('un dictado larguísimo (50 000 caracteres) se procesa en poco tiempo', () async {
      final String huge = List<String>.filled(2500, '200 g de pollo y ').join();
      final Stopwatch sw = Stopwatch()..start();
      final ParsedMealResult r = await assistant.parseMealText(huge);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(r.items, isNotEmpty);
    });
  });

  group('Diario', () {
    test('ánimo, energía y estrés siempre en 1–5, incluso con texto raro', () async {
      for (final String input in <String>[
        ..._weird,
        List<String>.filled(5000, 'feliz triste cansado ').join(),
      ]) {
        final JournalTextAnalysis a = await assistant.analyzeJournal(input, l10nEs);
        expect(a.moodScore, inInclusiveRange(1, 5), reason: input);
        expect(a.energyLevel, inInclusiveRange(1, 5), reason: input);
        expect(a.stressLevel, inInclusiveRange(1, 5), reason: input);
        expect(a.oneLineInsight, isNotEmpty);
      }
    });
  });
}

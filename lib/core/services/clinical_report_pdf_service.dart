import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/utils/biometric_formulas.dart';
import '../../shared/utils/number_formats.dart';
import '../clock/clock.dart';
import '../database/app_database.dart';
import '../domain/enums.dart';
import '../l10n/l10n.dart';
import 'smart_meal_suggester.dart';

/// Servicio de generación de informes clínicos en formato PDF 100% offline.
class ClinicalReportPdfService {
  ClinicalReportPdfService({this._clock = const Clock()});

  final Clock _clock;

  /// Genera un documento PDF formal (A4) con las métricas de composición corporal,
  /// nutrición, cronobiología y adherencia a suplementos.
  Future<Uint8List> generateReportBytes({
    required AppLocalizations l10n,
    required UserProfile profile,
    required BodyMeasurement? latestMeasurement,
    required List<BodyMeasurement> recentMeasurements,
    required int averageDailyKcal,
    required int foodDays,
    required double averageProteinG,
    required double averageCarbsG,
    required double averageFatG,
    required double averageSleepHours,
    required List<SupplementsTrackerData> activeSupplements,
    required int? readinessScore,
    List<String> vitalsSummary = const <String>[],
    List<String> symptomsSummary = const <String>[],
  }) async {
    // La fuente empaquetada cubre símbolos clínicos que faltan en las fuentes PDF básicas.
    // Se crea por documento: el objeto Font mantiene estado del PDF al que pertenece.
    final fuenteDeRespaldo = pw.Font.ttf(await rootBundle.load('assets/fonts/Manrope.ttf'));
    final pw.Document pdf = pw.Document(
      title: l10n.reportInformeDeSaludPersonal,
      author: l10n.reportNbSelfcare,
      theme: pw.ThemeData.withFont(fontFallback: <pw.Font>[fuenteDeRespaldo]),
    );

    // El informe también se genera fuera de la interfaz (pruebas, servicios):
    // los datos de fechas del idioma se cargan aquí y no se dan por supuestos.
    await initializeDateFormatting(l10n.localeName);
    final DateTime now = _clock.now();
    // Años cumplidos (24, no "25,0" a una semana del cumpleaños).
    final int age = BiometricFormulas.calculateDynamicAge(profile.birthDate, now).floor();
    final String dateStr = _longDate(now, l10n.localeName);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              // Encabezado institucional
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        l10n.reportInformeDeSaludPersonal,
                        style: const pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        l10n.reportGeneradoEnElTelefonoCon,
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
                      ),
                    ],
                  ),
                  pw.Text(
                    dateStr,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.blueGrey300, thickness: 1),
              pw.SizedBox(height: 10),

              // 1. Datos Demográficos y Objetivos
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    _pdfField(l10n.reportNombre, profile.name),
                    _pdfField(l10n.reportEdad, l10n.reportAnos(age.toString())),
                    _pdfField(
                      l10n.reportSexoBiologico,
                      profile.biologicalSex == BiologicalSex.female
                          ? l10n.reportFemenino
                          : l10n.reportMasculino,
                    ),
                    _pdfField(
                      l10n.reportEstatura,
                      '${NumberFormats.fixed(profile.heightCm, 0, l10n.localeName)} cm',
                    ),
                    _pdfField(
                      l10n.reportPesoMeta,
                      '${NumberFormats.fixed(profile.targetWeightKg, 1, l10n.localeName)} kg',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 2. Composición Corporal (Báscula BIA + Tendencia EMA)
              pw.Text(
                l10n.report1ComposicionCorporal,
                style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: <pw.TableRow>[
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: <pw.Widget>[
                      _tableHeader(l10n.reportMedida),
                      _tableHeader(l10n.reportUltimoValor),
                      _tableHeader(l10n.reportTendencia),
                      _tableHeader(l10n.reportReferencia),
                    ],
                  ),
                  _tableRow(
                    l10n.reportPeso,
                    latestMeasurement != null
                        ? '${NumberFormats.fixed(latestMeasurement.weightKg, 1, l10n.localeName)} kg'
                        : 'N/D',
                    latestMeasurement != null
                        ? '${NumberFormats.fixed(latestMeasurement.trendWeightKg, 1, l10n.localeName)} kg'
                        : 'N/D',
                    l10n.reportImc(
                      (latestMeasurement == null
                              ? 'N/D'
                              : NumberFormats.fixed(latestMeasurement.bmi, 1, l10n.localeName))
                          .toString(),
                    ),
                  ),
                  _tableRow(
                    l10n.reportGrasaCorporal,
                    latestMeasurement?.bodyFatPercentage != null
                        ? '${NumberFormats.fixed(latestMeasurement!.bodyFatPercentage!, 1, l10n.localeName)} %'
                        : 'N/D',
                    '-',
                    l10n.reportGrasaVisceral(
                      (latestMeasurement?.visceralFatIndex ?? 'N/D').toString(),
                    ),
                  ),
                  _tableRow(
                    l10n.reportMasaMuscular,
                    latestMeasurement?.muscleMassKg != null
                        ? '${NumberFormats.fixed(latestMeasurement!.muscleMassKg!, 1, l10n.localeName)} kg'
                        : 'N/D',
                    '-',
                    l10n.reportMasaLibreDeGrasaKg(
                      (latestMeasurement?.leanBodyMassKg == null
                              ? 'N/D'
                              : NumberFormats.fixed(
                                  latestMeasurement!.leanBodyMassKg!,
                                  1,
                                  l10n.localeName,
                                ))
                          .toString(),
                    ),
                  ),
                  _tableRow(
                    l10n.reportAguaCorporal,
                    latestMeasurement?.waterPercentage != null
                        ? '${NumberFormats.fixed(latestMeasurement!.waterPercentage!, 1, l10n.localeName)} %'
                        : 'N/D',
                    '-',
                    l10n.reportRangoHabitual5065,
                  ),
                  _tableRow(
                    l10n.reportMetabolismoBasal,
                    latestMeasurement?.basalMetabolicRateKcal != null
                        ? '${NumberFormats.group(latestMeasurement!.basalMetabolicRateKcal!, l10n.localeName)} kcal'
                        : 'N/D',
                    '-',
                    l10n.reportEdadMetabolicaAnos(
                      (latestMeasurement?.metabolicAge ?? 'N/D').toString(),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 3. Nutrición & Perfil de Macronutrientes
              pw.Text(
                l10n.report2AlimentacionMediaDeLos,
                style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    _pdfField(
                      l10n.reportEnergia,
                      l10n.reportKcalDia(
                        NumberFormats.group(averageDailyKcal, l10n.localeName).toString(),
                      ),
                    ),
                    _pdfField(
                      l10n.reportProteina,
                      l10n.reportGDia(
                        NumberFormats.fixed(averageProteinG, 0, l10n.localeName).toString(),
                      ),
                    ),
                    _pdfField(
                      l10n.reportCarbohidratos,
                      l10n.reportGDia(
                        NumberFormats.fixed(averageCarbsG, 0, l10n.localeName).toString(),
                      ),
                    ),
                    _pdfField(
                      l10n.reportGrasas,
                      l10n.reportGDia(
                        NumberFormats.fixed(averageFatG, 0, l10n.localeName).toString(),
                      ),
                    ),
                    _pdfField(
                      l10n.reportEstilo,
                      DietArchetypeInfo.getById(l10n, profile.activeDietArchetype).name,
                    ),
                    _pdfField(l10n.reportDiasConRegistro, l10n.reportDe7(foodDays.toString())),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 4. Cronobiología, Recuperación & Suplementación
              pw.Text(
                l10n.report3DescansoYSuplementos,
                style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: <pw.Widget>[
                        _pdfField(
                          l10n.reportSuenoMedio,
                          averageSleepHours > 0
                              ? l10n.todayHNoche(
                                  NumberFormats.fixed(averageSleepHours, 1, l10n.localeName),
                                )
                              : l10n.reportSinRegistros,
                        ),
                        _pdfField(
                          l10n.reportDisposicionDeHoy,
                          readinessScore == null
                              ? l10n.reportSinSuenoRegistrado
                              : '$readinessScore / 100',
                        ),
                        if (profile.biologicalSex == BiologicalSex.female)
                          _pdfField(
                            l10n.reportSeguimientoDelCiclo,
                            profile.isCycleTrackingEnabled
                                ? l10n.reportActivo
                                : l10n.reportInactivo,
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      l10n.reportMedicamentosYSuplementos,
                      style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      activeSupplements.isEmpty
                          ? l10n.reportNinguno
                          : activeSupplements.map((s) => '- ${s.name} (${s.dosage})').join('   '),
                      style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.blueGrey800),
                    ),
                    if (vitalsSummary.isNotEmpty) ...<pw.Widget>[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        l10n.reportSignosVitalesUltimos30Dias,
                        style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        vitalsSummary.join('\n'),
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.blueGrey800),
                      ),
                    ],
                    if (symptomsSummary.isNotEmpty) ...<pw.Widget>[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        l10n.reportSintomasMasFrecuentesUltimos30,
                        style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        symptomsSummary.join('   '),
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.blueGrey800),
                      ),
                    ],
                  ],
                ),
              ),

              pw.Spacer(),

              // Descargo médico
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  l10n.reportAvisoEsteDocumentoResumeRegistros,
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey700,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Una línea por signo vital: media, rango y número de mediciones.
  static List<String> summarizeVitals(AppLocalizations l10n, List<VitalReading> readings) {
    final Map<String, (String, String)> names = <String, (String, String)>{
      'blood_pressure': (l10n.reportTensionArterial, 'mmHg'),
      'glucose': (l10n.reportGlucosa, 'mg/dL'),
      'oxygen': (l10n.reportOxigenoEnSangre, '%'),
      'temperature': (l10n.reportTemperatura, '°C'),
    };
    final List<String> lines = <String>[];
    for (final MapEntry<String, (String, String)> e in names.entries) {
      final List<VitalReading> rows = readings.where((VitalReading r) => r.kind == e.key).toList();
      if (rows.isEmpty) continue;
      double mean(Iterable<double> v) => v.reduce((double a, double b) => a + b) / v.length;
      final double p = mean(rows.map((VitalReading r) => r.primaryValue));
      final List<double> secondary = rows
          .map((VitalReading r) => r.secondaryValue)
          .whereType<double>()
          .toList();
      final String value = e.key == 'blood_pressure' && secondary.isNotEmpty
          ? '${p.round()}/${mean(secondary).round()}'
          : (e.key == 'temperature' ? NumberFormats.fixed(p, 1, l10n.localeName) : '${p.round()}');
      lines.add(
        l10n.reportMediaMediciones(
          e.value.$1.toString(),
          value.toString(),
          e.value.$2.toString(),
          rows.length.toString(),
        ),
      );
    }
    return lines;
  }

  /// Fecha larga en el idioma del informe ("28 de octubre de 2026").
  static String _longDate(DateTime d, String locale) => DateFormat.yMMMMd(locale).format(d);

  /// Despliega el visor de impresión nativo o comparte el PDF.
  Future<void> shareOrPrintReport({
    required AppLocalizations l10n,
    required UserProfile profile,
    required BodyMeasurement? latestMeasurement,
    required List<BodyMeasurement> recentMeasurements,
    required int averageDailyKcal,
    required int foodDays,
    required double averageProteinG,
    required double averageCarbsG,
    required double averageFatG,
    required double averageSleepHours,
    required List<SupplementsTrackerData> activeSupplements,
    required int? readinessScore,
    List<String> vitalsSummary = const <String>[],
    List<String> symptomsSummary = const <String>[],
  }) async {
    final Uint8List pdfBytes = await generateReportBytes(
      l10n: l10n,
      profile: profile,
      latestMeasurement: latestMeasurement,
      recentMeasurements: recentMeasurements,
      averageDailyKcal: averageDailyKcal,
      foodDays: foodDays,
      averageProteinG: averageProteinG,
      averageCarbsG: averageCarbsG,
      averageFatG: averageFatG,
      averageSleepHours: averageSleepHours,
      activeSupplements: activeSupplements,
      readinessScore: readinessScore,
      vitalsSummary: vitalsSummary,
      symptomsSummary: symptomsSummary,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename:
          'reporte_clinico_${profile.name.replaceAll(" ", "_").toLowerCase()}_${_clock.now().toIso8601String().split("T").first}.pdf',
    );
  }

  static pw.Widget _pdfField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.TableRow _tableRow(String metric, String current, String ema, String reference) {
    return pw.TableRow(
      children: <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(metric, style: const pw.TextStyle(fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            current,
            style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(ema, style: const pw.TextStyle(fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            reference,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }
}

/// Provider de Riverpod para ClinicalReportPdfService.
final clinicalReportPdfServiceProvider = Provider<ClinicalReportPdfService>((ref) {
  return ClinicalReportPdfService(clock: ref.watch(clockProvider));
});

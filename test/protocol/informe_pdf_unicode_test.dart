import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/clock/clock.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/l10n/l10n.dart';
import 'package:nb_selfcare/core/services/clinical_report_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final idioma in <String>['es', 'en', 'pt']) {
    test('el informe $idioma dibuja acentos y símbolos clínicos sin glifos ausentes', () async {
      final UserProfile perfil = UserProfile(
        id: 1,
        name: 'Demostración: niñez y alimentação',
        birthDate: DateTime(1992, 5, 14),
        biologicalSex: BiologicalSex.male,
        heightCm: 178.0,
        targetWeightKg: 74.0,
        weeklyGoalRateKg: -0.4,
        dailyWaterGoalMl: 2500,
        dailyStepsGoal: 10000,
        dailySleepGoalHours: 8.0,
        currentAdaptiveTdeeKcal: 2150,
        themeMode: 'system',
        isLocalAiEnabled: true,
        isCycleTrackingEnabled: false,
        isFastingEnabled: true,
        isManualMacroMode: false,
        activeDietArchetype: DietArchetype.mediterranean,
        activeDietPhase: DietPhase.deficit,
        calorieCyclingScheduleJson: '',
        caffeineBedtimeCutoffHours: 8.0,
        hasImpedanceContraindication: false,
        hasEatingDisorderHistory: false,
        takesHypoglycemicMedication: false,
        hasSmartScale: true,
        vitalDevicesJson: '[]',
        careModulesJson:
            '["treatments","pelvic_floor","active_breaks","symptoms","checkups","habits"]',
        discreetNotifications: true,
        targetBedtimeMinutes: 1380,
        createdAt: DateTime(2026, 11, 25),
      );

      final avisos = <String>[];
      final bytes = await runZoned(
        () =>
            ClinicalReportPdfService(clock: Clock.fixed(DateTime(2026, 11, 25)))
                .generateReportBytes(
                  l10n: lookupAppLocalizations(Locale(idioma)),
                  profile: perfil,
                  latestMeasurement: null,
                  recentMeasurements: const <BodyMeasurement>[],
                  averageDailyKcal: 2120,
                  foodDays: 7,
                  averageProteinG: 155,
                  averageCarbsG: 210,
                  averageFatG: 62,
                  averageSleepHours: 7.8,
                  activeSupplements: const <SupplementsTrackerData>[],
                  readinessScore: 88,
                  vitalsSummary: const <String>['SpO₂ ≥ 95 % · presión ≤ 120 mmHg'],
                  symptomsSummary: const <String>['Energía → recuperación'],
                ),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, mensaje) {
            avisos.add(mensaje);
          },
        ),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(avisos.where((mensaje) => mensaje.contains('Unable to find a font')), isEmpty);
      // Solo el recorrido de QA optativo conserva documentos con estos datos sintéticos.
      final salida = Platform.environment['NB_SELFCARE_QA_PDF_DIR'];
      if (salida != null) {
        final carpeta = Directory(salida);
        expect(carpeta.isAbsolute, isTrue);
        await carpeta.create(recursive: true);
        await File('${carpeta.path}/informe-$idioma.pdf').writeAsBytes(bytes);
      }
    });
  }
}

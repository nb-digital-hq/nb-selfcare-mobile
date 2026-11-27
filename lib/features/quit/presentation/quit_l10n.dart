import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/utils/number_formats.dart';
import '../domain/quit_catalog.dart';
import '../domain/quit_progress.dart';

/// Textos e iconos de "Libre" (todo el texto vive en el ARB).
abstract final class QuitText {
  static String preset(AppLocalizations l10n, String key) => switch (key) {
    'tobacco' => l10n.quitPresetTobacco,
    'vape' => l10n.quitPresetVape,
    'alcohol' => l10n.quitPresetAlcohol,
    'sugar' => l10n.quitPresetSugar,
    'soda' => l10n.quitPresetSoda,
    'junk_food' => l10n.quitPresetJunkFood,
    'caffeine' => l10n.quitPresetCaffeine,
    'social_media' => l10n.quitPresetSocialMedia,
    'gaming' => l10n.quitPresetGaming,
    'gambling' => l10n.quitPresetGambling,
    'cannabis' => l10n.quitPresetCannabis,
    'adult_content' => l10n.quitPresetAdultContent,
    'nail_biting' => l10n.quitPresetNailBiting,
    _ => l10n.quitPresetCustom,
  };

  static IconData icon(String key) => switch (key) {
    'tobacco' => Icons.smoke_free_rounded,
    'vape' => Icons.cloud_off_outlined,
    'alcohol' => Icons.no_drinks_outlined,
    'sugar' => Icons.cookie_outlined,
    'soda' => Icons.local_drink_outlined,
    'junk_food' => Icons.fastfood_outlined,
    'caffeine' => Icons.coffee_outlined,
    'social_media' => Icons.phonelink_erase_rounded,
    'gaming' => Icons.sports_esports_outlined,
    'gambling' => Icons.casino_outlined,
    'cannabis' => Icons.grass_rounded,
    'adult_content' => Icons.visibility_off_outlined,
    'nail_biting' => Icons.back_hand_outlined,
    _ => Icons.flag_outlined,
  };

  /// Nombre del contador: el propio o el del catálogo.
  static String name(AppLocalizations l10n, QuitTracker t) =>
      t.presetKey == QuitPreset.customKey && (t.customName ?? '').isNotEmpty
      ? t.customName!
      : preset(l10n, t.presetKey);

  /// Qué se cuenta al día para [preset] ("Cigarrillos al día").
  static String unitsQuestion(AppLocalizations l10n, String key) => switch (key) {
    'tobacco' => l10n.quitUnitsTobacco,
    'vape' => l10n.quitUnitsVape,
    'alcohol' => l10n.quitUnitsAlcohol,
    'sugar' || 'junk_food' => l10n.quitUnitsPortions,
    'soda' => l10n.quitUnitsSoda,
    'caffeine' => l10n.quitUnitsCaffeine,
    'cannabis' => l10n.quitUnitsTimes,
    _ => l10n.quitUnitsTimes,
  };

  /// Lo que no se consumió ("142 cigarrillos").
  static String unitsAvoided(AppLocalizations l10n, String key, double units) {
    final String n = NumberFormats.group(units.floor());
    return switch (key) {
      'tobacco' => l10n.quitAvoidedTobacco(n),
      'alcohol' => l10n.quitAvoidedAlcohol(n),
      'soda' => l10n.quitAvoidedSoda(n),
      'caffeine' => l10n.quitAvoidedCaffeine(n),
      'sugar' || 'junk_food' => l10n.quitAvoidedPortions(n),
      _ => l10n.quitAvoidedTimes(n),
    };
  }

  static String benefit(AppLocalizations l10n, String key) => switch (key) {
    'tobacco_20m' => l10n.quitBenefitTobacco20m,
    'tobacco_12h' => l10n.quitBenefitTobacco12h,
    'tobacco_2d' => l10n.quitBenefitTobacco2d,
    'tobacco_3d' => l10n.quitBenefitTobacco3d,
    'tobacco_2w' => l10n.quitBenefitTobacco2w,
    'tobacco_1m' => l10n.quitBenefitTobacco1m,
    'tobacco_1y' => l10n.quitBenefitTobacco1y,
    'tobacco_5y' => l10n.quitBenefitTobacco5y,
    'tobacco_10y' => l10n.quitBenefitTobacco10y,
    'vape_20m' => l10n.quitBenefitVape20m,
    'vape_3d' => l10n.quitBenefitVape3d,
    'vape_2w' => l10n.quitBenefitVape2w,
    'vape_4w' => l10n.quitBenefitVape4w,
    'vape_3m' => l10n.quitBenefitVape3m,
    'alcohol_1d' => l10n.quitBenefitAlcohol1d,
    'alcohol_3d' => l10n.quitBenefitAlcohol3d,
    'alcohol_1w' => l10n.quitBenefitAlcohol1w,
    'alcohol_2w' => l10n.quitBenefitAlcohol2w,
    'alcohol_1m' => l10n.quitBenefitAlcohol1m,
    'alcohol_3m' => l10n.quitBenefitAlcohol3m,
    'alcohol_1y' => l10n.quitBenefitAlcohol1y,
    'sugar_3d' => l10n.quitBenefitSugar3d,
    'sugar_2w' => l10n.quitBenefitSugar2w,
    'sugar_1m' => l10n.quitBenefitSugar1m,
    'sugar_3m' => l10n.quitBenefitSugar3m,
    'caffeine_1d' => l10n.quitBenefitCaffeine1d,
    'caffeine_2d' => l10n.quitBenefitCaffeine2d,
    'caffeine_9d' => l10n.quitBenefitCaffeine9d,
    'caffeine_2w' => l10n.quitBenefitCaffeine2w,
    'screen_1d' => l10n.quitBenefitScreen1d,
    'screen_1w' => l10n.quitBenefitScreen1w,
    'screen_3w' => l10n.quitBenefitScreen3w,
    'gambling_1d' => l10n.quitBenefitGambling1d,
    'gambling_1w' => l10n.quitBenefitGambling1w,
    'gambling_1m' => l10n.quitBenefitGambling1m,
    'gambling_3m' => l10n.quitBenefitGambling3m,
    'cannabis_2d' => l10n.quitBenefitCannabis2d,
    'cannabis_1w' => l10n.quitBenefitCannabis1w,
    'cannabis_2w' => l10n.quitBenefitCannabis2w,
    'cannabis_4w' => l10n.quitBenefitCannabis4w,
    'nails_1w' => l10n.quitBenefitNails1w,
    'nails_1m' => l10n.quitBenefitNails1m,
    'nails_4m' => l10n.quitBenefitNails4m,
    _ => '',
  };

  /// "20 min", "12 h", "3 días", "2 semanas", "1 mes", "1 año"…
  static String span(AppLocalizations l10n, Duration d) {
    final int days = d.inDays;
    if (days == 0) {
      return d.inHours > 0 ? l10n.quitSpanHours(d.inHours) : l10n.quitSpanMinutes(d.inMinutes);
    }
    if (days % 365 == 0) return l10n.quitSpanYears(days ~/ 365);
    if (days % 30 == 0 && days < 365) return l10n.quitSpanMonths(days ~/ 30);
    if (days % 7 == 0 && days < 30) return l10n.quitSpanWeeks(days ~/ 7);
    return l10n.quitSpanDays(days);
  }

  /// Racha compacta: "12 d 4 h", "4 h 33 min" o "33 min".
  static String compact(AppLocalizations l10n, Duration d) {
    final DurationParts p = DurationParts.of(d);
    if (p.days > 0) return l10n.quitCompactDaysHours(p.days, p.hours);
    if (p.hours > 0) return l10n.quitCompactHoursMinutes(p.hours, p.minutes);
    return l10n.quitCompactMinutes(p.minutes);
  }

  /// Horas y minutos recuperados ("37 h 20 min").
  static String reclaimed(AppLocalizations l10n, int minutes) {
    if (minutes < 60) return l10n.quitCompactMinutes(minutes);
    return l10n.quitCompactHoursMinutes(minutes ~/ 60, minutes % 60);
  }

  static String money(AppLocalizations l10n, double amount) =>
      l10n.quitMoney(NumberFormats.group(amount.floor()));

  /// Mensaje del hito alcanzado.
  static String milestoneCheer(AppLocalizations l10n, int index, String name) {
    final String span = QuitText.span(l10n, QuitMilestones.all[index]);
    return index == QuitMilestones.automaticityIndex
        ? l10n.quitMilestoneAutomatic(name)
        : l10n.quitMilestoneCheer(span, name);
  }
}

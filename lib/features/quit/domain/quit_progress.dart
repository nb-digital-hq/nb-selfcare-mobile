import 'dart:math' as math;

import 'quit_catalog.dart';

/// Lo que lleva ganado un contador de "Libre" en un instante dado. Puro y
/// testeable: recibe los datos del contador y la hora del `Clock`.
class QuitProgress {
  const QuitProgress._({
    required this.streak,
    required this.cleanTime,
    required this.longest,
    required this.moneySaved,
    required this.unitsAvoided,
    required this.minutesReclaimed,
    required this.milestonesReached,
    required this.nextMilestone,
    required this.milestoneFraction,
  });

  factory QuitProgress.compute({
    required DateTime startedAt,
    required DateTime now,
    int bankedSeconds = 0,
    int longestStreakSeconds = 0,
    double? dailyCost,
    double? dailyUnits,
    int? dailyMinutes,
  }) {
    // Un inicio en el futuro (reloj cambiado) cuenta como recién empezado.
    final Duration streak = now.isBefore(startedAt) ? Duration.zero : now.difference(startedAt);
    final Duration clean = streak + Duration(seconds: math.max(0, bankedSeconds));
    final double cleanDays = clean.inSeconds / Duration.secondsPerDay;
    final Duration longest = Duration(seconds: math.max(longestStreakSeconds, streak.inSeconds));
    final Duration? next = QuitMilestones.next(streak);
    final Duration prev = QuitMilestones.previous(streak);
    final double fraction = next == null
        ? 1.0
        : ((streak - prev).inSeconds / (next - prev).inSeconds).clamp(0.0, 1.0);
    return QuitProgress._(
      streak: streak,
      cleanTime: clean,
      longest: longest,
      moneySaved: dailyCost == null || dailyCost <= 0 ? null : dailyCost * cleanDays,
      unitsAvoided: dailyUnits == null || dailyUnits <= 0 ? null : dailyUnits * cleanDays,
      minutesReclaimed: dailyMinutes == null || dailyMinutes <= 0
          ? null
          : (dailyMinutes * cleanDays).floor(),
      milestonesReached: QuitMilestones.reachedCount(streak),
      nextMilestone: next,
      milestoneFraction: fraction,
    );
  }

  /// Racha actual.
  final Duration streak;

  /// Tiempo libre total: la racha actual más las anteriores.
  final Duration cleanTime;

  /// Mejor racha (incluida la actual si ya la superó).
  final Duration longest;

  /// Dinero que ya no se gastó (en la moneda que la persona usa), o `null`.
  final double? moneySaved;

  /// Unidades que no se consumieron (cigarrillos, bebidas…), o `null`.
  final double? unitsAvoided;

  /// Minutos recuperados (redes, videojuegos…), o `null`.
  final int? minutesReclaimed;

  /// Hitos de racha alcanzados (índice en [QuitMilestones.all]).
  final int milestonesReached;

  /// Próximo hito, o `null` si ya se superaron todos.
  final Duration? nextMilestone;

  /// Avance de 0 a 1 entre el hito anterior y el siguiente (para el anillo).
  final double milestoneFraction;

  /// Si la racha actual es también la mejor.
  bool get isPersonalBest => streak >= longest && streak > Duration.zero;

  /// Beneficios de [preset] ya alcanzados con la racha actual.
  List<QuitBenefit> reachedBenefits(QuitPreset preset) =>
      preset.benefits.where((QuitBenefit b) => streak >= b.after).toList();

  /// Próximo beneficio de [preset] por alcanzar, o `null`.
  QuitBenefit? nextBenefit(QuitPreset preset) {
    for (final QuitBenefit b in preset.benefits) {
      if (streak < b.after) return b;
    }
    return null;
  }
}

/// Partes de una duración para mostrarla como "12 d 4 h 33 min".
class DurationParts {
  const DurationParts(this.days, this.hours, this.minutes, this.seconds);

  factory DurationParts.of(Duration d) {
    final int total = math.max(0, d.inSeconds);
    return DurationParts(
      total ~/ Duration.secondsPerDay,
      (total % Duration.secondsPerDay) ~/ Duration.secondsPerHour,
      (total % Duration.secondsPerHour) ~/ Duration.secondsPerMinute,
      total % Duration.secondsPerMinute,
    );
  }

  final int days;
  final int hours;
  final int minutes;
  final int seconds;
}

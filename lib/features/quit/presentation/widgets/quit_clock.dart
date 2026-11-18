import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/clock/clock.dart';
import '../../../../shared/theme/sc_colors.dart';

/// Repinta su contenido con la hora del `Clock`: cada segundo en color si
/// [seconds] es verdadero (cronómetro grande) o cada minuto; en Modo Papel
/// siempre cada minuto, para no provocar ghosting.
class QuitClockBuilder extends ConsumerStatefulWidget {
  const QuitClockBuilder({super.key, required this.builder, this.seconds = false});

  final Widget Function(BuildContext context, DateTime now) builder;
  final bool seconds;

  @override
  ConsumerState<QuitClockBuilder> createState() => _QuitClockBuilderState();
}

class _QuitClockBuilderState extends ConsumerState<QuitClockBuilder> {
  Timer? _ticker;
  Duration? _period;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Duration period = widget.seconds && !context.sc.isFlat
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);
    if (_period == period) return;
    _period = period;
    _ticker?.cancel();
    _ticker = Timer.periodic(period, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, ref.read(clockProvider).now());
}

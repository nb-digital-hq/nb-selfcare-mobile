import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_icon_controller.dart';

/// Logo de NB SelfCare con el color del ícono que la persona eligió (el mismo
/// que ve en la pantalla de inicio).
class AppLogo extends ConsumerWidget {
  const AppLogo({super.key, this.size = 96, this.iconKey});

  final double size;

  /// Ícono a mostrar; por defecto, el elegido en Ajustes.
  final String? iconKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String key = iconKey ?? ref.watch(appIconProvider);
    final int cache = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Image.asset(
      appIconAsset(key),
      width: size,
      height: size,
      cacheWidth: cache,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'NB SelfCare',
    );
  }
}

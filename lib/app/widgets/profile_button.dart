import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/l10n/l10n.dart';
import '../../features/profile_goals/application/profile_queries.dart';
import '../../shared/theme/sc_colors.dart';
import '../../shared/theme/sc_theme.dart';

/// Acceso al perfil desde la cabecera de cada pestaña.
///
/// El perfil se consulta poco y no merece un sitio fijo en la barra inferior:
/// como en la mayoría de apps de salud, vive en el avatar de arriba a la
/// derecha. Muestra la foto si la hay y, si no, la inicial.
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
    final String? path = profile?.avatarPath;
    final bool hasPhoto = path != null && File(path).existsSync();
    final String name = profile?.name.trim() ?? '';
    final String initial = name.isEmpty ? '' : name.characters.first.toUpperCase();

    return Semantics(
      button: true,
      label: context.l10n.perfilTitle,
      excludeSemantics: true,
      child: Tooltip(
        message: context.l10n.perfilTitle,
        child: InkResponse(
          radius: 26,
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push<void>('/perfil'));
          },
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.isFlat ? Colors.transparent : c.bg3,
              shape: BoxShape.circle,
              border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
              image: hasPhoto
                  ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover)
                  : null,
            ),
            child: hasPhoto
                ? null
                : Text(
                    initial,
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Acciones de cabecera de una pestaña principal: las propias de la pestaña y,
/// siempre al final, el acceso al perfil.
class TabHeaderActions extends StatelessWidget {
  const TabHeaderActions({super.key, this.actions = const <Widget>[]});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final Widget a in actions) ...<Widget>[a, const SizedBox(width: 8)],
        const ProfileButton(),
      ],
    );
  }
}

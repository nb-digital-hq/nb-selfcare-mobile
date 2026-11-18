import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/theme/theme_l10n.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/top_bar.dart';
import '../application/app_icon_controller.dart';
import 'widgets/app_logo.dart';

/// Ajustes › Ícono de la app: el logo en el color de cada tema. Al tocar uno
/// se aplica de verdad al lanzador (al salir de la app) y se recuerda.
class AppIconScreen extends ConsumerWidget {
  const AppIconScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final String active = ref.watch(appIconProvider);
    final List<String> keys = availableAppIcons();
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= 900 ? 6 : (width >= 600 ? 5 : 3);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: TopBar(
                title: l10n.appIconTitle,
                subtitle: l10n.appIconSubtitle,
                leading: BackButton(color: c.text),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                ScSpace.gutter * context.uiScale,
                ScSpace.s,
                ScSpace.gutter * context.uiScale,
                ScSpace.xl,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: ScSpace.m,
                  crossAxisSpacing: ScSpace.m,
                  childAspectRatio: 0.78,
                ),
                itemCount: keys.length,
                itemBuilder: (BuildContext context, int i) {
                  final String key = keys[i];
                  final String label = key.isEmpty
                      ? l10n.appIconDefault
                      : themeName(l10n, scThemeByKey(key));
                  return _IconCell(
                    iconKey: key,
                    label: label,
                    selected: key == active,
                    onTap: () async {
                      unawaited(HapticFeedback.selectionClick());
                      await ref.read(appIconProvider.notifier).select(key);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(l10n.appIconSaved(label))));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.iconKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String iconKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color mark = c.isFlat ? c.text : c.accent;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
        child: Column(
          children: <Widget>[
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? mark : Colors.transparent,
                          width: c.isFlat ? 1.5 : 2.5,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints box) =>
                            AppLogo(size: box.maxWidth, iconKey: iconKey),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: mark,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.bg, width: 2),
                          ),
                          child: Icon(AppIcons.check, color: c.isFlat ? c.bg : c.ink, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ScSpace.xs),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.type.caption.copyWith(
                color: selected ? mark : c.text2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

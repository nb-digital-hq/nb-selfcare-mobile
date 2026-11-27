import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/pressable.dart';

/// Formas de registrar comida: búsqueda, código de barras y accesos rápidos.
class ComerEntryHub extends StatelessWidget {
  const ComerEntryHub({
    super.key,
    required this.onOpenSearch,
    required this.onOpenBarcode,
    required this.onOpenTextEntry,
    required this.onOpenCombos,
    required this.onOpenRecipes,
    required this.onOpenCustomFood,
    required this.onOpenSmartMenu,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenBarcode;
  final VoidCallback onOpenTextEntry;
  final VoidCallback onOpenCombos;
  final VoidCallback onOpenRecipes;
  final VoidCallback onOpenCustomFood;
  final VoidCallback onOpenSmartMenu;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    // Los atajos van en una sola fila de iconos con su nombre: registrar es lo
    // frecuente, y el balance del día debe verse sin desplazarse.
    final List<_Atajo> atajos = <_Atajo>[
      _Atajo(AppIcons.textEntry, l10n.comerWriteMeal, onOpenTextEntry),
      _Atajo(AppIcons.combos, l10n.comerCombos, onOpenCombos),
      _Atajo(Icons.soup_kitchen_rounded, l10n.comerRecipes, onOpenRecipes),
      _Atajo(AppIcons.add, l10n.comerCreateFood, onOpenCustomFood),
      _Atajo(AppIcons.chispa, l10n.comerSmartMenu, onOpenSmartMenu),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.gutter, ScSpace.xs, ScSpace.gutter, ScSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SearchField(onTap: onOpenSearch, onScan: onOpenBarcode),
          const SizedBox(height: ScSpace.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final _Atajo a in atajos) Expanded(child: _AtajoBoton(atajo: a)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Atajo {
  const _Atajo(this.icono, this.titulo, this.accion);

  final IconData icono;
  final String titulo;
  final VoidCallback accion;
}

class _AtajoBoton extends StatelessWidget {
  const _AtajoBoton({required this.atajo});

  final _Atajo atajo;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Semantics(
      button: true,
      label: atajo.titulo,
      excludeSemantics: true,
      child: InkWell(
        onTap: atajo.accion,
        borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ScSpace.s, horizontal: 2),
          child: Column(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.isFlat ? c.bg : c.bg2,
                  shape: BoxShape.circle,
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Icon(atajo.icono, size: 22, color: c.isFlat ? c.text : c.accent),
              ),
              const SizedBox(height: ScSpace.s - 2),
              Text(
                atajo.titulo,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: context.type.caption.copyWith(
                  color: c.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Buscador protagonista con el escáner integrado a la derecha.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap, required this.onScan});

  final VoidCallback onTap;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final String label = context.l10n.comerSearchHint;
    return Pressable(
      scale: 0.985,
      child: Material(
        color: c.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
          side: BorderSide(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.only(left: ScSpace.l),
                    child: Row(
                      children: <Widget>[
                        Icon(AppIcons.search, size: 22, color: c.isFlat ? c.text : c.accent),
                        const SizedBox(width: ScSpace.m),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.text2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(width: c.isFlat ? 1.5 : 1, height: 28, color: c.isFlat ? c.line2 : c.line),
            IconButton(
              tooltip: context.l10n.comerScanBarcode,
              onPressed: onScan,
              style: IconButton.styleFrom(fixedSize: const Size(56, 56)),
              icon: Icon(AppIcons.barcode, color: c.isFlat ? c.text : c.accent),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:intl/intl.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/section_head.dart';
import '../../../application/enlace_pc.dart';

/// Conexión con NB SelfCare de escritorio: vincular con QR, estado y sincronización.
class PcLinkSection extends ConsumerWidget {
  const PcLinkSection({super.key});

  String? _mensaje(BuildContext context, String? codigo) => switch (codigo) {
    null => null,
    'INVALID_INPUT' => context.l10n.pcErrorQr,
    'CONSENT_REQUIRED' => context.l10n.pcErrorPermiso,
    _ => context.l10n.pcErrorRed,
  };

  Future<void> _escanear(BuildContext context, WidgetRef ref) async {
    final String? texto = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const _EscanerDeEnlace(), fullscreenDialog: true),
    );
    if (texto == null) return;
    await ref.read(enlacePcProvider.notifier).vincular(texto);
  }

  Future<void> _conCodigo(BuildContext context, WidgetRef ref) async {
    final TextEditingController campo = TextEditingController();
    final String? texto = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.l10n.pcCodigoTitulo),
        content: TextField(
          controller: campo,
          maxLines: 4,
          maxLength: 4096,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(helperText: context.l10n.pcCodigoAyuda),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.pcCancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(campo.text.trim()),
            child: Text(context.l10n.pcCodigoVincular),
          ),
        ],
      ),
    );
    campo.dispose();
    if (texto == null || texto.isEmpty) return;
    await ref.read(enlacePcProvider.notifier).vincular(texto);
  }

  Future<void> _desvincular(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(context.l10n.pcDesvincularConfirmar),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.pcCancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.pcDesvincular),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(enlacePcProvider.notifier).desvincular();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final EstadoEnlacePc e = ref.watch(enlacePcProvider);
    final String? error = _mensaje(context, e.error);
    final TextStyle cuerpo = TextStyle(
      fontFamily: ScFonts.ui,
      fontSize: 12,
      color: c.text2,
      height: 1.35,
    );
    final String estado = e.enRevision > 0
        ? context.l10n.pcEnRevision(e.enRevision)
        : e.pendientes > 0
        ? context.l10n.pcPendientes(e.pendientes)
        : context.l10n.pcAlDia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHead(
          title: context.l10n.pcTitulo,
          subtitle: context.l10n.pcSubtitulo,
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        const SizedBox(height: 8),
        HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!e.vinculado) ...<Widget>[
                Text(context.l10n.pcExplicacion, style: cuerpo),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                    label: Text(
                      context.l10n.pcVincular,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: e.cargando ? null : () => unawaited(_escanear(context, ref)),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: e.cargando ? null : () => unawaited(_conCodigo(context, ref)),
                    child: Text(context.l10n.pcConCodigo),
                  ),
                ),
              ] else ...<Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.computer_rounded, size: 20, color: c.accent),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.pcVinculado,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: c.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  e.ultima == null
                      ? context.l10n.pcNunca
                      : context.l10n.pcUltima(
                          DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag())
                              .add_Hm()
                              .format(e.ultima!),
                        ),
                  style: cuerpo,
                ),
                Text(estado, style: cuerpo),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: e.sincronizando
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded, size: 18),
                        label: Text(
                          e.sincronizando
                              ? context.l10n.pcSincronizando
                              : context.l10n.pcSincronizarAhora,
                        ),
                        onPressed: e.sincronizando
                            ? null
                            : () {
                                unawaited(HapticFeedback.selectionClick());
                                unawaited(ref.read(enlacePcProvider.notifier).sincronizar());
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => unawaited(_desvincular(context, ref)),
                      child: Text(context.l10n.pcDesvincular),
                    ),
                  ],
                ),
              ],
              if (error != null) ...<Widget>[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(error, style: cuerpo.copyWith(color: c.warning)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Lector del QR de vinculación. Solo acepta códigos QR y devuelve su texto.
class _EscanerDeEnlace extends StatefulWidget {
  const _EscanerDeEnlace();
  @override
  State<_EscanerDeEnlace> createState() => _EscanerDeEnlaceState();
}

class _EscanerDeEnlaceState extends State<_EscanerDeEnlace> {
  bool _leido = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.l10n.pcEscanearTitulo),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ReaderWidget(
            codeFormat: Format.qrCode,
            showGallery: false,
            showToggleCamera: false,
            showFlashlight: false,
            cropPercent: 0.7,
            scanDelay: const Duration(milliseconds: 250),
            loading: const ColoredBox(color: Colors.black),
            onScan: (Code code) {
              final String? texto = code.text;
              if (_leido || !code.isValid || texto == null || texto.isEmpty) return;
              _leido = true;
              unawaited(HapticFeedback.mediumImpact());
              Navigator.of(context).pop(texto);
            },
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Text(
              context.l10n.pcEscanearAyuda,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

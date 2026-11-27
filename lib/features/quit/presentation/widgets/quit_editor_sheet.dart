import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/clock/clock.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/date_formats.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../application/quit_service.dart';
import '../../domain/quit_catalog.dart';
import '../quit_l10n.dart';

/// Abre el formulario para crear un contador o, con [tracker], editarlo.
/// Al crear, lleva al detalle del contador nuevo.
Future<void> showQuitEditor(BuildContext context, {QuitTracker? tracker}) async {
  final int? createdId = await mostrarHojaMenu<int>(
    context,
    builder: (BuildContext _) => QuitEditorSheet(tracker: tracker),
  );
  if (createdId != null && context.mounted) unawaited(context.push('/libre/$createdId'));
}

class QuitEditorSheet extends ConsumerStatefulWidget {
  const QuitEditorSheet({super.key, this.tracker});

  final QuitTracker? tracker;

  @override
  ConsumerState<QuitEditorSheet> createState() => _QuitEditorSheetState();
}

class _QuitEditorSheetState extends ConsumerState<QuitEditorSheet> {
  late String _presetKey;
  late DateTime _startedAt;
  late bool _startNow;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  final TextEditingController _units = TextEditingController();
  final TextEditingController _minutes = TextEditingController();
  final TextEditingController _motivation = TextEditingController();
  bool _saving = false;

  bool get _editing => widget.tracker != null;

  @override
  void initState() {
    super.initState();
    final QuitTracker? t = widget.tracker;
    final DateTime now = ref.read(clockProvider).now();
    _presetKey = t?.presetKey ?? QuitPreset.tobacco.key;
    _startedAt = t?.startedAt ?? now;
    _startNow = t == null;
    _name.text = t?.customName ?? '';
    _cost.text = t?.dailyCost == null ? '' : NumberFormats.input(t!.dailyCost!, maxDigits: 2);
    _units.text = t?.dailyUnits == null ? '' : NumberFormats.input(t!.dailyUnits!);
    _minutes.text = t?.dailyMinutes == null ? '' : '${t!.dailyMinutes}';
    _motivation.text = t?.motivation ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _units.dispose();
    _minutes.dispose();
    _motivation.dispose();
    super.dispose();
  }

  static double? _parse(String raw) =>
      double.tryParse(raw.trim().replaceAll('.', '').replaceAll(',', '.'));

  static double? _parseDecimal(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  QuitPreset get _preset => QuitPreset.byKey(_presetKey);

  bool get _canSave =>
      !_saving && (_presetKey != QuitPreset.customKey || _name.text.trim().isNotEmpty);

  Future<void> _pickStart() async {
    final DateTime now = ref.read(clockProvider).now();
    final DateTime? date = await showDatePicker(
      context: context,
      confirmText: context.l10n.commonAccept,
      initialDate: _startedAt.isAfter(now) ? now : _startedAt,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      confirmText: context.l10n.commonAccept,
      errorInvalidText: context.l10n.commonInvalidTime,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (time == null || !mounted) return;
    final DateTime picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _startedAt = picked.isAfter(now) ? now : picked;
      _startNow = false;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    unawaited(HapticFeedback.mediumImpact());
    final QuitService service = ref.read(quitServiceProvider);
    final QuitMeasure measure = _preset.measure;
    final QuitDraft draft = QuitDraft(
      presetKey: _presetKey,
      customName: _name.text,
      startedAt: _startNow ? ref.read(clockProvider).now() : _startedAt,
      dailyCost: _parse(_cost.text),
      dailyUnits: measure == QuitMeasure.units ? _parseDecimal(_units.text) : null,
      dailyMinutes: measure == QuitMeasure.time ? int.tryParse(_minutes.text.trim()) : null,
      motivation: _motivation.text,
    );
    final QuitTracker? t = widget.tracker;
    if (t != null) {
      await service.update(t, draft);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final int? id = await service.add(draft);
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final QuitPreset preset = _preset;
    final String startLabel = _startNow
        ? l10n.quitStartNow
        : '${DateFormats.shortDate(_startedAt, l10n.localeName)} '
              '${DateFormats.time(_startedAt, l10n.localeName)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.gutter, 0, ScSpace.gutter, ScSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(_editing ? l10n.quitEditTitle : l10n.quitNewTitle, style: context.text.titleLarge),
          const SizedBox(height: ScSpace.xs),
          Text(l10n.quitNewBody, style: context.type.caption),
          const SizedBox(height: ScSpace.l),
          if (!_editing) ...<Widget>[
            Text(l10n.quitWhat, style: context.text.labelLarge),
            const SizedBox(height: ScSpace.s),
            Wrap(
              spacing: ScSpace.s,
              runSpacing: ScSpace.s,
              children: <Widget>[
                for (final QuitPreset p in QuitPreset.all)
                  ChoiceChip(
                    avatar: Icon(QuitText.icon(p.key), size: 18),
                    label: Text(QuitText.preset(l10n, p.key)),
                    selected: p.key == _presetKey,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _presetKey = p.key),
                  ),
              ],
            ),
            const SizedBox(height: ScSpace.l),
          ],
          if (preset.key == QuitPreset.customKey) ...<Widget>[
            TextField(
              controller: _name,
              maxLength: QuitService.maxNameLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.quitCustomName,
                hintText: l10n.quitCustomNameHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ScSpace.s),
          ],
          if (preset.medicalNote) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(ScSpace.m),
              decoration: BoxDecoration(
                color: c.isFlat ? c.bg3 : c.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(ScRadius.controlOf(c)),
                border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.health_and_safety_outlined, color: c.isFlat ? c.text : c.warning),
                  const SizedBox(width: ScSpace.s),
                  Expanded(child: Text(l10n.quitAlcoholSafety, style: context.text.bodySmall)),
                ],
              ),
            ),
            const SizedBox(height: ScSpace.m),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available_outlined),
            title: Text(l10n.quitSince),
            subtitle: Text(startLabel),
            trailing: TextButton(onPressed: _pickStart, child: Text(l10n.quitChangeStart)),
          ),
          const SizedBox(height: ScSpace.s),
          if (preset.measure == QuitMeasure.units) ...<Widget>[
            TextField(
              controller: _units,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: QuitText.unitsQuestion(l10n, preset.key),
                prefixIcon: const Icon(Icons.tag_rounded),
              ),
            ),
            const SizedBox(height: ScSpace.m),
          ],
          if (preset.measure == QuitMeasure.time) ...<Widget>[
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.quitMinutesQuestion,
                suffixText: l10n.quitMinutesSuffix,
                prefixIcon: const Icon(Icons.schedule_rounded),
              ),
            ),
            const SizedBox(height: ScSpace.m),
          ],
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.quitCostQuestion,
              helperText: l10n.quitOptional,
              prefixIcon: const Icon(Icons.savings_outlined),
            ),
          ),
          const SizedBox(height: ScSpace.m),
          TextField(
            controller: _motivation,
            maxLength: QuitService.maxTextLength,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.quitWhy,
              hintText: l10n.quitWhyHint,
              prefixIcon: const Icon(Icons.favorite_border_rounded),
            ),
          ),
          const SizedBox(height: ScSpace.l),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: Text(_editing ? l10n.commonSave : l10n.quitStartCounter),
          ),
        ],
      ),
    );
  }
}

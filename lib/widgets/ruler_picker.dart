import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/l10n.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'dialogs.dart';
import 'glass.dart';
import 'rolling_text.dart';
import 'ui_kit.dart';

class RulerPicker extends StatefulWidget {
  const RulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.majorEvery = 10,
    this.label,
    this.height = 86,
    this.axis = Axis.horizontal,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final int majorEvery;
  final String Function(double value)? label;
  final double height;
  final Axis axis;

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  static const _gap = 11.0;
  late final ScrollController _scroll = ScrollController(initialScrollOffset: _offsetOf(widget.value));
  late int _index = _indexOf(widget.value);

  int get _count => ((widget.max - widget.min) / widget.step).round() + 1;

  int _indexOf(double v) => ((v.clamp(widget.min, widget.max) - widget.min) / widget.step).round();

  double _offsetOf(double v) => _indexOf(v) * _gap;

  double _valueAt(int i) {
    final raw = widget.min + i * widget.step;
    return (raw * 1000).round() / 1000;
  }

  @override
  void didUpdateWidget(RulerPicker old) {
    super.didUpdateWidget(old);
    final wanted = _indexOf(widget.value);
    if (wanted != _index && _scroll.hasClients && !_scroll.position.isScrollingNotifier.value) {
      _index = wanted;
      _quiet = true;
      _scroll
          .animateTo(wanted * _gap, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic)
          .whenComplete(() => _quiet = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _quiet = false;

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) _quiet = false;
    if (_quiet) return false;
    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      final i = (_scroll.offset / _gap).round().clamp(0, _count - 1);
      if (i != _index) {
        _index = i;
        HapticFeedback.selectionClick();
        widget.onChanged(_valueAt(i));
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final vertical = widget.axis == Axis.vertical;
    return LayoutBuilder(builder: (context, box) {
      final side = (vertical ? widget.height : box.maxWidth) / 2 - _gap / 2;
      return Ltr(child: SizedBox(
        height: widget.height,
        child: Stack(
          alignment: vertical ? Alignment.centerRight : Alignment.topCenter,
          children: [
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => LinearGradient(
                begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
                end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
                colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
                stops: const [0, 0.18, 0.82, 1],
              ).createShader(r),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ListView.builder(
                  controller: _scroll,
                  scrollDirection: widget.axis,
                  reverse: vertical,
                  physics: const _SnapPhysics(_gap),
                  padding: vertical ? EdgeInsets.symmetric(vertical: side) : EdgeInsets.symmetric(horizontal: side),
                  itemExtent: _gap,
                  itemCount: _count,
                  itemBuilder: (context, i) {
                    final major = i % widget.majorEvery == 0;
                    final half = !major && widget.majorEvery % 2 == 0 && i % (widget.majorEvery ~/ 2) == 0;
                    return _Tick(
                      major: major,
                      half: half,
                      vertical: vertical,
                      label: major ? (widget.label ?? _plain)(_valueAt(i)) : null,
                      color: gc.textTertiary,
                      labelColor: gc.textSecondary,
                    );
                  },
                ),
              ),
            ),
            IgnorePointer(
              child: Container(
                width: vertical ? 44 : 3,
                height: vertical ? 3 : 44,
                decoration: BoxDecoration(color: gc.accent, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ],
        ),
      ));
    });
  }

  static String _plain(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
}

class _Tick extends StatelessWidget {
  const _Tick({
    required this.major,
    required this.half,
    required this.label,
    required this.color,
    required this.labelColor,
    this.vertical = false,
  });

  final bool major;
  final bool half;
  final String? label;
  final Color color;
  final Color labelColor;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return OverflowBox(
        maxHeight: 40,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (label != null) ...[
              Text(label!, maxLines: 1, style: AppTheme.f(12, weight: FontWeight.w700, color: labelColor)),
              const SizedBox(width: 10),
            ],
            Container(
              width: major ? 34 : (half ? 24 : 16),
              height: major ? 2 : 1.4,
              decoration: BoxDecoration(
                color: major ? labelColor : color.withValues(alpha: half ? 0.9 : 0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      );
    }
    return OverflowBox(
      maxWidth: 60,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: major ? 2 : 1.4,
            height: major ? 34 : (half ? 24 : 16),
            decoration: BoxDecoration(
              color: major ? labelColor : color.withValues(alpha: half ? 0.9 : 0.6),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 10),
            Text(label!, maxLines: 1, style: AppTheme.f(12, weight: FontWeight.w700, color: labelColor)),
          ],
        ],
      ),
    );
  }
}

class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics(this.extent, {super.parent});

  final double extent;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) => _SnapPhysics(extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);
    final base = super.createBallisticSimulation(position, velocity);
    var target = position.pixels;
    if (base != null) target = base.x(double.infinity);
    target = ((target / extent).round() * extent).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < tolerance.distance && velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      SpringDescription.withDampingRatio(mass: 0.6, stiffness: 180, ratio: 1),
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

const rulerCleared = double.nan;

/// Number entry sheet. In Minimal view it opens on the keyboard and the small
/// icon in the corner swaps to the scroller (and back); the last choice is
/// remembered. Everywhere else it opens on the scroller as before, and the
/// keyboard icon opens the typing box.
Future<double?> askRuler(
  BuildContext context, {
  required String title,
  required double value,
  required double min,
  required double max,
  required double step,
  String unit = '',
  int majorEvery = 10,
  String Function(double value)? format,
  String Function(double value)? tickLabel,
  bool vertical = false,
  String? hint,
  String? clearLabel,
}) async {
  var current = value.clamp(min, max).toDouble();
  final decimals = step == step.roundToDouble() ? 0 : (step < 0.1 || step * 10 != (step * 10).roundToDouble() ? 2 : 1);
  final decimalOk = step != step.roundToDouble();
  final minimal = fit.minimalMode;
  var keyboard = minimal && fit.numberEntryKeyboard;
  final controller = TextEditingController();

  String show(double v) {
    if (format != null) return format(v);
    final exact = (v * 100).round() / 100;
    final onGrid = ((exact / step).round() * step - exact).abs() < 0.001;
    if (onGrid) return decimalText(exact.toStringAsFixed(decimals));
    var text = exact.toStringAsFixed(2);
    if (text.endsWith('0')) text = text.substring(0, text.length - 1);
    return decimalText(text);
  }

  // The plain number, without the ruler's fixed decimals ("20", not "20.0").
  String plain(double v) {
    var text = ((v * 100).round() / 100).toString();
    if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
    return decimalText(text);
  }

  double? parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));
  double fit2(double v) => (v.clamp(min, max) * 100).round() / 100;

  void fill() {
    final text = plain(current);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
  }

  double result() => keyboard ? fit2(parse(controller.text) ?? current) : current;

  if (keyboard) fill();

  final picked = await showAppSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) {
        final gc = sheet.gc;
        final reading = Ltr(child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            RollingText(show(current), style: AppTheme.f(54, weight: FontWeight.w800, color: gc.text, height: 1.1)),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(unit, style: AppTheme.f(18, weight: FontWeight.w700, color: gc.textSecondary)),
            ],
          ],
        ));
        final typedField = Ltr(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 190,
                child: TextField(
                  key: const ValueKey('number-entry-field'),
                  controller: controller,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(decimal: decimalOk, signed: min < 0),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(min < 0 ? r'[0-9.,\-]' : r'[0-9.,]'))],
                  cursorColor: gc.accent,
                  style: AppTheme.f(50, weight: FontWeight.w800, color: gc.text, height: 1.1),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.only(bottom: 4),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: gc.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: gc.accent, width: 1.5)),
                  ),
                  onChanged: (text) {
                    final v = parse(text);
                    if (v != null) setSheet(() => current = fit2(v));
                  },
                  onSubmitted: (_) => Navigator.of(sheet).pop(result()),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(unit, style: AppTheme.f(18, weight: FontWeight.w700, color: gc.textSecondary)),
              ],
            ],
          ),
          if (format != null) ...[
            const SizedBox(height: 8),
            Text('= ${format(current)}', style: AppTheme.f(15, weight: FontWeight.w600, color: gc.textSecondary)),
          ],
        ]));
        final ruler = RulerPicker(
          value: current,
          min: min,
          max: max,
          step: step,
          majorEvery: majorEvery,
          label: tickLabel,
          axis: vertical ? Axis.vertical : Axis.horizontal,
          height: vertical ? 300 : 86,
          onChanged: (v) => setSheet(() => current = v),
        );
        final swapIcon = minimal && keyboard ? PhosphorIconsRegular.ruler : PhosphorIconsRegular.keyboard;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard ? MediaQuery.viewInsetsOf(sheet).bottom : 0),
          child: Container(
            padding: sheetPad(sheet),
            decoration: sheetDecoration(gc),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Text(titleCase(title),
                        style: AppTheme.f(15, weight: FontWeight.w700, color: gc.textSecondary)),
                  ),
                  Semantics(
                    button: true,
                    label: title,
                    child: GestureDetector(
                      key: const ValueKey('number-entry-swap'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        if (minimal) {
                          if (keyboard) {
                            final v = parse(controller.text);
                            if (v != null) current = fit2(v);
                          }
                          keyboard = !keyboard;
                          if (keyboard) fill();
                          fit.setNumberEntryKeyboard(keyboard);
                          setSheet(() {});
                          return;
                        }
                        final typed = await askNumber(sheet,
                            title: title, initial: show(current), decimal: decimalOk);
                        if (typed == null) return;
                        setSheet(() => current = (typed.clamp(min, max) * 100).round() / 100);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(swapIcon, size: 20, color: gc.textSecondary),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                if (keyboard)
                  Center(child: typedField)
                else if (vertical)
                  Row(children: [
                    Expanded(child: Center(child: reading)),
                    SizedBox(width: 130, child: ruler),
                  ])
                else ...[
                  Center(child: reading),
                  const SizedBox(height: 18),
                  ruler,
                ],
                if (hint != null) ...[
                  const SizedBox(height: 14),
                  Text(hint,
                      textAlign: TextAlign.center,
                      style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textTertiary, height: 1.4)),
                ],
                const SizedBox(height: 18),
                PrimaryButton(label: t.set, onTap: () => Navigator.of(sheet).pop(result())),
                if (clearLabel != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(sheet).pop(rulerCleared),
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(clearLabel,
                            style: AppTheme.f(14, weight: FontWeight.w600, color: gc.textSecondary)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
  Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
  return picked;
}

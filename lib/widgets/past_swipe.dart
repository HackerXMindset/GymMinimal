import 'package:flutter/material.dart';

/// Lets a card that shows one stretch of time (a week, eight weeks) be moved
/// into the past. Drag right to see the stretch before, drag left to come back.
/// [limit] is how many steps back there is anything to see, and [builder] draws
/// the card for the step it is given. [go] moves by a number of steps, for
/// arrows in the card's own heading.
class PastSwipe extends StatefulWidget {
  const PastSwipe({super.key, required this.limit, required this.builder});

  final int limit;
  final Widget Function(BuildContext context, int back, void Function(int delta) go) builder;

  @override
  State<PastSwipe> createState() => _PastSwipeState();
}

class _PastSwipeState extends State<PastSwipe> {
  int _back = 0;
  int _dir = 1;
  double _drag = 0;

  void _go(int delta) {
    final next = (_back + delta).clamp(0, widget.limit);
    if (next == _back) return;
    setState(() {
      _dir = delta > 0 ? 1 : -1;
      _back = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final back = _back.clamp(0, widget.limit);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _drag = 0,
      onHorizontalDragUpdate: (d) => _drag += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (_drag > 36 || v > 400) {
          _go(1);
        } else if (_drag < -36 || v < -400) {
          _go(-1);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: Offset(0.05 * _dir, 0), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(back), child: widget.builder(context, back, _go)),
      ),
    );
  }
}

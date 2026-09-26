/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// The shared Harmony card entrance used by Home rows, Search results and
/// styled destination lists.
///
/// A card enters with a subtle translation and fade from [beginOffset]
/// (from the LEFT by default; carousels whose cards enter from above pass
/// `Offset(0, -0.12)`) with an easeOutCubic curve the first time it becomes
/// visible in the viewport. While it stays visible it remains revealed; once
/// it leaves the viewport completely the animation resets, so scrolling it
/// back into view plays the entrance again. The check runs only on
/// scroll-driven visibility transitions, never per frame.
class HarmonyReveal extends StatefulWidget {
  const HarmonyReveal({
    required this.child,
    this.beginOffset = const Offset(-0.08, 0),
    super.key,
  });

  final Widget child;

  /// Entrance origin relative to the resting position, as a fraction of the
  /// card's size.
  final Offset beginOffset;

  @override
  State<HarmonyReveal> createState() => _HarmonyRevealState();
}

class _HarmonyRevealState extends State<HarmonyReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<Offset> _offsetAnimation = Tween<Offset>(
    begin: widget.beginOffset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  late final Animation<double> _opacityAnimation = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  ScrollableState? _scrollable;
  ScrollPosition? _position;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  void _setup() {
    if (!mounted) return;
    final scrollable = _resolveScrollable();
    if (scrollable == null) {
      _controller.value = 1;
      return;
    }
    _scrollable = scrollable;
    _position = scrollable.position..addListener(_evaluate);
    _evaluate();
  }

  /// The nearest ancestor that actually scrolls. Lists embedded in sliver
  /// pages sometimes sit inside a shrink-wrapped, non-scrolling ListView;
  /// those are skipped so the outer scrollable drives the reveal instead.
  ScrollableState? _resolveScrollable() {
    ScrollableState? resolved;
    context.visitAncestorElements((element) {
      if (element.widget is Scrollable) {
        final state = (element as StatefulElement).state as ScrollableState;
        if (state.position.physics is! NeverScrollableScrollPhysics) {
          resolved = state;
          return false;
        }
      }
      return true;
    });
    return resolved;
  }

  bool _isFullyOutsideViewport() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return true;
    final scrollableBox = _scrollable?.context.findRenderObject();
    if (scrollableBox is! RenderBox || !scrollableBox.attached) return false;
    final topLeft = scrollableBox.globalToLocal(box.localToGlobal(Offset.zero));
    final childRight = topLeft.dx + box.size.width;
    final childBottom = topLeft.dy + box.size.height;
    return childRight < 0 ||
        childBottom < 0 ||
        topLeft.dx > scrollableBox.size.width ||
        topLeft.dy > scrollableBox.size.height;
  }

  void _evaluate() {
    if (!mounted) return;
    if (_isFullyOutsideViewport()) {
      if (_visible || _controller.value != 0) {
        _visible = false;
        _controller
          ..stop()
          ..value = 0;
      }
      return;
    }
    if (!_visible) {
      _visible = true;
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_evaluate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: FractionalTranslation(
            translation: _offsetAnimation.value,
            child: child,
          ),
        );
      },
    );
  }
}

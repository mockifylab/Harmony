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

import 'dart:math' as math show pi;
import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/app_themes.dart';

/// Pull-to-refresh indicator that reuses the Time Machine kitsune mark.
/// It is fully driven by [status] transitions reported by a surrounding
/// `RefreshIndicator.noSpinner` plus the live drag [progress], which the
/// parent maps to the same arming threshold the indicator uses internally,
/// so the badge reaches full size exactly when the pull arms.
class KitsuneRefreshBadge extends StatefulWidget {
  const KitsuneRefreshBadge({
    super.key,
    required this.status,
    required this.progress,
  });

  final RefreshIndicatorStatus? status;
  final double progress;

  @override
  State<KitsuneRefreshBadge> createState() => _KitsuneRefreshBadgeState();
}

class _KitsuneRefreshBadgeState extends State<KitsuneRefreshBadge>
    with TickerProviderStateMixin {
  static const _badgeSize = 44.0;

  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final AnimationController _exitController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(KitsuneRefreshBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == oldWidget.status) return;

    switch (widget.status) {
      case RefreshIndicatorStatus.drag:
      case RefreshIndicatorStatus.armed:
        _spinController.stop();
        _exitController.value = 0;
      case RefreshIndicatorStatus.snap:
      case RefreshIndicatorStatus.refresh:
        _exitController.value = 0;
        _spinController.repeat();
      case RefreshIndicatorStatus.done:
      case RefreshIndicatorStatus.canceled:
        _exitController.forward(from: 0);
      case null:
        _spinController.stop();
        _exitController.value = 0;
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_spinController, _exitController]),
      builder: (context, _) {
        final status = widget.status;
        final colorScheme = Theme.of(context).colorScheme;
        final progress = status == RefreshIndicatorStatus.drag
            ? widget.progress.clamp(0.0, 1.0)
            : 0.0;
        final exit = _exitController.value;

        final opacity = switch (status) {
          null => 0.0,
          RefreshIndicatorStatus.drag => progress,
          RefreshIndicatorStatus.done ||
          RefreshIndicatorStatus.canceled => 1 - exit,
          _ => 1.0,
        };
        final scale = switch (status) {
          null => 0.0,
          RefreshIndicatorStatus.drag => 0.65 + 0.35 * progress,
          RefreshIndicatorStatus.done ||
          RefreshIndicatorStatus.canceled => 1 - 0.2 * exit,
          _ => 1.0,
        };
        if (opacity <= 0) return const SizedBox.shrink();

        final angle = switch (status) {
          RefreshIndicatorStatus.drag => lerpDouble(-0.55, 0, progress)!,
          RefreshIndicatorStatus.armed => 0.0,
          _ => 2 * math.pi * _spinController.value,
        };

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: _badgeSize,
              height: _badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: getGlassSurfaceColor(colorScheme),
                border: Border.all(color: colorScheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: getGlassShadowColor(colorScheme),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Transform.rotate(
                  angle: angle,
                  child: Image.asset(
                    'assets/icons/harmony_fox_foreground.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

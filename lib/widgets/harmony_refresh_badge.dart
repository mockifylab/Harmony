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

import 'dart:math' as math show pi, sin;
import 'dart:ui' show lerpDouble;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/app_themes.dart';

/// Home pull-to-refresh badge: an accent refresh glyph inside the same
/// circular glass shell as the profile icon, so both read as one icon
/// language. It is driven by [status] transitions reported by a surrounding
/// `RefreshIndicator.noSpinner` plus the live drag [progress], which the
/// parent maps against the indicator's real activation threshold, so the
/// badge reaches full size only once releasing would actually refresh.
class HarmonyRefreshBadge extends StatefulWidget {
  const HarmonyRefreshBadge({
    super.key,
    required this.status,
    required this.progress,
  });

  /// Diameter of the badge shell, which the parent uses to center it.
  static const size = 38.0;

  final RefreshIndicatorStatus? status;
  final double progress;

  @override
  State<HarmonyRefreshBadge> createState() => _HarmonyRefreshBadgeState();
}

class _HarmonyRefreshBadgeState extends State<HarmonyRefreshBadge>
    with TickerProviderStateMixin {
  static const _badgeSize = HarmonyRefreshBadge.size;
  static const _glyphSize = 18.0;

  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final AnimationController _exitController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// One-shot pop played when the deliberate pull actually activates the
  /// refresh, so the activation is felt without a bounce or a hold.
  late final AnimationController _popController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void didUpdateWidget(HarmonyRefreshBadge oldWidget) {
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
        _popController.forward(from: 0);
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
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _spinController,
        _exitController,
        _popController,
      ]),
      builder: (context, _) {
        final status = widget.status;
        final colorScheme = Theme.of(context).colorScheme;
        // The framework flips to `armed` well before releasing would refresh,
        // so both pull states track the live progress and the badge only
        // fills at the point where the refresh really fires.
        final isPulling =
            status == RefreshIndicatorStatus.drag ||
            status == RefreshIndicatorStatus.armed;
        final progress = isPulling ? widget.progress.clamp(0.0, 1.0) : 0.0;
        final exit = _exitController.value;

        final opacity = switch (status) {
          null => 0.0,
          RefreshIndicatorStatus.drag ||
          RefreshIndicatorStatus.armed => progress,
          RefreshIndicatorStatus.done ||
          RefreshIndicatorStatus.canceled => 1 - exit,
          _ => 1.0,
        };
        final scale = switch (status) {
          null => 0.0,
          RefreshIndicatorStatus.drag ||
          RefreshIndicatorStatus.armed => 0.65 + 0.35 * progress,
          RefreshIndicatorStatus.done ||
          RefreshIndicatorStatus.canceled => 1 - 0.2 * exit,
          _ => 1.0,
        };
        if (opacity <= 0) return const SizedBox.shrink();

        final pop = 1 + 0.16 * math.sin(math.pi * _popController.value);

        final angle = switch (status) {
          RefreshIndicatorStatus.drag ||
          RefreshIndicatorStatus.armed => lerpDouble(-0.55, 0, progress)!,
          _ => 2 * math.pi * _spinController.value,
        };

        return Transform.scale(
          scale: scale * pop,
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
              child: Center(
                child: Transform.rotate(
                  angle: angle,
                  child: Icon(
                    FluentIcons.arrow_sync_24_regular,
                    size: _glyphSize,
                    color: colorScheme.primary,
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

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

import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

/// Visual state of a download affordance, shared by every download button in
/// the app so they all animate the same way.
enum DownloadButtonState { idle, downloading, completed }

/// The one download button used across the app. It renders a fixed-footprint
/// [IconButton] that cross-fades between the idle arrow, an animated download
/// ring and the completed state, so switching states never shifts layout.
class DownloadIconButton extends StatelessWidget {
  const DownloadIconButton({
    super.key,
    required this.state,
    this.onPressed,
    this.progress,
    this.size = 24,
    this.idleIcon = FluentIcons.arrow_download_24_regular,
    this.completedIcon = FluentIcons.checkmark_circle_24_filled,
    this.completedColor,
    this.showCancelGlyph = true,
    this.tooltip,
    this.style,
    this.downloadingStyle,
    this.completedStyle,
    this.activeColor,
  });

  final DownloadButtonState state;

  /// Fired on tap in every state; the caller decides what a tap means per
  /// state. Pass `null` to disable, e.g. while a song download runs, since
  /// single-song downloads cannot be cancelled.
  final VoidCallback? onPressed;

  /// Download progress between 0 and 1. `null` shows an indeterminate ring.
  final double? progress;

  /// Icon and ring diameter.
  final double size;
  final IconData idleIcon;
  final IconData completedIcon;

  /// Explicit color for the completed icon; defaults to the button's
  /// foreground so filled styles keep their contrast.
  final Color? completedColor;

  /// Whether the downloading ring carries a small dismiss glyph, for
  /// downloads that can be cancelled by tapping.
  final bool showCancelGlyph;
  final String? tooltip;

  /// Button chrome per state. Missing styles fall back to [style].
  final ButtonStyle? style;
  final ButtonStyle? downloadingStyle;
  final ButtonStyle? completedStyle;

  /// Ring color while downloading, green by default.
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = this.activeColor ?? colorScheme.primary;

    final resolvedStyle = switch (state) {
      DownloadButtonState.idle => style,
      DownloadButtonState.downloading => downloadingStyle ?? style,
      DownloadButtonState.completed => completedStyle ?? style,
    };

    final content = switch (state) {
      DownloadButtonState.idle => Icon(idleIcon),
      DownloadButtonState.downloading => DownloadRing(
        size: size,
        progress: progress,
        color: activeColor,
        glyph: showCancelGlyph ? FluentIcons.dismiss_24_regular : null,
      ),
      DownloadButtonState.completed => Icon(
        completedIcon,
        color: completedColor,
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: IconButton(
        key: ValueKey(state),
        icon: content,
        iconSize: size,
        tooltip: tooltip,
        style: resolvedStyle,
        onPressed: onPressed,
      ),
    );
  }
}

/// Circular download indicator. Determinate when [progress] is set, otherwise
/// a spinning arc. Used inside [DownloadIconButton] and wherever a bare
/// indicator is needed, like the song bar artwork overlay.
class DownloadRing extends StatefulWidget {
  const DownloadRing({
    super.key,
    this.size = 24,
    this.progress,
    this.color,
    this.trackColor,
    this.glyph,
    this.glyphColor,
    this.strokeWidth,
  });

  final double size;
  final double? progress;
  final Color? color;
  final Color? trackColor;
  final IconData? glyph;
  final Color? glyphColor;
  final double? strokeWidth;

  @override
  State<DownloadRing> createState() => _DownloadRingState();
}

class _DownloadRingState extends State<DownloadRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = widget.color ?? colorScheme.primary;
    final trackColor = widget.trackColor ?? color.withValues(alpha: 0.18);
    final strokeWidth = widget.strokeWidth ?? math.max(2, widget.size * 0.09);

    final Widget ring;
    if (widget.progress != null) {
      ring = TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: 0,
          end: widget.progress!.clamp(0.0, 1.0),
        ),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (_, value, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _RingPainter(
            color: color,
            trackColor: trackColor,
            strokeWidth: strokeWidth,
            startAngle: -math.pi / 2,
            sweep: 2 * math.pi * value,
          ),
        ),
      );
    } else {
      ring = AnimatedBuilder(
        animation: _rotation,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _RingPainter(
            color: color,
            trackColor: trackColor,
            strokeWidth: strokeWidth,
            startAngle: _rotation.value * 2 * math.pi,
            sweep: 1.9,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring,
          if (widget.glyph != null)
            Icon(
              widget.glyph,
              size: widget.size * 0.42,
              color: widget.glyphColor ?? colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.startAngle,
    required this.sweep,
  });

  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double startAngle;
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = trackColor,
    );

    if (sweep < 0.01) return;

    final arcRect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    canvas.drawArc(
      arcRect,
      startAngle,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.startAngle != startAngle ||
      oldDelegate.sweep != sweep;
}

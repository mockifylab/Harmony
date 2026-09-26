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
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/artwork_provider.dart';

final Map<String, Color?> _colorCache = {};
final Map<String, Future<Color?>> _inFlight = {};

/// Dominant color of an artwork image, or null when the image cannot be
/// decoded or holds no usable color. Results are cached per artwork URL, so
/// callers may resolve on every rebuild.
Future<Color?> resolveArtworkColor(String? artwork) {
  if (artwork == null || artwork.isEmpty) return Future.value(null);

  if (_colorCache.containsKey(artwork)) {
    return Future.value(_colorCache[artwork]);
  }

  final pending = _inFlight[artwork];
  if (pending != null) return pending;

  final future = _extractArtworkColor(artwork)
      .then<Color?>((color) {
        _colorCache[artwork] = color;
        return color;
      })
      .catchError((Object _) {
        _colorCache[artwork] = null;
        return null;
      })
      .whenComplete(() => _inFlight.remove(artwork));

  _inFlight[artwork] = future;
  return future;
}

Future<Color?> _extractArtworkColor(String artwork) async {
  final completer = Completer<ui.Image>();
  final stream = ArtworkProvider.get(artwork).resolve(ImageConfiguration.empty);

  final listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image);
    },
    onError: (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);

  try {
    return await _dominantColorOf(await completer.future);
  } finally {
    stream.removeListener(listener);
  }
}

/// Picks the artwork's dominant hue, weighting saturated pixels above the
/// washed-out ones that would otherwise drag every cover towards grey.
Future<Color?> _dominantColorOf(ui.Image image) async {
  final width = image.width;
  final height = image.height;
  if (width <= 0 || height <= 0) return null;

  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return null;
  final pixels = byteData.buffer.asUint8List();

  // A bounded sample grid keeps the cost flat no matter how large the cover is.
  const targetSamples = 24;
  final xStep = (width / targetSamples).ceil().clamp(1, width);
  final yStep = (height / targetSamples).ceil().clamp(1, height);

  const buckets = 12;
  final hueWeight = List<double>.filled(buckets, 0);
  final hueSumR = List<double>.filled(buckets, 0);
  final hueSumG = List<double>.filled(buckets, 0);
  final hueSumB = List<double>.filled(buckets, 0);
  var greySumR = 0.0;
  var greySumG = 0.0;
  var greySumB = 0.0;
  var greyCount = 0;

  for (var y = yStep ~/ 2; y < height; y += yStep) {
    for (var x = xStep ~/ 2; x < width; x += xStep) {
      final offset = (y * width + x) * 4;
      if (pixels[offset + 3] < 200) continue;

      final r = pixels[offset].toDouble();
      final g = pixels[offset + 1].toDouble();
      final b = pixels[offset + 2].toDouble();
      final hsv = HSVColor.fromColor(
        Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt()),
      );

      final isNearBlack = hsv.value < 0.12;
      final isWashedOut = hsv.saturation < 0.18;
      if (isNearBlack || (isWashedOut && hsv.value > 0.95)) continue;

      if (isWashedOut) {
        greySumR += r;
        greySumG += g;
        greySumB += b;
        greyCount++;
        continue;
      }

      final index = (hsv.hue / (360 / buckets)).floor().clamp(0, buckets - 1);
      hueWeight[index] += hsv.saturation * hsv.value;
      hueSumR[index] += r;
      hueSumG[index] += g;
      hueSumB[index] += b;
    }
  }

  var bestIndex = -1;
  var bestWeight = 0.0;
  for (var i = 0; i < buckets; i++) {
    if (hueWeight[i] > bestWeight) {
      bestWeight = hueWeight[i];
      bestIndex = i;
    }
  }

  if (bestIndex >= 0) {
    final weight = hueWeight[bestIndex];
    return Color.fromARGB(
      255,
      (hueSumR[bestIndex] / weight).round().clamp(0, 255),
      (hueSumG[bestIndex] / weight).round().clamp(0, 255),
      (hueSumB[bestIndex] / weight).round().clamp(0, 255),
    );
  }

  if (greyCount > 0) {
    return Color.fromARGB(
      255,
      (greySumR / greyCount).round().clamp(0, 255),
      (greySumG / greyCount).round().clamp(0, 255),
      (greySumB / greyCount).round().clamp(0, 255),
    );
  }

  return null;
}

/// Background gradient of the full player: the artwork color toned towards the
/// theme surface, so controls stay readable in either brightness.
List<Color> artworkBackdropColors(ColorScheme colorScheme, Color? artworkColor) {
  final surface = colorScheme.surface;
  final isDark = colorScheme.brightness == Brightness.dark;
  final hsv = HSVColor.fromColor(artworkColor ?? colorScheme.tertiary);

  final toned = isDark
      // Dark and saturated: a moody wash over the near-black surface.
      ? hsv
            .withSaturation(hsv.saturation.clamp(0.35, 0.90))
            .withValue(hsv.value.clamp(0.22, 0.42))
            .toColor()
      // Light and pastel: the cream surface keeps the dark ink readable.
      : hsv
            .withSaturation(hsv.saturation.clamp(0.20, 0.70))
            .withValue(hsv.value.clamp(0.72, 0.90))
            .toColor();

  return [
    Color.alphaBlend(toned.withValues(alpha: isDark ? 0.62 : 0.55), surface),
    Color.alphaBlend(toned.withValues(alpha: isDark ? 0.20 : 0.18), surface),
    surface,
  ];
}

/// Restrained artwork tint for the mini player, blended into the glass surface
/// at a low enough strength that the title and controls keep their contrast.
Color miniPlayerSurfaceColor(ColorScheme colorScheme, Color? artworkColor) {
  final glass = getGlassSurfaceColor(colorScheme);
  if (artworkColor == null) return glass;

  final isDark = colorScheme.brightness == Brightness.dark;
  final hsv = HSVColor.fromColor(artworkColor);
  final toned = hsv
      .withSaturation(hsv.saturation.clamp(0.0, 0.75))
      .withValue(
        isDark ? hsv.value.clamp(0.20, 0.45) : hsv.value.clamp(0.78, 0.94),
      )
      .toColor();

  return Color.alphaBlend(toned.withValues(alpha: isDark ? 0.22 : 0.28), glass);
}

/// Companion border tint for [miniPlayerSurfaceColor].
Color miniPlayerBorderColor(ColorScheme colorScheme, Color? artworkColor) {
  final base = getGlassBorderColor(colorScheme);
  if (artworkColor == null) return base;

  return Color.alphaBlend(
    artworkColor.withValues(
      alpha: colorScheme.brightness == Brightness.dark ? 0.18 : 0.22,
    ),
    base,
  );
}

/// Rebuilds [builder] with the dominant color of [artwork], resolving it again
/// whenever the artwork changes.
class ArtworkColorBuilder extends StatefulWidget {
  const ArtworkColorBuilder({
    super.key,
    required this.artwork,
    required this.builder,
  });

  final String? artwork;
  final Widget Function(BuildContext context, Color? artworkColor) builder;

  @override
  State<ArtworkColorBuilder> createState() => _ArtworkColorBuilderState();
}

class _ArtworkColorBuilderState extends State<ArtworkColorBuilder> {
  Color? _color;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ArtworkColorBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artwork != widget.artwork) _resolve();
  }

  Future<void> _resolve() async {
    final requested = widget.artwork;
    final color = await resolveArtworkColor(requested);
    // A newer artwork may have been requested while this one decoded.
    if (!mounted || requested != widget.artwork) return;
    if (_color != color) setState(() => _color = color);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _color);
}

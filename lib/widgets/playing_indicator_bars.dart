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

import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart' show audioHandler;

/// The live-playback marker of the current song: three small bars bouncing out
/// of phase while the song plays, resting at equal low height when paused. One
/// ticker drives all three bars, so only a card that is actually playing owns
/// an animation controller. The colour follows the active accent, which is the
/// Harmony green unless the user picked another one.
class PlayingIndicatorBars extends StatefulWidget {
  const PlayingIndicatorBars({required this.isPlaying, super.key});

  final bool isPlaying;

  @override
  State<PlayingIndicatorBars> createState() => _PlayingIndicatorBarsState();
}

class _PlayingIndicatorBarsState extends State<PlayingIndicatorBars>
    with SingleTickerProviderStateMixin {
  static const _maxHeight = 14.0;
  static const _barWidth = 3.0;
  static const _barGap = 2.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  // Phase-shifted curves so the three bars animate at different heights.
  late final List<Animation<double>> _bars = [
    for (var i = 0; i < 3; i++)
      _controller.drive(
        Tween<double>(begin: 0.3, end: 1).chain(
          CurveTween(
            curve: Interval(i * 0.18, 0.55 + i * 0.18, curve: Curves.easeInOut),
          ),
        ),
      ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PlayingIndicatorBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying == oldWidget.isPlaying) return;
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    if (!widget.isPlaying) {
      return _barsRow(color, const [0.42, 0.42, 0.42]);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          _barsRow(color, [for (final bar in _bars) bar.value]),
    );
  }

  Widget _barsRow(Color color, List<double> scales) {
    return SizedBox(
      height: _maxHeight,
      width: _barWidth * 3 + _barGap * 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final scale in scales)
            Container(
              width: _barWidth,
              height: _maxHeight * scale,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(_barWidth / 2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compares a card's stable track id (`ytid`) with the media session's current
/// track and hands [builder] the verdict plus the live playing flag. The
/// identity comes from `MediaItem.extras['ytid']` on the existing media-item
/// stream — no second playback state, and nothing polls: the streams emit only
/// when the session actually changes. A card that is not the current song
/// never subscribes to playback, so only the playing card animates. Give
/// [songId] as `null`/empty to opt a card out of the indicator entirely.
class CurrentSongBuilder extends StatefulWidget {
  const CurrentSongBuilder({
    required this.songId,
    required this.builder,
    super.key,
  });

  final String? songId;
  final Widget Function(
    BuildContext context,
    bool isCurrentSong,
    bool isPlaying,
  )
  builder;

  @override
  State<CurrentSongBuilder> createState() => _CurrentSongBuilderState();
}

class _CurrentSongBuilderState extends State<CurrentSongBuilder> {
  late final Stream<String?> _currentSongIdStream = audioHandler.mediaItem
      .map((item) => item?.extras?['ytid']?.toString())
      .distinct();

  late final Stream<bool> _isPlayingStream = audioHandler.playbackStateStream
      .map((state) => state.playing)
      .distinct();

  @override
  Widget build(BuildContext context) {
    final songId = widget.songId;
    if (songId == null || songId.isEmpty) {
      return widget.builder(context, false, false);
    }

    return StreamBuilder<String?>(
      stream: _currentSongIdStream,
      initialData: _currentSongId(),
      builder: (context, snapshot) {
        if (snapshot.data != songId) {
          return widget.builder(context, false, false);
        }
        return StreamBuilder<bool>(
          stream: _isPlayingStream,
          initialData: _isPlaying(),
          builder: (context, playingSnapshot) =>
              widget.builder(context, true, playingSnapshot.data ?? false),
        );
      },
    );
  }
}

String? _currentSongId() =>
    audioHandler.mediaItem.valueOrNull?.extras?['ytid']?.toString();

bool _isPlaying() => audioHandler.playbackState.valueOrNull?.playing ?? false;

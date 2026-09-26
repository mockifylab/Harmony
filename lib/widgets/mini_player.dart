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
import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/models/full_player_state.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/screens/now_playing_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/theme/artwork_palette.dart';
import 'package:musify/widgets/marquee.dart';
import 'package:musify/widgets/song_artwork.dart';
import 'package:musify/widgets/verified_artist_badge.dart';
import 'package:rxdart/rxdart.dart';

final Stream<FullPlayerState> _fullPlayerStateStream =
    Rx.combineLatest3(
          audioHandler.playbackStateStream,
          audioHandler.queue.distinct(),
          audioHandler.positionDataStream,
          (PlaybackState state, List<MediaItem> queue, PositionData pos) =>
              FullPlayerState(
                playbackState: state,
                queue: queue,
                position: pos,
              ),
        )
        .throttleTime(const Duration(milliseconds: 120), trailing: true)
        .asBroadcastStream();

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static const double playerHeight = 56;
  static const double _borderRadius = 12;
  static const double _artworkSize = 40;
  static const double _artworkRadius = 4;

  static final GlobalKey _pillKey = GlobalKey();

  /// Global bounds of the visible pill, or null while the mini player is
  /// hidden. Floating UI (three-dot menus) reads this instead of guessing a
  /// fixed offset, so nothing can be laid out on top of the pill.
  static Rect? currentBounds() {
    final box = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaSnapshot) {
          final metadata = mediaSnapshot.data;
          if (metadata == null) return const SizedBox.shrink();

          return StreamBuilder<FullPlayerState>(
            stream: _fullPlayerStateStream,
            builder: (context, stateSnapshot) {
              final state = stateSnapshot.data;
              if (state == null) return const SizedBox.shrink();

              return _MiniPlayerBody(
                colorScheme: colorScheme,
                metadata: metadata,
                state: state,
              );
            },
          );
        },
      ),
    );
  }
}

class _MiniPlayerBody extends StatefulWidget {
  const _MiniPlayerBody({
    required this.colorScheme,
    required this.metadata,
    required this.state,
  });

  final ColorScheme colorScheme;
  final MediaItem metadata;
  final FullPlayerState state;

  @override
  State<_MiniPlayerBody> createState() => _MiniPlayerBodyState();
}

class _MiniPlayerBodyState extends State<_MiniPlayerBody>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _revealController;

  /// Width of the strip the mini player slides right by to uncover the close
  /// button sitting behind its leading edge.
  static const double _deleteRevealExtent = 60;
  static const double _deleteButtonSize = 44;
  static const double _deleteButtonInset = 6;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _revealController = AnimationController(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _revealResetTimer?.cancel();
    _animationController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MiniPlayerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new song must never inherit the previous song's swipe-reveal state, so
    // fold the reveal back the moment the media item changes.
    if (oldWidget.metadata.id != widget.metadata.id) {
      _cancelRevealResetTimer();
      if (_revealController.value != 0) _revealController.value = 0;
      _dismissedMediaId = null;
    }
  }

  static const double _dragThresholdForNavigation = 10;

  /// Revealing the close button offsets the pill; the reveal is a gesture
  /// preview, so it folds back on its own shortly after the hand leaves,
  /// never staying stretched.
  Timer? _revealResetTimer;

  void _startRevealResetTimer() {
    _revealResetTimer?.cancel();
    _revealResetTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      if (_revealController.value > 0 && !_revealController.isAnimating) {
        _revealController.reverse();
      }
    });
  }

  void _cancelRevealResetTimer() {
    _revealResetTimer?.cancel();
    _revealResetTimer = null;
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    if ((details.primaryDelta ?? 0) < -_dragThresholdForNavigation) {
      _navigateToNowPlaying();
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta == 0) return;
    _cancelRevealResetTimer();
    _revealController.value =
        (_revealController.value + delta / _deleteRevealExtent).clamp(0.0, 1.0);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 250) {
      _revealController.forward();
      _startRevealResetTimer();
    } else if (velocity < -250) {
      _cancelRevealResetTimer();
      _revealController.reverse();
    } else if (_revealController.value > 0.5) {
      _revealController.forward();
      _startRevealResetTimer();
    } else {
      _cancelRevealResetTimer();
      _revealController.reverse();
    }
  }

  void _handleTap() {
    if (_revealController.value > 0) {
      _cancelRevealResetTimer();
      _revealController.reverse();
      return;
    }
    _navigateToNowPlaying();
  }

  /// The swipe-revealed action stops playback and hides the mini player
  /// without touching the queue, so the current song stays current and can
  /// be resumed later. The dismissal is keyed to this media item; playing
  /// anything else makes the mini player visible again.
  String? _dismissedMediaId;

  void _closePlayer() {
    _cancelRevealResetTimer();
    _revealController.reverse();
    setState(() {
      _dismissedMediaId = widget.metadata.id;
    });
    unawaited(audioHandler.stop());
  }

  void _navigateToNowPlaying() {
    Navigator.of(context).push(_createSlideTransition());
  }

  String? _artworkSource(MediaItem metadata) {
    final artworkPath = metadata.extras?['artWorkPath']?.toString();
    if (artworkPath != null && artworkPath.isNotEmpty) return artworkPath;
    return metadata.artUri?.toString();
  }

  PageRoute<void> _createSlideTransition() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, _) => const NowPlayingPage(),
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.05, 0.7, 0.1, 1.0),
          reverseCurve: const Cubic(0.3, 0.0, 0.8, 0.15),
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final metadata = widget.metadata;
    final state = widget.state;

    final totalDuration = state.position.duration > Duration.zero
        ? state.position.duration
        : (metadata.duration ?? Duration.zero);
    final progress = totalDuration.inMilliseconds == 0
        ? 0.0
        : (state.position.position.inMilliseconds /
                  totalDuration.inMilliseconds)
              .clamp(0.0, 1.0);

    final ytid = metadata.extras?['ytid']?.toString();
    final isOffline = ytid != null && isSongAlreadyOffline(ytid);

    if (metadata.id == _dismissedMediaId) return const SizedBox.shrink();

    return ArtworkColorBuilder(
      key: MiniPlayer._pillKey,
      artwork: _artworkSource(metadata),
      builder: (context, artworkColor) => AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _revealController]),
        builder: (context, child) {
          return Stack(
            children: [
              Positioned.fill(child: _buildCloseReveal(colorScheme)),
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.translate(
                  offset: Offset(
                    _revealController.value * _deleteRevealExtent,
                    0,
                  ),
                  child: GestureDetector(
                    onTapDown: (_) => _animationController.forward(),
                    onTapUp: (_) => _animationController.reverse(),
                    onTapCancel: () => _animationController.reverse(),
                    onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                    onHorizontalDragEnd: _handleHorizontalDragEnd,
                    onVerticalDragUpdate: _handleVerticalDrag,
                    onTap: _handleTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        MiniPlayer._borderRadius,
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 550),
                          curve: Curves.easeOut,
                          height: MiniPlayer.playerHeight,
                          decoration: BoxDecoration(
                            color: miniPlayerSurfaceColor(
                              colorScheme,
                              artworkColor,
                            ),
                            borderRadius: BorderRadius.circular(
                              MiniPlayer._borderRadius,
                            ),
                            border: Border.all(
                              color: miniPlayerBorderColor(
                                colorScheme,
                                artworkColor,
                              ),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: getGlassShadowColor(colorScheme),
                                blurRadius: 18,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              MiniPlayer._borderRadius,
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        _ArtworkWidget(metadata: metadata),
                                        Expanded(
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            switchInCurve: Curves.easeIn,
                                            switchOutCurve: Curves.easeOut,
                                            layoutBuilder:
                                                (
                                                  currentChild,
                                                  previousChildren,
                                                ) => Stack(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  children: [
                                                    ...previousChildren,
                                                    if (currentChild != null)
                                                      currentChild,
                                                  ],
                                                ),
                                            transitionBuilder:
                                                (child, animation) =>
                                                    FadeTransition(
                                                      opacity: animation,
                                                      child: child,
                                                    ),
                                            child: KeyedSubtree(
                                              key: ValueKey(metadata.id),
                                              child: _MetadataWidget(
                                                title: metadata.title,
                                                artist: metadata.artist,
                                                isOffline: isOffline,
                                                verified:
                                                    metadata
                                                        .extras?['artistVerified'] ==
                                                    true,
                                                colorScheme: colorScheme,
                                              ),
                                            ),
                                          ),
                                        ),
                                        _PlayPauseButton(
                                          colorScheme: colorScheme,
                                          playbackState: state.playbackState,
                                        ),
                                        _NextButton(colorScheme: colorScheme),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 2,
                                  width: double.infinity,
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 2,
                                    backgroundColor: colorScheme.outline
                                        .withValues(alpha: 0.45),
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCloseReveal(ColorScheme colorScheme) {
    // The button waits just past the leading edge and slides into the strip
    // the mini player uncovers, so it reads as emerging from behind the card.
    final hidden =
        (1 - _revealController.value.clamp(0.0, 1.0)) *
        (_deleteButtonSize + _deleteButtonInset);

    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.translate(
          offset: Offset(-hidden, 0),
          child: Padding(
            padding: const EdgeInsets.only(left: _deleteButtonInset),
            child: _ClosePlayerButton(
              colorScheme: colorScheme,
              onPressed: _closePlayer,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosePlayerButton extends StatelessWidget {
  const _ClosePlayerButton({
    required this.colorScheme,
    required this.onPressed,
  });

  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        _MiniPlayerBodyState._deleteButtonSize,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: getGlassSurfaceColor(colorScheme),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Container(
              width: _MiniPlayerBodyState._deleteButtonSize,
              height: _MiniPlayerBodyState._deleteButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: getGlassBorderColor(colorScheme),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: getGlassShadowColor(colorScheme),
                    blurRadius: 18,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                FluentIcons.dismiss_24_filled,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkWidget extends StatelessWidget {
  const _ArtworkWidget({required this.metadata});
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Hero(
        tag: 'now_playing_artwork',
        child: SongArtworkWidget(
          metadata: metadata,
          size: MiniPlayer._artworkSize,
          errorWidgetIconSize: 20,
          borderRadius: MiniPlayer._artworkRadius,
        ),
      ),
    );
  }
}

class _MetadataWidget extends StatelessWidget {
  const _MetadataWidget({
    required this.title,
    required this.artist,
    required this.isOffline,
    this.verified = false,
    required this.colorScheme,
  });

  final String title;
  final String? artist;
  final bool isOffline;
  final bool verified;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarqueeWidget(
            manualScrollEnabled: false,
            animationDuration: const Duration(seconds: 8),
            backDuration: const Duration(seconds: 2),
            pauseDuration: const Duration(seconds: 2),
            child: Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (isOffline) ...[
                Icon(
                  FluentIcons.checkmark_circle_16_filled,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  artist ?? '',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (verified) ...[
                const SizedBox(width: 5),
                const VerifiedArtistBadge(size: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: audioHandler.skipToNext,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: Icon(
        FluentIcons.next_24_filled,
        color: colorScheme.onSurface,
        size: 24,
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.colorScheme,
    required this.playbackState,
  });

  final ColorScheme colorScheme;
  final PlaybackState playbackState;

  @override
  Widget build(BuildContext context) {
    final processingState = playbackState.processingState;
    final isPlaying = playbackState.playing;
    final isLoading =
        processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering;
    final isCompleted = processingState == AudioProcessingState.completed;

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onSurface),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: isCompleted
          ? () => audioHandler.playAgain()
          : (isPlaying ? audioHandler.pause : audioHandler.play),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: Icon(
        isCompleted
            ? FluentIcons.arrow_counterclockwise_24_filled
            : (isPlaying
                  ? FluentIcons.pause_24_filled
                  : FluentIcons.play_24_filled),
        color: colorScheme.onSurface,
        size: 28,
      ),
    );
  }
}

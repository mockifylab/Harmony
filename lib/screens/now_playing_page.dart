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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/theme/artwork_palette.dart';
import 'package:musify/widgets/flip_card.dart';
import 'package:musify/widgets/now_playing/about_artist_sheet.dart';
import 'package:musify/widgets/now_playing/bottom_actions_row.dart';
import 'package:musify/widgets/now_playing/now_playing_artist.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import 'package:musify/widgets/now_playing/now_playing_controls.dart';
import 'package:musify/widgets/queue_list_view.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final _lyricsController = FlipCardController();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800 && size.height > 600;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = size.width;
    final baseIconSize = screenWidth < 360
        ? 36.0
        : screenWidth < 400
        ? 40.0
        : 44.0;
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          final metadata = snapshot.data;

          return ArtworkColorBuilder(
            artwork: _artworkOf(metadata),
            builder: (context, artworkColor) => AnimatedContainer(
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: artworkBackdropColors(colorScheme, artworkColor),
                  stops: const [0.0, 0.38, 0.72],
                ),
              ),
              child: SafeArea(
                child: metadata == null
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          _buildAppBar(context, colorScheme, metadata),
                          Expanded(
                            child: isLargeScreen
                                ? _DesktopLayout(
                                    metadata: metadata,
                                    size: size,
                                    adjustedIconSize: baseIconSize,
                                    adjustedMiniIconSize: miniIconSize,
                                    lyricsController: _lyricsController,
                                  )
                                : _PlayerSwipe(
                                    onTriggered: () =>
                                        _openAboutArtist(context, metadata),
                                    onDismiss: () => Navigator.pop(context),
                                    child: _MobileLayout(
                                      metadata: metadata,
                                      size: size,
                                      adjustedIconSize: baseIconSize,
                                      adjustedMiniIconSize: miniIconSize,
                                      isLargeScreen: isLargeScreen,
                                      lyricsController: _lyricsController,
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _artworkOf(MediaItem? metadata) {
    if (metadata == null) return null;
    final artworkPath = metadata.extras?['artWorkPath']?.toString();
    if (artworkPath != null && artworkPath.isNotEmpty) return artworkPath;
    return metadata.artUri?.toString();
  }

  /// Opens the artist of the playing song over the player, and follows the
  /// sheet's "Go to artist" the way the artist name does: the player is left
  /// behind for the artist page.
  Future<void> _openAboutArtist(
    BuildContext context,
    MediaItem metadata,
  ) async {
    final info = extractNowPlayingArtist(metadata);
    final lookup = nowPlayingArtistLookup(info);
    if (offlineMode.value || lookup.isEmpty) return;

    final router = GoRouter.of(context);
    final artistPath = NavigationManager.artistPath(context, lookup);

    final openArtist = await showAboutArtistSheet(
      context,
      info: info,
      lookup: lookup,
    );
    if (!openArtist || !context.mounted) return;

    Navigator.of(context).pop();
    unawaited(router.push(artistPath, extra: nowPlayingArtistSeed(info)));
  }

  Widget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem metadata,
  ) {
    final canOpenArtist = canOpenNowPlayingArtist(metadata);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            iconSize: 26,
            icon: const Icon(FluentIcons.chevron_down_24_regular),
            style: IconButton.styleFrom(foregroundColor: colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: canOpenArtist
                  ? _AboutArtistPill(
                      colorScheme: colorScheme,
                      onPressed: () => _openAboutArtist(context, metadata),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Balances the leading button so the pill sits in the middle.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// The way into the artist of the playing song. Reads as part of the player
/// chrome until it is used.
class _AboutArtistPill extends StatelessWidget {
  const _AboutArtistPill({required this.colorScheme, required this.onPressed});

  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: getGlassSurfaceColor(colorScheme),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: getGlassBorderColor(colorScheme)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.person_24_regular,
                size: 16,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 7),
              Text(
                context.l10n!.aboutArtist,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Swipe gestures on the player body. An upward swipe opens the about-artist
/// sheet, a downward swipe dismisses the player. The page lifts as the swipe
/// is made so the gesture is felt before it is released; each direction only
/// fires once it passes its threshold, playback is untouched either way, and
/// swipes only start over content that does not scroll vertically itself.
class _PlayerSwipe extends StatefulWidget {
  const _PlayerSwipe({
    required this.onTriggered,
    required this.onDismiss,
    required this.child,
  });

  final VoidCallback onTriggered;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<_PlayerSwipe> createState() => _PlayerSwipeState();
}

class _PlayerSwipeState extends State<_PlayerSwipe>
    with SingleTickerProviderStateMixin {
  static const _threshold = 64.0;
  static const _dismissThreshold = 110.0;
  static const _lift = 14.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  // Signed: negative is an upward swipe, positive a downward one.
  double _drag = 0;

  void _onUpdate(DragUpdateDetails details) {
    _drag = (_drag + details.delta.dy).clamp(
      -_threshold,
      _dismissThreshold * 1.8,
    );
    _controller.value = (_drag.abs() / _threshold).clamp(0.0, 2.0);
  }

  void _onEnd(DragEndDetails details) {
    final triggered = _drag <= -_threshold;
    final dismiss = _drag >= _dismissThreshold;
    _drag = 0;
    _controller.value = 0;
    if (triggered) {
      widget.onTriggered();
      return;
    }
    if (dismiss) {
      widget.onDismiss();
      return;
    }
    unawaited(_controller.reverse());
  }

  double get _sinkOffset {
    final drag = _drag;
    if (drag <= _dismissThreshold) return drag;
    return _dismissThreshold + (drag - _dismissThreshold) * 0.35;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onUpdate,
      onVerticalDragEnd: _onEnd,
      onVerticalDragCancel: _cancelDrag,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            0,
            _drag >= 0
                ? _sinkOffset
                : -_lift *
                      Curves.easeOut.transform(
                        _controller.value.clamp(0.0, 1.0),
                      ),
          ),
          child: child,
        ),
      ),
    );
  }

  void _cancelDrag() {
    _drag = 0;
    unawaited(_controller.reverse());
  }
}

/// Transport by artwork: dragging the cover left goes to the next song and
/// right to the previous one, using the same queue the transport buttons use.
/// The artwork tracks the finger, a drag that never passes the threshold eases
/// back without changing songs, and vertical drags are left to the dismissal
/// gesture above, which the gesture arena splits by direction.
class _ArtworkSwipe extends StatefulWidget {
  const _ArtworkSwipe({required this.child});

  final Widget child;

  @override
  State<_ArtworkSwipe> createState() => _ArtworkSwipeState();
}

class _ArtworkSwipeState extends State<_ArtworkSwipe>
    with SingleTickerProviderStateMixin {
  static const double _threshold = 72;
  static const double _flickVelocity = 700;
  // Past this the artwork keeps following the finger, but slower, so it stays
  // on screen while the drag still feels answered.
  static const double _maxDrag = 180;

  late final AnimationController _settleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  Animation<double> _settle = const AlwaysStoppedAnimation(0);
  double _drag = 0;

  void _onUpdate(DragUpdateDetails details) {
    if (_settleController.isAnimating) return;
    final delta = details.primaryDelta ?? 0;
    if (delta == 0) return;

    setState(() {
      final next = _drag + delta;
      _drag = next.abs() <= _maxDrag
          ? next
          : next.sign * (_maxDrag + (next.abs() - _maxDrag) * 0.3);
    });
  }

  void _onEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final passedDrag = _drag.abs() >= _threshold;
    if (passedDrag || velocity.abs() >= _flickVelocity) {
      final swipeLeft = (passedDrag ? _drag.sign : velocity.sign) < 0;
      unawaited(
        swipeLeft ? audioHandler.skipToNext() : audioHandler.skipToPrevious(),
      );
    }
    _settleBack();
  }

  void _settleBack() {
    _settle = Tween<double>(begin: _drag, end: 0).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutCubic),
    );
    _drag = 0;
    unawaited(_settleController.forward(from: 0));
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (_) {
        // Picking the artwork up mid-settle keeps it under the finger instead
        // of jumping back to where the settle started.
        if (!_settleController.isAnimating) return;
        _drag = _settle.value;
        _settleController.stop();
      },
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: _settleBack,
      child: AnimatedBuilder(
        animation: _settleController,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            _settleController.isAnimating ? _settle.value : _drag,
            0,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.lyricsController,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final FlipCardController lyricsController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: NowPlayingArtwork(
                      size: size,
                      metadata: metadata,
                      lyricsController: lyricsController,
                    ),
                  ),
                ),
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    flex: 4,
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: true,
                  lyricsController: lyricsController,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        const Expanded(child: QueueWidget()),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
    required this.lyricsController,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final FlipCardController lyricsController;

  @override
  Widget build(BuildContext context) {
    final isLandscape = size.width > size.height;

    if (isLandscape) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            flex: 5,
            child: Center(
              child: _ArtworkSwipe(
                child: NowPlayingArtwork(
                  size: size,
                  metadata: metadata,
                  lyricsController: lyricsController,
                ),
              ),
            ),
          ),
          if (!isLive)
            Expanded(
              flex: 4,
              child: NowPlayingControls(
                size: size,
                audioId: metadata.extras?['ytid'],
                adjustedIconSize: adjustedIconSize,
                adjustedMiniIconSize: adjustedMiniIconSize,
                metadata: metadata,
              ),
            ),
          BottomActionsRow(
            metadata: metadata,
            iconSize: adjustedMiniIconSize,
            isLargeScreen: isLargeScreen,
            lyricsController: lyricsController,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: _ArtworkSwipe(
                child: NowPlayingArtwork(
                  size: size,
                  metadata: metadata,
                  lyricsController: lyricsController,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isLive)
                  Expanded(
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: isLargeScreen,
                  lyricsController: lyricsController,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

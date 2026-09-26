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
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/widgets/download_button.dart';
import 'package:musify/widgets/now_playing/marquee_text_widget.dart';
import 'package:musify/widgets/now_playing/now_playing_artist.dart';
import 'package:musify/widgets/playback_icon_button.dart';
import 'package:musify/widgets/position_slider.dart';
import 'package:musify/widgets/verified_artist_badge.dart';

class NowPlayingControls extends StatelessWidget {
  const NowPlayingControls({
    super.key,
    required this.size,
    required this.audioId,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.metadata,
  });

  final Size size;
  final dynamic audioId;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = size.width > 800;

    final titleFontSize = getResponsiveTitleFontSize(size);
    final artistFontSize = getResponsiveArtistFontSize(size);
    final canOpenArtist = canOpenNowPlayingArtist(metadata);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 280;
        final isVeryCompact = availableHeight < 200;

        final spacing = isVeryCompact
            ? 2.0
            : isCompact
            ? 4.0
            : 8.0;
        final iconScale = isVeryCompact
            ? 0.65
            : isCompact
            ? 0.75
            : 1.0;
        final fontScale = isCompact ? 0.9 : 1.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCompact) const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 8 : 4,
                vertical: spacing,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () =>
                              _copyNowPlayingSong(context, metadata),
                          child: MarqueeTextWidget(
                            text: metadata.title,
                            fontColor: colorScheme.onSurface,
                            fontSize: titleFontSize * fontScale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: spacing),
                        if (metadata.artist != null)
                          Row(
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: canOpenArtist
                                      ? () => _openArtistPage(context, metadata)
                                      : null,
                                  onLongPress: () =>
                                      _copyNowPlayingSong(context, metadata),
                                  child: MarqueeTextWidget(
                                    text: metadata.artist!,
                                    fontColor: colorScheme.onSurfaceVariant,
                                    fontSize: artistFontSize * fontScale,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (metadata.extras?['artistVerified'] ==
                                  true) ...[
                                const SizedBox(width: 5),
                                const VerifiedArtistBadge(size: 16),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  _NowPlayingQuickActions(metadata: metadata),
                ],
              ),
            ),
            if (!isCompact) const Spacer(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 400 : constraints.maxWidth,
              ),
              child: const PositionSlider(),
            ),
            SizedBox(height: spacing),
            PlayerControlButtons(
              metadata: metadata,
              iconSize: adjustedIconSize * iconScale,
              miniIconSize: adjustedMiniIconSize * iconScale,
            ),
            if (!isCompact) const Spacer(),
          ],
        );
      },
    );
  }

  void _openArtistPage(BuildContext context, MediaItem metadata) {
    final info = extractNowPlayingArtist(metadata);
    final lookup = nowPlayingArtistLookup(info);

    if (lookup.isEmpty) return;

    final router = GoRouter.of(context);
    final artistPath = NavigationManager.artistPath(context, lookup);

    Navigator.of(context).pop();
    unawaited(router.push(artistPath, extra: nowPlayingArtistSeed(info)));
  }
}

Future<void> _copyNowPlayingSong(
  BuildContext context,
  MediaItem metadata,
) async {
  final artist = metadata.artist?.trim();
  final title = metadata.title.trim();
  final text = artist == null || artist.isEmpty ? title : '$artist - $title';
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showToast(context, context.l10n!.songInfoCopied);
}

class PlayerControlButtons extends StatelessWidget {
  const PlayerControlButtons({
    super.key,
    required this.metadata,
    required this.iconSize,
    required this.miniIconSize,
  });
  final MediaItem metadata;
  final double iconSize;
  final double miniIconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveIconSize = screenWidth < 360 ? iconSize * 0.85 : iconSize;
    final responsiveMiniIconSize = screenWidth < 360
        ? miniIconSize * 0.85
        : miniIconSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isTight = maxWidth < 360;
        final isUltraTight = maxWidth < 320;

        final horizontalPadding = isUltraTight
            ? 10.0
            : isTight
            ? 14.0
            : 20.0;

        final controlIconSize =
            responsiveIconSize *
            (isUltraTight
                ? 0.75
                : isTight
                ? 0.85
                : 0.92);
        final miniControlSize =
            responsiveMiniIconSize *
            (isUltraTight
                ? 0.8
                : isTight
                ? 0.9
                : 1.0);
        final playPadding = EdgeInsets.all(
          responsiveIconSize *
              (isUltraTight
                  ? 0.30
                  : isTight
                  ? 0.36
                  : 0.45),
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _buildShuffleButton(context, colorScheme, miniControlSize),
              _PlaybackControlButton(
                icon: FluentIcons.previous_24_filled,
                isEnabled:
                    audioHandler.hasPrevious ||
                    repeatNotifier.value != AudioServiceRepeatMode.none,
                tooltip: context.l10n!.skipToPrevious,
                onPressed: () => audioHandler.skipToPrevious(),
                colorScheme: colorScheme,
                controlIconSize: controlIconSize,
              ),
              PlaybackIconButton(
                iconColor: colorScheme.onPrimary,
                backgroundColor: colorScheme.primary,
                iconSize: controlIconSize * 1.15,
                padding: playPadding,
              ),
              StreamBuilder<List<MediaItem>>(
                stream: audioHandler.queue,
                builder: (context, snapshot) {
                  return ValueListenableBuilder<AudioServiceRepeatMode>(
                    valueListenable: repeatNotifier,
                    builder: (_, repeatMode, __) {
                      return _PlaybackControlButton(
                        icon: FluentIcons.next_24_filled,
                        isEnabled:
                            audioHandler.hasNext ||
                            repeatMode == AudioServiceRepeatMode.one,
                        tooltip: context.l10n!.skipToNext,
                        onPressed: () =>
                            repeatMode == AudioServiceRepeatMode.one
                            ? audioHandler.playAgain()
                            : audioHandler.skipToNext(),
                        colorScheme: colorScheme,
                        controlIconSize: controlIconSize,
                      );
                    },
                  );
                },
              ),
              NowPlayingLikeButton(
                metadata: metadata,
                iconSize: miniControlSize,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShuffleButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
  ) {
    return _ShuffleToggleButton(colorScheme: colorScheme, size: size);
  }
}

/// Shuffle toggle with a one-shot settle animation. Each time the shuffle
/// state actually changes, the icon turns from its resting pose into the new
/// state with a short easeOutCubic rotation — the same motion language as
/// HarmonyReveal. It fires only on state transitions, never on rebuilds, and
/// never loops or bounces.
class _ShuffleToggleButton extends StatefulWidget {
  const _ShuffleToggleButton({required this.colorScheme, required this.size});

  final ColorScheme colorScheme;
  final double size;

  @override
  State<_ShuffleToggleButton> createState() => _ShuffleToggleButtonState();
}

class _ShuffleToggleButtonState extends State<_ShuffleToggleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _rotation = Tween<double>(
    begin: 0.35,
    end: 0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  bool _shuffleEnabled = shuffleNotifier.value;

  @override
  void initState() {
    super.initState();
    shuffleNotifier.addListener(_onShuffleChanged);
  }

  void _onShuffleChanged() {
    if (shuffleNotifier.value == _shuffleEnabled) return;
    setState(() {
      _shuffleEnabled = shuffleNotifier.value;
    });
    unawaited(_controller.forward(from: 0));
  }

  @override
  void dispose() {
    shuffleNotifier.removeListener(_onShuffleChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _shuffleEnabled;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(angle: _rotation.value, child: child);
      },
      child: IconButton(
        icon: Icon(
          value
              ? FluentIcons.arrow_shuffle_24_filled
              : FluentIcons.arrow_shuffle_24_regular,
          color: value
              ? widget.colorScheme.primary
              : widget.colorScheme.onSurfaceVariant,
        ),
        tooltip: context.l10n!.shuffle,
        iconSize: widget.size,
        onPressed: () {
          audioHandler.setShuffleMode(
            value ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
          );
        },
      ),
    );
  }
}

/// Cycles the queue repeat mode. It lives in the player's action row so the
/// main control row keeps the Shuffle/Previous/Play/Next/Like order.
class NowPlayingRepeatButton extends StatelessWidget {
  const NowPlayingRepeatButton({super.key, required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = iconSize;

    return StreamBuilder<List<MediaItem>>(
      stream: audioHandler.queue,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? [];
        return ValueListenableBuilder<AudioServiceRepeatMode>(
          valueListenable: repeatNotifier,
          builder: (_, repeatMode, __) {
            final isActive = repeatMode != AudioServiceRepeatMode.none;

            return IconButton(
              icon: Icon(
                repeatMode == AudioServiceRepeatMode.one
                    ? FluentIcons.arrow_repeat_1_24_filled
                    : isActive
                    ? FluentIcons.arrow_repeat_all_24_filled
                    : FluentIcons.arrow_repeat_all_off_24_regular,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              tooltip: context.l10n!.repeat,
              iconSize: size,
              style: IconButton.styleFrom(
                backgroundColor: isActive
                    ? colorScheme.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final AudioServiceRepeatMode newMode;
                if (repeatMode == AudioServiceRepeatMode.none) {
                  newMode = queue.length <= 1
                      ? AudioServiceRepeatMode.one
                      : AudioServiceRepeatMode.all;
                } else if (repeatMode == AudioServiceRepeatMode.all) {
                  newMode = AudioServiceRepeatMode.one;
                } else {
                  newMode = AudioServiceRepeatMode.none;
                }
                repeatNotifier.value = newMode;
                audioHandler.setRepeatMode(newMode);
              },
            );
          },
        );
      },
    );
  }
}

/// Toggles the current song's liked state through the shared liked-songs store,
/// so the button stays in sync with every other screen. Uses the same plus and
/// added-to-liked presentation as the notification's like control.
class NowPlayingLikeButton extends StatelessWidget {
  const NowPlayingLikeButton({
    super.key,
    required this.metadata,
    required this.iconSize,
    this.showBackground = false,
  });

  final MediaItem metadata;
  final double iconSize;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final audioId = metadata.extras?['ytid']?.toString();
    final isRadio = metadata.extras?['isLive'] ?? false;

    return ValueListenableBuilder<List>(
      valueListenable: isRadio ? userLikedRadioStations : userLikedSongsList,
      builder: (context, _, __) {
        final isLiked = isRadio
            ? isRadioStationLiked(audioId ?? '')
            : isSongAlreadyLiked(audioId);

        return IconButton(
          icon: Icon(
            isLiked
                ? FluentIcons.checkmark_circle_24_filled
                : FluentIcons.add_24_regular,
            color: isLiked ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          iconSize: iconSize,
          tooltip: isLiked
              ? context.l10n!.removeFromLikedSongs
              : context.l10n!.addToLikedSongs,
          style: IconButton.styleFrom(
            backgroundColor: showBackground && isLiked
                ? colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _toggleLike(context),
        );
      },
    );
  }

  Future<void> _toggleLike(BuildContext context) async {
    final id = metadata.extras?['ytid']?.toString();
    if (id == null || id.isEmpty) return;

    try {
      if (metadata.extras?['isLive'] ?? false) {
        if (isRadioStationLiked(id)) {
          await removeRadioStationFromLiked(id);
        } else {
          await addRadioStationToLiked(id);
        }
        return;
      }

      await updateSongLikeStatus(
        id,
        !isSongAlreadyLiked(id),
        songData: mediaItemToMap(metadata),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Error toggling like status from the player',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

class _NowPlayingQuickActions extends StatelessWidget {
  const _NowPlayingQuickActions({required this.metadata});

  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final audioId = metadata.extras?['ytid']?.toString();
    final isRadio = metadata.extras?['isLive'] ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NowPlayingLikeButton(metadata: metadata, iconSize: 24),
        if (!offlineMode.value && !isRadio)
          ValueListenableBuilder<Set<String>>(
            valueListenable: activeSongDownloads,
            builder: (context, activeDownloads, _) {
              final isDownloading = activeDownloads.contains(audioId);
              final isOffline = isSongAlreadyOffline(audioId);

              return DownloadIconButton(
                state: isDownloading
                    ? DownloadButtonState.downloading
                    : isOffline
                    ? DownloadButtonState.completed
                    : DownloadButtonState.idle,
                completedColor: colorScheme.primary,
                tooltip: context.l10n!.makeOffline,
                onPressed: audioId == null || isDownloading
                    ? null
                    : () async {
                        if (isSongAlreadyOffline(audioId)) {
                          await OfflinePlaylistService()
                              .removeSongFromOfflineAndResync(audioId);
                        } else {
                          await makeSongOffline(mediaItemToMap(metadata));
                        }
                      },
              );
            },
          ),
      ],
    );
  }
}

class _PlaybackControlButton extends StatelessWidget {
  const _PlaybackControlButton({
    required this.icon,
    required this.isEnabled,
    required this.tooltip,
    required this.onPressed,
    required this.colorScheme,
    required this.controlIconSize,
  });

  final IconData icon;
  final bool isEnabled;
  final String tooltip;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final double controlIconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        color: isEnabled
            ? colorScheme.onSurface
            : colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      tooltip: tooltip,
      iconSize: controlIconSize * 0.85,
      onPressed: isEnabled ? onPressed : null,
    );
  }
}

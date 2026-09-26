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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/artist_service.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/widgets/artist_shelf.dart';
import 'package:musify/widgets/now_playing/now_playing_artist.dart';
import 'package:musify/widgets/playlist_cube.dart';
import 'package:musify/widgets/section_header.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/spinner.dart';
import 'package:musify/widgets/verified_artist_badge.dart';

/// Opens the artist of the playing song. Resolves to true when the sheet was
/// dismissed by asking for the artist page.
Future<bool> showAboutArtistSheet(
  BuildContext context, {
  required NowPlayingArtist info,
  required String lookup,
}) async {
  final openArtist = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => AboutArtistSheet(info: info, lookup: lookup),
  );
  return openArtist ?? false;
}

/// What the artist page knows about an artist, without leaving the player.
///
/// Only the fields the artist profile actually carries are shown: the artwork,
/// the name, the monthly listener count and the biography. Nothing is derived
/// or guessed, and an artist the API has no further detail for says so.
class AboutArtistSheet extends StatefulWidget {
  const AboutArtistSheet({super.key, required this.info, required this.lookup});

  final NowPlayingArtist info;

  /// The id the profile is looked up with, as given by [nowPlayingArtistLookup].
  final String lookup;

  @override
  State<AboutArtistSheet> createState() => _AboutArtistSheetState();
}

class _AboutArtistSheetState extends State<AboutArtistSheet> {
  late final Future<Map<String, dynamic>?> _profile = getArtistProfile(
    widget.lookup,
    preferredName: widget.info.artist.isEmpty ? null : widget.info.artist,
    sourceSongId: widget.info.sourceSongId.isEmpty
        ? null
        : widget.info.sourceSongId,
    sourceVideoAuthor: widget.info.videoAuthor.isEmpty
        ? null
        : widget.info.videoAuthor,
    // An artist id from the song's metadata is the channel that uploaded it,
    // so it can be trusted when the strict name search would give up.
    preferredVerified: widget.info.artistId.isNotEmpty,
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: getSettingsGlassColor(colorScheme),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: getGlassBorderColor(colorScheme)),
            ),
            boxShadow: [
              BoxShadow(
                color: getGlassShadowColor(colorScheme),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * 0.62),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(context, colorScheme),
                  _buildTitle(context, colorScheme),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: _profile,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 180,
                              child: Spinner(),
                            );
                          }
                          final artist = snapshot.data;
                          if (artist == null) {
                            return _buildUnavailable(context, colorScheme);
                          }
                          return _buildArtist(context, colorScheme, artist);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(BuildContext context, ColorScheme colorScheme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(false),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.person_24_regular,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n!.aboutArtist,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtist(
    BuildContext context,
    ColorScheme colorScheme,
    Map<String, dynamic> artist,
  ) {
    final l10n = context.l10n!;
    final name = _artistName(artist);
    final listeners = artist['monthlyListeners']?.toString().trim() ?? '';
    final description = artist['description']?.toString().trim() ?? '';
    final hasListeners = listeners.isNotEmpty;
    final hasDescription = description.isNotEmpty;
    // Each shelf entry pairs the song with its real play count; the count
    // ranks the shelf and never travels into the song map.
    final topSongEntries = asMapList(artist['topSongs'])
        .where((entry) => entry['song'] is Map)
        .toList();
    final topSongs = [
      for (final entry in topSongEntries)
        Map<String, dynamic>.from(entry['song'] as Map),
    ];
    final releases = asMapList(artist['releases']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ClipOval(
            child: PlaylistCube(
              artist,
              size: 104,
              cubeIcon: FluentIcons.person_24_filled,
              showTypeLabel: false,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              // Earned by the artist page itself, never inferred from the name.
              if (artist['isVerifiedArtist'] == true) ...[
                const SizedBox(width: 5),
                const VerifiedArtistBadge(size: 18),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.artist,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (hasListeners) ...[
          const SizedBox(height: 14),
          Center(
            child: _buildChip(
              colorScheme,
              FluentIcons.headphones_20_filled,
              '$listeners ${l10n.monthlyListeners}',
            ),
          ),
        ],
        if (hasDescription) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: getHarmonyCardColor(colorScheme),
              borderRadius: BorderRadius.circular(18),
              border: getHarmonyCardBorder(colorScheme),
            ),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (topSongs.isNotEmpty)
          _buildPopularTracks(
            context,
            colorScheme,
            name,
            topSongs,
            topSongEntries,
          ),
        if (releases.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ArtistShelf(
              title: l10n.albums,
              icon: FluentIcons.cd_16_regular,
              items: releases,
              subtitleOf: _releaseSubtitle,
              onTap: _openRelease,
            ),
          ),
        if (!hasListeners &&
            !hasDescription &&
            topSongs.isEmpty &&
            releases.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.noArtistDetails,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(FluentIcons.arrow_right_24_regular, size: 20),
          label: Text(l10n.goToArtist),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.primary,
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.55),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// The artist's own shelf of most-played songs: real tracks ordered by the
  /// play count the API reports for them, capped so the sheet stays a sheet.
  Widget _buildPopularTracks(
    BuildContext context,
    ColorScheme colorScheme,
    String artistName,
    List<Map<String, dynamic>> songs,
    List<Map<String, dynamic>> entries,
  ) {
    const shownCount = 5;
    return Column(
      children: [
        const SizedBox(height: 24),
        SectionHeader(
          title: context.l10n!.topSongs,
          icon: FluentIcons.music_note_2_24_filled,
        ),
        for (var i = 0; i < songs.length && i < shownCount; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == songs.length - 1 || i == shownCount - 1 ? 0 : 10,
            ),
            child: SongBar(
              songs[i],
              true,
              rank: i + 1,
              playCount: entries[i]['playCount']?.toString(),
              borderRadius: BorderRadius.circular(18),
              backgroundColor: getHarmonyCardColor(colorScheme),
              border: getHarmonyCardBorder(colorScheme),
              onPlay: () => audioHandler.playPlaylistSong(
                playlist: {'title': artistName, 'list': songs},
                songIndex: i,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChip(ColorScheme colorScheme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            FluentIcons.person_24_regular,
            size: 40,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n!.artistNotFound,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// A release leaves the sheet behind: the album page takes over the player.
  void _openRelease(Map<String, dynamic> release) {
    final releaseId = release['ytid']?.toString();
    if (releaseId == null || releaseId.isEmpty) return;

    final router = GoRouter.of(context);
    final path = NavigationManager.albumPath(context, releaseId);
    Navigator.of(context).pop();
    unawaited(router.push(path, extra: release));
  }

  String _releaseSubtitle(Map<String, dynamic> release) {
    final year = release['year']?.toString();
    final type = switch (release['releaseType']?.toString()) {
      'single' => context.l10n!.single,
      'ep' => 'EP',
      _ => context.l10n!.album,
    };
    return year == null || year.isEmpty ? type : '$type • $year';
  }

  String _artistName(Map<String, dynamic> artist) {
    final title = normalizeArtistDisplayTitle(
      artist['title']?.toString() ?? '',
    );
    if (title.isNotEmpty) return title;
    return widget.info.artist;
  }
}

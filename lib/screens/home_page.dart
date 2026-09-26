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
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/artist_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:musify/widgets/announcement_box.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/harmony_refresh_badge.dart';
import 'package:musify/widgets/harmony_reveal.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playing_indicator_bars.dart';
import 'package:musify/widgets/playlist_artwork.dart';
import 'package:musify/widgets/section_header.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/typewriter_text.dart';
import 'package:musify/widgets/verified_artist_badge.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // The pull the surrounding RefreshIndicator has to accumulate before a
  // release actually refreshes: 25% of the viewport. The framework's earlier
  // `armed` flip sits at only a sixth of that, so mapping the badge to the
  // real threshold makes a deliberate pull the thing that reads as activation.
  static const _pullToArmFraction = 0.25;

  /// Space between the search header and the greeting: the original lead-in
  /// plus the 15dp the header was nudged down by.
  static const _greetingLeadIn = 27.0;

  /// Rotating lines under the greeting. Every entry is a real signal: the
  /// genre and release lines describe what the app actually serves, and the
  /// artist line comes from the user's own history, so nothing here is
  /// hardcoded. Held as one instance so the typewriter never restarts
  /// mid-rotation.
  late final List<String> _greetingPhrases = _buildGreetingPhrases();

  List<String> _buildGreetingPhrases() {
    final artist = _topRecentArtist();
    return [
      if (artist != null) 'More like $artist',
      'Punjabi and Urdu rap',
      'Built from your listening',
      'Tuned to your taste',
      'Fresh drops for you',
    ];
  }

  /// The artist played most often in the user's stored history, skipping
  /// names too long for the line and channels that are not the artist.
  String? _topRecentArtist() {
    final counts = <String, int>{};
    final names = <String, String>{};

    for (final song in userRecentlyPlayed.value.whereType<Map>()) {
      final name = song['artist']?.toString().trim() ?? '';
      if (name.isEmpty || name.length > 16) continue;
      if (looksUnofficialArtistName(name)) continue;
      final key = name.toLowerCase();
      names.putIfAbsent(key, () => name);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (names.isEmpty) return null;

    var best = names.keys.first;
    for (final key in names.keys) {
      if (counts[key]! > counts[best]!) best = key;
    }
    return names[best];
  }

  late Future<List> _recommendedSongsFuture;
  late Future<List> _madeForYouFuture;
  late Future<Map<String, List>> _newReleasesFuture;
  late Future<List<Map<String, dynamic>>> _recentArtistsFuture;
  final ScrollController _homeScrollController = ScrollController();
  // Kept outside of setState so a status tick during the pull gesture
  // rebuilds only the badge, not the whole Home page.
  final ValueNotifier<RefreshIndicatorStatus?> _refreshStatus = ValueNotifier(
    null,
  );

  /// Whether the header search field currently holds focus, so the header can
  /// stay expanded while the keyboard is up regardless of scroll position.
  final ValueNotifier<bool> _searchFieldFocused = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _recommendedSongsFuture = getRecommendedSongs();
    _madeForYouFuture = getPlaylists(playlistsNum: 20);
    _newReleasesFuture = getNewReleases();
    _recentArtistsFuture = _resolveRecentArtists();
    externalRecommendations.addListener(_refreshRecommendedSongs);
  }

  Future<List<Map<String, dynamic>>> _resolveRecentArtists() async {
    final seen = <String>{};
    final names = <String>[];

    for (final song in userRecentlyPlayed.value.whereType<Map>()) {
      final name = song['artist']?.toString().trim();
      if (name == null || name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.add(key)) names.add(name);
      // More candidates than the section needs are collected because several
      // song credits can resolve to the same artist.
      if (names.length >= 12) break;
    }

    final artistIds = <String>{};
    final artistTitles = <String>{};
    final artists = <Map<String, dynamic>>[];

    // Resolve every candidate concurrently so the section is not serialized
    // on a dozen sequential network round trips at launch.
    final resolved = await Future.wait(
      names.map(
        (name) => searchVerifiedArtists(
          name,
          limit: 1,
        ).catchError((_) => <Map<String, dynamic>>[]),
      ),
    );

    for (final found in resolved) {
      if (artists.length >= 6) break;
      if (found.isEmpty) continue;

      final artist = found.first;
      final artistId = artist['ytid']?.toString().trim() ?? '';
      final artistTitle = normalizeArtistDisplayTitle(
        artist['title']?.toString() ?? '',
      ).toLowerCase();
      final isDuplicateId = artistId.isNotEmpty && !artistIds.add(artistId);
      final isDuplicateTitle =
          artistTitle.isNotEmpty && !artistTitles.add(artistTitle);
      if (isDuplicateId || isDuplicateTitle) continue;

      artists.add(artist);
    }
    return artists;
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _refreshStatus.dispose();
    _searchFieldFocused.dispose();
    externalRecommendations.removeListener(_refreshRecommendedSongs);
    super.dispose();
  }

  void _refreshRecommendedSongs() {
    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = getRecommendedSongs();
    });
  }

  Future<void> _refreshHomeData() async {
    // Failed fetches keep the previous future so a section never loses its
    // current content mid-refresh. The futures are swapped in only after all
    // fetches settle, which lets the sections update in place without a
    // loading-state flicker.
    var recommendedSongs = _recommendedSongsFuture;
    var madeForYou = _madeForYouFuture;
    var newReleases = _newReleasesFuture;
    var recentArtists = _recentArtistsFuture;

    await Future.wait<void>([
      getRecommendedSongs().then(
        (result) => recommendedSongs = Future.value(result),
        onError: (Object _) {},
      ),
      getPlaylists(playlistsNum: 20).then(
        (result) => madeForYou = Future.value(result),
        onError: (Object _) {},
      ),
      getNewReleases().then(
        (result) => newReleases = Future.value(result),
        onError: (Object _) {},
      ),
      _resolveRecentArtists().then(
        (result) => recentArtists = Future.value(result),
        onError: (Object _) {},
      ),
    ]);

    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = recommendedSongs;
      _madeForYouFuture = madeForYou;
      _newReleasesFuture = newReleases;
      _recentArtistsFuture = recentArtists;
    });
  }

  void _handleRefreshStatusChange(RefreshIndicatorStatus? status) {
    if (!mounted) return;
    _refreshStatus.value = status;
  }

  /// Touches on the home content move the focus away from the search field so
  /// the keyboard and the search panel never stay up behind a scroll or a
  /// tap on something else.
  void _dismissSearchFocus() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return;
    focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator.noSpinner(
        onRefresh: _refreshHomeData,
        onStatusChange: _handleRefreshStatusChange,
        child: Stack(
          children: [
            // Any touch that starts on the content - a tap or the start of a
            // swipe - takes the focus away from the search field, which also
            // collapses the search panel and closes the keyboard.
            Listener(
              onPointerDown: (_) => _dismissSearchFocus(),
              child: SingleChildScrollView(
                controller: _homeScrollController,
                physics: const BouncingScrollPhysics(),
                padding: commonSingleChildScrollViewPadding.copyWith(
                  top:
                      MediaQuery.paddingOf(context).top +
                      commonSingleChildScrollViewPadding.top +
                      140,
                ),
                child: Column(
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: announcementURL,
                      builder: (_, _url, __) {
                        if (_url == null) return const SizedBox.shrink();
                        final isSponsorshipAnnouncement =
                            isSponsorshipAnnouncementUrl(_url);
                        final _message = isSponsorshipAnnouncement
                            ? context.l10n!.sponsorProject
                            : context.l10n!.newAnnouncement;
                        final _icon = isSponsorshipAnnouncement
                            ? FluentIcons.heart_24_filled
                            : FluentIcons.megaphone_24_filled;

                        return AnnouncementBox(
                          message: _message,
                          url: _url,
                          icon: _icon,
                          onDismiss: () async {
                            announcementURL.value = null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: _greetingLeadIn),
                    _buildGreeting(),
                    const SizedBox(height: 16),
                    _buildQuickAccessGrid(),
                    const SizedBox(height: 24),
                    _buildMadeForYouSection(),
                    const SizedBox(height: 24),
                    _buildJumpBackInSection(),
                    const SizedBox(height: 24),
                    _buildNewReleasesSections(),
                    const SizedBox(height: 24),
                    _buildRecentArtistsSection(),
                    const SizedBox(height: 24),
                    _buildSuggestedSongsSection(),
                    const MiniPlayerBottomSpace(),
                  ],
                ),
              ),
            ),

            AnimatedBuilder(
              animation: Listenable.merge([
                _homeScrollController,
                _searchFieldFocused,
              ]),
              builder: (context, _) {
                const collapseDistance = 90.0;
                final scrollProgress =
                    ((_homeScrollController.hasClients
                                ? _homeScrollController.offset
                                : 0.0) /
                            collapseDistance)
                        .clamp(0.0, 1.0);
                // While the keyboard is up the header holds its fully
                // expanded size whatever the list beneath is doing, so the
                // bar never shrinks under the typist's finger.
                final progress = _searchFieldFocused.value
                    ? 0.0
                    : scrollProgress;

                return Positioned(
                  top: MediaQuery.paddingOf(context).top + 30,
                  left: 20,
                  right: 20,
                  child: Row(
                    // Top-aligned so the search panel can grow downward from a
                    // fixed upper edge; the profile icon is centered in the
                    // row height explicitly to keep its position as the row
                    // grows taller than the collapsed search box.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: _headerRowHeight(progress),
                        child: Center(
                          child: _ProfileIcon(size: _headerRowHeight(progress)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HomeSearchBox(
                          progress: progress,
                          focusNotifier: _searchFieldFocused,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            AnimatedBuilder(
              animation: _homeScrollController,
              builder: (context, _) {
                final position = _homeScrollController.hasClients
                    ? _homeScrollController.position
                    : null;
                final dragProgress = position != null && position.pixels < 0
                    ? (-position.pixels /
                              (position.viewportDimension * _pullToArmFraction))
                          .clamp(0.0, 1.0)
                    : 0.0;
                // Centered in the band between the floating header's bottom
                // edge and the greeting's top line, so it is clear of both.
                final topInset = MediaQuery.paddingOf(context).top;
                final bandTop = topInset + 30 + _floatingHeaderExpandedHeight;
                final bandBottom = topInset + 140 + _greetingLeadIn;
                final badgeTop =
                    (bandTop + bandBottom - HarmonyRefreshBadge.size) / 2;

                return Positioned(
                  top: badgeTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<RefreshIndicatorStatus?>(
                        valueListenable: _refreshStatus,
                        builder: (context, status, _) => HarmonyRefreshBadge(
                          status: status,
                          progress: dragProgress,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 5
        ? 'Good Night,'
        : hour < 12
        ? 'Good Morning,'
        : hour < 17
        ? 'Good Afternoon,'
        : hour < 21
        ? 'Good Evening,'
        : 'Good Night,';

    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.titleLarge;
    final fontSize = math.min(
      (baseStyle?.fontSize ?? 22) * 1.4,
      MediaQuery.sizeOf(context).width * 0.0805,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            greeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseStyle?.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          TypewriterText(
            phrases: _greetingPhrases,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    return AnimatedBuilder(
      animation: Listenable.merge([userLikedPlaylists, userCustomPlaylists]),
      builder: (context, _) {
        final entries = _buildQuickAccessEntries();

        if (entries.isEmpty) return const SizedBox.shrink();

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.55,
          children: [for (final entry in entries) _buildQuickAccessCard(entry)],
        );
      },
    );
  }

  List<_QuickAccessEntry> _buildQuickAccessEntries() {
    final entries = <_QuickAccessEntry>[
      _QuickAccessEntry(
        title: context.l10n!.offlineSongs,
        icon: FluentIcons.arrow_download_24_filled,
        onTap: () => context.go('/library/userSongs/offline'),
      ),
      _QuickAccessEntry(
        title: context.l10n!.likedSongs,
        icon: FluentIcons.heart_24_filled,
        onTap: () => context.go('/library/userSongs/liked'),
      ),
    ];

    final seenIds = <String>{};
    final playlistEntries = <_QuickAccessEntry>[];

    void addPlaylistEntry(Map playlist) {
      final id = playlist['ytid']?.toString();
      final title = playlist['title']?.toString();
      if (id == null || id.isEmpty || title == null || title.isEmpty) return;
      if (!seenIds.add(id)) return;

      final isAlbum = playlist['isAlbum'] == true;
      final cubeIcon = isAlbum
          ? FluentIcons.cd_16_regular
          : FluentIcons.text_bullet_list_24_filled;
      playlistEntries.add(
        _QuickAccessEntry(
          title: title,
          // Falls back to the first song's artwork for playlists the user
          // created without their own image.
          artwork: PlaylistUtils.resolvePlaylistArtwork(playlist),
          isAlbum: isAlbum,
          icon: cubeIcon,
          cubeIcon: cubeIcon,
          onTap: () => context.push(
            isAlbum
                ? NavigationManager.albumPath(context, id)
                : '/home/playlist/$id',
          ),
        ),
      );
    }

    final liked = userLikedPlaylists.value
        .where((playlist) => !isArtistPlaylist(playlist))
        .toList();

    for (final playlist in liked.reversed) {
      if (playlistEntries.length >= 2) break;
      if (playlist['isAlbum'] == true) continue;
      addPlaylistEntry(playlist);
    }

    if (playlistEntries.length < 2) {
      final custom = getUserCustomPlaylists()
        ..sort(
          (a, b) =>
              ((b['createdAt'] as int?) ?? 0) - ((a['createdAt'] as int?) ?? 0),
        );
      for (final playlist in custom) {
        if (playlistEntries.length >= 2) break;
        addPlaylistEntry(playlist);
      }
    }

    for (final playlist in liked.reversed) {
      if (playlistEntries.length >= 4) break;
      if (playlist['isAlbum'] != true) continue;
      addPlaylistEntry(playlist);
    }

    entries.addAll(playlistEntries);
    return entries;
  }

  Widget _buildQuickAccessCard(_QuickAccessEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;

    return _HarmonyCard(
      onTap: entry.onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            margin: const EdgeInsetsDirectional.only(start: 6),
            decoration: BoxDecoration(
              color: entry.artwork == null
                  ? colorScheme.primary.withValues(alpha: 0.14)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: entry.artwork == null
                ? Icon(entry.icon, color: colorScheme.primary, size: 22)
                : PlaylistArtwork(
                    playlistArtwork: entry.artwork,
                    playlistTitle: entry.title,
                    cubeIcon: entry.cubeIcon,
                    iconSize: 22,
                    size: 56,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              FluentIcons.chevron_right_20_regular,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      children: [
        SectionHeader(title: title, icon: icon),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildHorizontalCarousel({
    required double height,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    Offset beginOffset = const Offset(-0.08, 0),
    double focalItemExtent = 0,
  }) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final revealed = HarmonyReveal(
            beginOffset: beginOffset,
            child: itemBuilder(context, index),
          );
          if (focalItemExtent <= 0) return revealed;
          return _FocalCarouselItem(
            index: index,
            itemExtent: focalItemExtent,
            child: revealed,
          );
        },
      ),
    );
  }

  Widget _buildMadeForYouSection() {
    return AsyncLoader<List<dynamic>>(
      future: _madeForYouFuture,
      loadingWidget: const SizedBox.shrink(),
      builder: (context, playlists) {
        final items = playlists.whereType<Map>().take(20).toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return _buildSection(
          title: 'Made for you',
          icon: FluentIcons.star_24_filled,
          child: _buildHorizontalCarousel(
            height: 224,
            itemCount: items.length,
            focalItemExtent: 160,
            itemBuilder: (context, index) => _buildMadeForYouCard(items[index]),
          ),
        );
      },
    );
  }

  Widget _buildMadeForYouCard(Map playlist) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = playlist['title']?.toString() ?? '';
    final isAlbum = playlist['isAlbum'] == true;
    final id = playlist['ytid']?.toString() ?? '';

    return SizedBox(
      width: 152,
      child: _HarmonyCard(
        onTap: id.isEmpty
            ? null
            : () => context.push(
                isAlbum
                    ? NavigationManager.albumPath(context, id)
                    : '/home/playlist/$id',
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PlaylistArtwork(
                  playlistArtwork: playlist['image']?.toString(),
                  playlistTitle: title,
                  cubeIcon: isAlbum
                      ? FluentIcons.cd_16_regular
                      : FluentIcons.text_bullet_list_24_filled,
                  iconSize: 42,
                  size: 140,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.3,
                    ).copyWith(color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAlbum ? context.l10n!.album : context.l10n!.playlist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Same visual recipe as the Made for you card: identical shell, artwork
  // inset, corner radius and typography, with playback of the real release
  // row attached.
  Widget _buildNewReleaseCard(
    Map song,
    int index,
    List<Map> songs,
    String playlistTitle,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = song['title']?.toString() ?? '';
    final artist = song['artist']?.toString() ?? '';

    Future<void> play() async {
      await audioHandler.playPlaylistSong(
        playlist: {'title': playlistTitle, 'list': songs},
        songIndex: index,
      );
    }

    return SizedBox(
      width: 152,
      child: CurrentSongBuilder(
        songId: song['ytid']?.toString(),
        builder: (context, isCurrentSong, isPlaying) => _HarmonyCard(
          onTap: play,
          active: isCurrentSong,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: song['image']?.toString() ?? '',
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    memCacheWidth: 280,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                      ).copyWith(color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (song['artistVerified'] == true) ...[
                                const SizedBox(width: 5),
                                const VerifiedArtistBadge(size: 12),
                              ],
                            ],
                          ),
                        ),
                        if (isCurrentSong) ...[
                          const SizedBox(width: 6),
                          PlayingIndicatorBars(isPlaying: isPlaying),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJumpBackInSection() {
    return ValueListenableBuilder<List>(
      valueListenable: userRecentlyPlayed,
      builder: (context, recentlyPlayed, _) {
        final songs = recentlyPlayed.whereType<Map>().take(10).toList();
        if (songs.isEmpty) return const SizedBox.shrink();

        return _buildSection(
          title: 'Jump back in',
          icon: FluentIcons.history_24_filled,
          child: _buildHorizontalCarousel(
            height: 224,
            itemCount: songs.length,
            focalItemExtent: 160,
            itemBuilder: (context, index) =>
                _buildJumpBackCard(songs[index], index, songs),
          ),
        );
      },
    );
  }

  // Same visual recipe as the Made for you card: identical shell, artwork
  // inset, corner radius and typography, with playback of the real history
  // entry attached.
  Widget _buildJumpBackCard(Map song, int index, List<Map> songs) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = song['title']?.toString() ?? '';
    final artist = song['artist']?.toString() ?? '';

    Future<void> play() async {
      await audioHandler.playPlaylistSong(
        playlist: {'title': 'Jump back in', 'list': songs},
        songIndex: index,
      );
    }

    return SizedBox(
      width: 152,
      child: CurrentSongBuilder(
        songId: song['ytid']?.toString(),
        builder: (context, isCurrentSong, isPlaying) => _HarmonyCard(
          onTap: play,
          active: isCurrentSong,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PlaylistArtwork(
                    playlistArtwork: song['image']?.toString(),
                    playlistTitle: title,
                    cubeIcon: FluentIcons.music_note_1_24_regular,
                    iconSize: 42,
                    size: 140,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                      ).copyWith(color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (song['artistVerified'] == true) ...[
                                const SizedBox(width: 5),
                                const VerifiedArtistBadge(size: 12),
                              ],
                            ],
                          ),
                        ),
                        if (isCurrentSong) ...[
                          const SizedBox(width: 6),
                          PlayingIndicatorBars(isPlaying: isPlaying),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewReleasesSections() {
    return AsyncLoader<Map<String, List>>(
      future: _newReleasesFuture,
      loadingWidget: const SizedBox.shrink(),
      builder: (context, releases) {
        // Rows are driven purely by what the search API returned; a category
        // YouTube has nothing fresh for is simply left out.
        final rows = releases.entries
            .map(
              (entry) => MapEntry(
                entry.key,
                entry.value.whereType<Map>().take(20).toList(),
              ),
            )
            .where((entry) => entry.value.isNotEmpty)
            .toList();
        if (rows.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 24),
              _buildSection(
                title: rows[i].key,
                icon: FluentIcons.arrow_download_24_filled,
                child: _buildHorizontalCarousel(
                  height: 224,
                  focalItemExtent: 160,
                  itemCount: rows[i].value.length,
                  itemBuilder: (context, index) => _buildNewReleaseCard(
                    rows[i].value[index],
                    index,
                    rows[i].value,
                    rows[i].key,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRecentArtistsSection() {
    return AsyncLoader<List<Map<String, dynamic>>>(
      future: _recentArtistsFuture,
      loadingWidget: const SizedBox.shrink(),
      builder: (context, artists) {
        if (artists.isEmpty) return const SizedBox.shrink();

        return _buildSection(
          title: 'Based on your recent listening',
          icon: FluentIcons.person_24_regular,
          child: _buildRecentArtistRows(artists),
        );
      },
    );
  }

  /// The shelf spans two rows so it reads at a glance instead of as one long
  /// strip. The resolved artists are split in half rather than repeated, so
  /// the second row only ever carries real entries from the same history.
  Widget _buildRecentArtistRows(List<Map<String, dynamic>> artists) {
    final rowSize = (artists.length + 1) ~/ 2;
    final rows = <List<Map<String, dynamic>>>[];
    for (var start = 0; start < artists.length; start += rowSize) {
      rows.add(
        artists.sublist(start, math.min(start + rowSize, artists.length)),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildHorizontalCarousel(
            height: 76,
            itemCount: rows[i].length,
            itemBuilder: (context, index) =>
                _buildRecentArtistCard(rows[i][index]),
          ),
        ],
      ],
    );
  }

  Widget _buildRecentArtistCard(Map<String, dynamic> artist) {
    final colorScheme = Theme.of(context).colorScheme;
    final artistId = artist['ytid']?.toString() ?? '';

    return SizedBox(
      width: 200,
      child: ArtistBar(
        artist: artist,
        borderRadius: BorderRadius.circular(18),
        backgroundColor: getHarmonyCardColor(colorScheme),
        border: getHarmonyCardBorder(colorScheme),
        boxShadow: getHarmonyCardShadow(colorScheme),
        onTap: artistId.isEmpty
            ? () {}
            : () => context.push(
                NavigationManager.artistPath(context, artistId),
                extra: artist,
              ),
      ),
    );
  }

  Widget _buildSuggestedSongsSection() {
    return AsyncLoader<List<dynamic>>(
      future: _recommendedSongsFuture,
      loadingWidget: const SizedBox.shrink(),
      builder: (context, songs) {
        final suggested = songs.whereType<Map>().toList();
        if (suggested.isEmpty) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          children: [
            SectionHeader(
              title: 'Suggested Songs For You',
              icon: FluentIcons.sparkle_24_filled,
              actionButton: IconButton(
                icon: const Icon(FluentIcons.play_circle_24_filled),
                onPressed: () => audioHandler.playPlaylistSong(
                  playlist: {
                    'title': 'Suggested Songs For You',
                    'list': suggested,
                  },
                  songIndex: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < suggested.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RepaintBoundary(
                  key: listItemKey('home_suggested', index, suggested[index]),
                  child: HarmonyReveal(
                    child: SongBar(
                      suggested[index],
                      true,
                      backgroundColor: getHarmonyCardColor(colorScheme),
                      border: getHarmonyCardBorder(colorScheme),
                      boxShadow: getHarmonyCardShadow(colorScheme),
                      borderRadius: BorderRadius.circular(18),
                      barPadding: const EdgeInsetsDirectional.only(
                        top: 10,
                        bottom: 10,
                        start: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAccessEntry {
  const _QuickAccessEntry({
    required this.title,
    required this.onTap,
    this.icon = FluentIcons.book_24_regular,
    this.artwork,
    this.isAlbum = false,
    this.cubeIcon = FluentIcons.text_bullet_list_24_filled,
  });

  final String title;
  final VoidCallback onTap;
  final IconData icon;
  final String? artwork;
  final bool isAlbum;
  final IconData cubeIcon;
}

class _HarmonyCard extends StatelessWidget {
  const _HarmonyCard({required this.child, this.onTap, this.active = false});

  final Widget child;
  final VoidCallback? onTap;

  /// True while this card's song is the one playing; renders the accent
  /// stroke and glow of the Harmony playing card without changing geometry.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: getHarmonyCardColor(colorScheme),
        borderRadius: BorderRadius.circular(18),
        border: active
            ? getHarmonyActiveCardBorder(colorScheme)
            : getHarmonyCardBorder(colorScheme),
        boxShadow: active
            ? getHarmonyActiveCardShadow(colorScheme)
            : getHarmonyCardShadow(colorScheme),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: child,
        ),
      ),
    );
  }
}

/// Continuous cover-flow treatment for the horizontal home card carousels.
/// A card's scale, opacity and Y rotation are derived from how far its
/// center currently sits from the viewport's focal point, so the effect
/// tracks the scroll position directly — there is no per-card controller,
/// timer, or "waiting for the center" step. Only cards the ListView has
/// built (the visible ones plus a small cache) subscribe to scroll
/// notifications.
class _FocalCarouselItem extends StatelessWidget {
  const _FocalCarouselItem({
    required this.index,
    required this.itemExtent,
    required this.child,
  });

  final int index;
  final double itemExtent;
  final Widget child;

  /// Maximum Y rotation (degrees) applied to the outermost visible cards.
  static const _maxRotationDegrees = 12.0;

  @override
  Widget build(BuildContext context) {
    final position = Scrollable.of(context).position;

    return AnimatedBuilder(
      animation: position,
      builder: (context, child) {
        if (!position.hasContentDimensions || !position.hasViewportDimension) {
          return child!;
        }

        final viewportCenter = position.viewportDimension / 2;
        final itemCenter =
            (index * itemExtent) + (itemExtent / 2) - position.pixels;
        final offset =
            (itemCenter - viewportCenter) / (position.viewportDimension * 0.45);
        final t = offset.clamp(-1.0, 1.0);
        final amount = t.abs();
        final scale = lerpDouble(1.0, 0.85, amount)!;
        final opacity = lerpDouble(1.0, 0.6, amount)!;
        final rotation = -t * _maxRotationDegrees * math.pi / 180;

        return Opacity(
          opacity: opacity,
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(rotation),
            alignment: Alignment.center,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

// Geometry of the floating home header: the search box collapses from the
// expanded bar height down to a true circle of the collapsed height, while
// the profile icon beside it keeps the collapsed size at all times.
const double _floatingHeaderExpandedHeight = 56.0;
const double _floatingHeaderCollapsedHeight = 48.0;

/// Height of the header row at a given collapse amount. The profile icon is
/// centered in it, so this is also what keeps the icon aligned with the
/// search box at every point of the collapse. The open search panel grows
/// past this height, downward.
double _headerRowHeight(double progress) => lerpDouble(
  _floatingHeaderExpandedHeight,
  _floatingHeaderCollapsedHeight,
  progress.clamp(0.0, 1.0),
)!;

/// Standalone circular profile icon of the floating home header. Tapping it
/// opens the settings drawer; it subtly scales on press without moving the
/// surrounding layout.
class _ProfileIcon extends StatefulWidget {
  const _ProfileIcon({required this.size});

  final double size;

  @override
  State<_ProfileIcon> createState() => _ProfileIconState();
}

class _ProfileIconState extends State<_ProfileIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foxColor = colorScheme.brightness == Brightness.dark
        ? colorScheme.primary
        : colorScheme.onSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => settingsDrawerOpen.value = true,
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _pressController,
          builder: (context, child) => Transform.scale(
            scale: 1 + (0.06 * _pressController.value),
            child: child,
          ),
          child: Image.asset(
            'assets/icons/harmony_fox_foreground.png',
            color: foxColor,
            colorBlendMode: BlendMode.srcIn,
            filterQuality: FilterQuality.high,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// The search entry point of the floating home header, sitting beside the
/// profile icon in the same header row. The search tab keeps owning the
/// search itself: submitting here hands the query over to it.
class _HomeSearchBox extends StatefulWidget {
  const _HomeSearchBox({required this.progress, required this.focusNotifier});

  /// Scroll-driven collapse amount: 0 (expanded bar) to 1 (48dp circle).
  final double progress;

  /// Mirrors the field's focus, so the header can hold itself open while the
  /// keyboard is up instead of collapsing with the list beneath it.
  final ValueNotifier<bool> focusNotifier;

  @override
  State<_HomeSearchBox> createState() => _HomeSearchBoxState();
}

class _HomeSearchBoxState extends State<_HomeSearchBox>
    with SingleTickerProviderStateMixin {
  /// Search examples typed out while the field is idle and empty. The pool
  /// mixes music searches, artist-oriented phrases, and short quotes; the
  /// special phrase cycles in deterministically after every three of these.
  static const _normalExamples = <String>[
    'Arijit Singh',
    'Punjabi songs',
    'Diljit Dosanjh',
    'Lo-fi study beats',
    'Karan Aujla',
    'Sad songs',
    'AP Dhillon',
    'Bollywood hits',
    'Shubh',
    'Sufi music',
    'Sidhu Moose Wala',
    'Workout music',
    'Taylor Swift',
    'Monsoon melodies',
    'The Weeknd',
    '90s Bollywood',
    'Music is life',
    'Chill vibes',
    'Feel the beat',
    'Romantic songs',
    'Turn it up',
    'Party anthems',
    'Lost in melody',
    'Acoustic covers',
  ];

  static const _specialExample = 'Harmony By Aasif';

  /// Slot within the rotation: three normal phrases, then the special phrase.
  static const _specialSlot = 3;
  static const _cycleLength = _specialSlot + 1;

  static const _typeInterval = Duration(milliseconds: 90);
  static const _deleteInterval = Duration(milliseconds: 40);
  static const _holdInterval = Duration(milliseconds: 1600);
  static const _placeholderFade = Duration(milliseconds: 180);

  /// How long the expansion towards the open panel takes; the suggestion
  /// sheet only starts appearing in the second half of it.
  static const _expandDuration = Duration(milliseconds: 260);

  /// The open panel is about half of the available width, but never wider
  /// than the space the header actually has.
  static const _expandedWidthFactor = 0.5;
  static const _maxSuggestions = 4;
  static const _suggestionRowHeight = 42.0;
  static const _suggestionDebounce = Duration(milliseconds: 300);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _expandController = AnimationController(
    vsync: this,
    duration: _expandDuration,
  );

  /// One step of the placeholder animation runs at a time; the timer is only
  /// alive while the placeholder is on screen.
  Timer? _typingTimer;
  int _slotInCycle = 0;
  int _normalIndex = 0;
  int _typedLength = 0;
  bool _isTypingPlaceholder = false;
  bool _hasText = false;

  /// Live suggestions for the text currently in the field; kept empty while
  /// the field is empty so the panel shows search history instead.
  List<String> _suggestions = [];
  Timer? _suggestionTimer;

  /// Invalidates in-flight suggestion fetches: only the response matching the
  /// newest request may be applied.
  int _latestSuggestionRequest = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleFieldChanged);
    _focusNode.addListener(_handleFieldChanged);
    _isTypingPlaceholder = true;
    _typeNextCharacter();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _suggestionTimer?.cancel();
    _controller.removeListener(_handleFieldChanged);
    _focusNode.removeListener(_handleFieldChanged);
    _controller.dispose();
    _focusNode.dispose();
    _expandController.dispose();
    super.dispose();
  }

  /// The placeholder animates only while the field is empty and unfocused, so
  /// it never competes with the cursor or with what the user is typing.
  void _handleFieldChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }

    if (hasText || _focusNode.hasFocus) {
      _stopPlaceholder();
    } else {
      _startPlaceholder();
    }

    // The panel only grows while the field is focused; losing focus collapses
    // it and takes the suggestions with it.
    widget.focusNotifier.value = _focusNode.hasFocus;
    if (_focusNode.hasFocus) {
      unawaited(_expandController.forward());
    } else {
      _clearSuggestions();
      unawaited(_expandController.reverse());
    }
  }

  void _clearSuggestions() {
    _suggestionTimer?.cancel();
    _suggestionTimer = null;
    _latestSuggestionRequest++;
    if (_suggestions.isEmpty) return;
    setState(() => _suggestions = []);
  }

  /// Suggestions are only requested once the expansion has made room for
  /// them; the debounce and the request guard keep a fast typist from seeing
  /// stale results.
  void _handleQueryChanged(String value) {
    final query = value.trim();
    _suggestionTimer?.cancel();
    _suggestionTimer = null;
    final requestId = ++_latestSuggestionRequest;

    if (query.isEmpty) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }

    _suggestionTimer = Timer(_suggestionDebounce, () async {
      List<String> found;
      try {
        found = await getSearchSuggestions(query);
      } catch (error, stackTrace) {
        logger.log(
          'Error while fetching search suggestions',
          error: error,
          stackTrace: stackTrace,
        );
        return;
      }
      if (!mounted ||
          requestId != _latestSuggestionRequest ||
          _controller.text.trim() != query) {
        return;
      }
      setState(() => _suggestions = found.take(_maxSuggestions).toList());
    });
  }

  void _startPlaceholder() {
    if (_isTypingPlaceholder) return;
    setState(() {
      _isTypingPlaceholder = true;
      _typedLength = 0;
    });
    _typeNextCharacter();
  }

  void _stopPlaceholder() {
    _typingTimer?.cancel();
    _typingTimer = null;
    if (!_isTypingPlaceholder && _typedLength == 0) return;
    setState(() {
      _isTypingPlaceholder = false;
      _typedLength = 0;
    });
  }

  /// Deterministic rotation: three normal phrases, then the special phrase,
  /// repeating. Normal phrases walk the pool in order.
  String get _currentExample => _slotInCycle == _specialSlot
      ? _specialExample
      : _normalExamples[_normalIndex];

  void _advanceToNextSlot() {
    _slotInCycle = (_slotInCycle + 1) % _cycleLength;
    if (_slotInCycle != _specialSlot) {
      _normalIndex = (_normalIndex + 1) % _normalExamples.length;
    }
  }

  void _typeNextCharacter() {
    if (!mounted || !_isTypingPlaceholder) return;
    final example = _currentExample;

    if (_typedLength >= example.length) {
      _typingTimer = Timer(_holdInterval, _deletePlaceholder);
      return;
    }
    setState(() => _typedLength++);
    _typingTimer = Timer(_typeInterval, _typeNextCharacter);
  }

  void _deletePlaceholder() {
    if (!mounted || !_isTypingPlaceholder) return;

    if (_typedLength == 0) {
      setState(_advanceToNextSlot);
      _typingTimer = Timer(_typeInterval, _typeNextCharacter);
      return;
    }
    setState(() => _typedLength--);
    _typingTimer = Timer(_deleteInterval, _deletePlaceholder);
  }

  /// The special phrase highlights "Aasif" in the dynamic accent; every other
  /// phrase renders uniformly in the muted placeholder color.
  TextSpan _placeholderSpan(String typedText, ColorScheme colorScheme) {
    if (_slotInCycle == _specialSlot) {
      const marker = 'Aasif';
      final start = typedText.indexOf(marker);
      if (start >= 0) {
        final end = start + marker.length;
        return TextSpan(
          children: [
            TextSpan(text: typedText.substring(0, start)),
            TextSpan(
              text: marker,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: typedText.substring(end)),
          ],
        );
      }
    }
    return TextSpan(text: typedText);
  }

  void _submitQuery(String value) {
    final query = value.trim();
    if (query.isEmpty) return;

    _focusNode.unfocus();
    NavigationManager.router.go(NavigationManager.searchPath);
    pendingSearchQuery.value = query;
  }

  void _clearQuery() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _handleTap() {
    // Focus expands the bar where it is; the Home list keeps its exact
    // scroll position.
    _focusNode.requestFocus();
  }

  /// The sheet below the field: live suggestions while there is a query,
  /// otherwise the same stored search history the search tab shows.
  Widget _buildSuggestionsSheet(ColorScheme colorScheme) {
    if (_controller.text.trim().isNotEmpty) {
      return _buildSuggestionRows(_suggestions, colorScheme);
    }
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: searchHistoryNotifier,
      builder: (context, searchHistory, _) {
        final entries = searchHistory
            .map((entry) => entry.toString())
            .take(_maxSuggestions)
            .toList();
        return _buildSuggestionRows(entries, colorScheme);
      },
    );
  }

  Widget _buildSuggestionRows(List<String> entries, ColorScheme colorScheme) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: colorScheme.primary.withValues(alpha: 0.16),
        ),
        for (final entry in entries) _buildSuggestionRow(entry, colorScheme),
        const SizedBox(height: 6),
      ],
    );
  }

  /// The Home green-square icon language in a compact row: a tinted rounded
  /// square carrying the search glyph, then the query itself.
  Widget _buildSuggestionRow(String entry, ColorScheme colorScheme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _submitQuery(entry),
      child: SizedBox(
        height: _suggestionRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  FluentIcons.search_24_regular,
                  size: 12,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = widget.progress.clamp(0.0, 1.0);
    final rowHeight = _headerRowHeight(progress);
    final textStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface,
    );
    const iconSize = 18.0;
    const expandedIconOffset = 14.0;
    const expandedGap = 10.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final width = lerpDouble(
          fullWidth,
          _floatingHeaderCollapsedHeight,
          progress,
        )!;
        // The icon glides from its inset position toward the geometric
        // center of the ever-narrower shell and rests exactly centered once
        // the shell is the 48dp circle.
        final collapsedIconOffset = lerpDouble(
          expandedIconOffset,
          (width - iconSize) / 2,
          progress,
        )!;
        final gap = expandedGap * (1 - progress);
        // The text vanishes early in the collapse, long before the shell
        // becomes a circle.
        final fieldFade = (1 - progress / 0.4).clamp(0.0, 1.0);
        // The shell rounds off as it narrows; fully collapsed it is a true
        // circle (radius = half the collapsed height).
        final shellRadius = lerpDouble(
          16,
          _floatingHeaderCollapsedHeight / 2,
          progress,
        )!;

        return AnimatedBuilder(
          animation: _expandController,
          builder: (context, _) {
            // Focusing the field opens the box into a panel about half the
            // available width, anchored where the box already rests: the top
            // edge stays put while the panel grows downward and towards the
            // leading edge. The icon crosses to the trailing side, so the
            // text field starts where the icon used to sit.
            final expand = Curves.easeOutCubic.transform(
              _expandController.value,
            );
            final openWidth = math.min(
              MediaQuery.sizeOf(context).width * _expandedWidthFactor,
              fullWidth,
            );
            final panelWidth = lerpDouble(width, openWidth, expand)!;
            final iconOffset = lerpDouble(
              collapsedIconOffset,
              panelWidth - expandedIconOffset - iconSize,
              expand,
            )!;
            final collapsedFieldStart = collapsedIconOffset + iconSize + gap;
            final fieldStart = lerpDouble(
              collapsedFieldStart,
              expandedIconOffset,
              expand,
            )!;
            // The trailing inset mirrors the leading one once the icon has
            // moved over, so the field always stops short of it by the gap.
            final fieldEnd = lerpDouble(
              expandedIconOffset,
              collapsedFieldStart,
              expand,
            )!;
            final fieldWidth = (panelWidth - fieldStart - fieldEnd).clamp(
              0.0,
              double.infinity,
            );
            // The sheet only appears over the second half of the expansion,
            // so suggestions never show on a box that has not made room.
            final sheetAppear = ((_expandController.value - 0.5) / 0.5).clamp(
              0.0,
              1.0,
            );
            // An open panel always keeps the normal card corners instead of
            // following the collapse of the circle it grew out of.
            final radius = BorderRadius.circular(
              lerpDouble(shellRadius, 16, expand)!,
            );

            return Align(
              alignment: AlignmentDirectional.topEnd,
              child: SizedBox(
                width: panelWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleTap,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: getGlassSurfaceColor(colorScheme),
                          borderRadius: radius,
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: rowHeight,
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.only(
                                        start: fieldStart,
                                      ),
                                      child: SizedBox(
                                        width: fieldWidth,
                                        child: Opacity(
                                          opacity: fieldFade,
                                          child: ClipRect(
                                            child: Stack(
                                              alignment: AlignmentDirectional
                                                  .centerStart,
                                              children: [
                                                // A non-layout-affecting
                                                // layer, so typing the
                                                // placeholder out never moves
                                                // anything else.
                                                IgnorePointer(
                                                  child: AnimatedOpacity(
                                                    opacity:
                                                        _isTypingPlaceholder
                                                        ? 1
                                                        : 0,
                                                    duration: _placeholderFade,
                                                    child: Text.rich(
                                                      _placeholderSpan(
                                                        _currentExample
                                                            .substring(
                                                              0,
                                                              _typedLength,
                                                            ),
                                                        colorScheme,
                                                      ),
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: textStyle.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                TextField(
                                                  controller: _controller,
                                                  focusNode: _focusNode,
                                                  onChanged:
                                                      _handleQueryChanged,
                                                  onSubmitted: _submitQuery,
                                                  textInputAction:
                                                      TextInputAction.search,
                                                  cursorColor:
                                                      colorScheme.primary,
                                                  cursorOpacityAnimates: true,
                                                  style: textStyle,
                                                  maxLines: 1,
                                                  decoration:
                                                      const InputDecoration(
                                                        isCollapsed: true,
                                                        filled: false,
                                                        border:
                                                            InputBorder.none,
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                      ),
                                                ),
                                                if (_hasText)
                                                  Align(
                                                    alignment:
                                                        AlignmentDirectional
                                                            .centerEnd,
                                                    child: IconButton(
                                                      onPressed: _clearQuery,
                                                      icon: const Icon(
                                                        FluentIcons
                                                            .dismiss_circle_24_regular,
                                                      ),
                                                      iconSize: 16,
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints.tightFor(
                                                            width: 26,
                                                            height: 26,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  PositionedDirectional(
                                    start: iconOffset,
                                    top: (rowHeight - iconSize) / 2,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () =>
                                          _submitQuery(_controller.text),
                                      child: Icon(
                                        FluentIcons.search_24_regular,
                                        size: iconSize,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // The rows are revealed by the expansion itself:
                            // clipped to zero height until the box has opened
                            // far enough to hold them.
                            ClipRect(
                              child: Align(
                                heightFactor: _expandController.value,
                                alignment: Alignment.topCenter,
                                child: Opacity(
                                  opacity: sheetAppear,
                                  child: FractionalTranslation(
                                    translation: Offset(
                                      -0.05 * (1 - sheetAppear),
                                      0,
                                    ),
                                    child: _buildSuggestionsSheet(colorScheme),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

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
import 'dart:ui' show ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/artist_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/widgets/announcement_box.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_artwork.dart';
import 'package:musify/widgets/section_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List> _recommendedSongsFuture;
  late Future<List> _madeForYouFuture;
  late Future<List> _trendingSongsFuture;
  late Future<List<Map<String, dynamic>>> _recentArtistsFuture;
  final ScrollController _homeScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _recommendedSongsFuture = getRecommendedSongs();
    _madeForYouFuture = getPlaylists(playlistsNum: 8);
    _trendingSongsFuture = fetchSongsList('Punjabi trending songs');
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
      if (names.length >= 6) break;
    }

    final artists = <Map<String, dynamic>>[];
    for (final name in names) {
      try {
        final found = await searchVerifiedArtists(name, limit: 1);
        if (found.isNotEmpty) artists.add(found.first);
      } catch (_) {
        // Skip artists that fail to resolve; the section fills with what works.
      }
    }
    return artists;
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    externalRecommendations.removeListener(_refreshRecommendedSongs);
    super.dispose();
  }

  void _refreshRecommendedSongs() {
    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = getRecommendedSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _homeScrollController,
            physics: const BouncingScrollPhysics(),
            padding: commonSingleChildScrollViewPadding.copyWith(
              top: commonSingleChildScrollViewPadding.top + 108,
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
                const SizedBox(height: 12),
                _buildGreeting(),
                const SizedBox(height: 16),
                _buildQuickAccessGrid(),
                const SizedBox(height: 24),
                _buildMadeForYouSection(),
                const SizedBox(height: 24),
                _buildJumpBackInSection(),
                const SizedBox(height: 24),
                _buildTrendingSection(),
                const SizedBox(height: 24),
                _buildRecentArtistsSection(),
                const SizedBox(height: 24),
                _buildSuggestedSongsSection(),
                const MiniPlayerBottomSpace(),
              ],
            ),
          ),

          AnimatedBuilder(
            animation: _homeScrollController,
            builder: (context, child) {
              const collapseDistance = 90.0;
              final collapse =
                  (_homeScrollController.hasClients
                      ? _homeScrollController.offset
                      : 0.0) /
                  collapseDistance;
              final progress = collapse.clamp(0.0, 1.0);

              return Positioned(
                top: 30,
                left: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      height: 64 - (20 * progress),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * (1 - progress),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xB3222222),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.08),
                            blurRadius: 18,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              settingsDrawerOpen.value = true;
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/icons/kitsune_icon.png',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: 1 - progress,
                              child: Opacity(
                                opacity: 1 - progress,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Harmony By ',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        TextSpan(
                                          text: 'Aasif',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.green,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        greeting,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
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
      playlistEntries.add(
        _QuickAccessEntry(
          title: title,
          artwork: playlist['image']?.toString(),
          isAlbum: isAlbum,
          cubeIcon: isAlbum
              ? FluentIcons.cd_16_regular
              : FluentIcons.text_bullet_list_24_filled,
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
  }) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) =>
            _HorizontalReveal(child: itemBuilder(context, index)),
      ),
    );
  }

  Widget _buildMadeForYouSection() {
    return AsyncLoader<List<dynamic>>(
      future: _madeForYouFuture,
      loadingWidget: const SizedBox.shrink(),
      builder: (context, playlists) {
        final items = playlists.whereType<Map>().take(8).toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return _buildSection(
          title: 'Made for you',
          icon: FluentIcons.star_24_filled,
          child: _buildHorizontalCarousel(
            height: 224,
            itemCount: items.length,
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
                      color: Colors.white,
                    ),
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

  Widget _buildSongCarouselCard(
    Map song,
    int index,
    List<Map> songs,
    String playlistTitle,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    Future<void> play() async {
      await audioHandler.playPlaylistSong(
        playlist: {'title': playlistTitle, 'list': songs},
        songIndex: index,
      );
    }

    return SizedBox(
      width: 250,
      child: _HarmonyCard(
        onTap: play,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: song['image']?.toString() ?? '',
                width: 76,
                height: 76,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song['title']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    song['artist']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    FluentIcons.play_circle_24_filled,
                    size: 22,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
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
            height: 100,
            itemCount: songs.length,
            itemBuilder: (context, index) => _buildSongCarouselCard(
              songs[index],
              index,
              songs,
              'Jump back in',
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendingSection() {
    return AsyncLoader<List<dynamic>>(
      future: _trendingSongsFuture,
      loadingWidget: const SizedBox.shrink(),
      builder: (context, songs) {
        final trending = songs.whereType<Map>().take(10).toList();
        if (trending.isEmpty) return const SizedBox.shrink();

        return _buildSection(
          title: 'Trending Tracks',
          icon: FluentIcons.arrow_trending_24_filled,
          child: _buildHorizontalCarousel(
            height: 100,
            itemCount: trending.length,
            itemBuilder: (context, index) => _buildSongCarouselCard(
              trending[index],
              index,
              trending,
              'Trending Tracks',
            ),
          ),
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

        final colorScheme = Theme.of(context).colorScheme;

        return _buildSection(
          title: 'Based on your recent listening',
          icon: FluentIcons.person_24_regular,
          child: _buildHorizontalCarousel(
            height: 76,
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              final artistId = artist['ytid']?.toString() ?? '';

              return SizedBox(
                width: 250,
                child: ArtistBar(
                  artist: artist,
                  borderRadius: BorderRadius.circular(18),
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.72),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.16),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.10),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ],
                  onTap: artistId.isEmpty
                      ? () {}
                      : () => context.push(
                          NavigationManager.artistPath(context, artistId),
                          extra: artist,
                        ),
                ),
              );
            },
          ),
        );
      },
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
                  child: SongBar(
                    suggested[index],
                    true,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.72),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.16),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.10),
                        blurRadius: 14,
                        spreadRadius: 0,
                      ),
                    ],
                    borderRadius: BorderRadius.circular(18),
                    barPadding: const EdgeInsetsDirectional.only(
                      top: 10,
                      bottom: 10,
                      start: 12,
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
  const _HarmonyCard({required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.10),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

class _HorizontalReveal extends StatefulWidget {
  const _HorizontalReveal({required this.child});

  final Widget child;

  @override
  State<_HorizontalReveal> createState() => _HorizontalRevealState();
}

class _HorizontalRevealState extends State<_HorizontalReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ScrollPosition? _position;
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  void _setup() {
    if (!mounted) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) {
      _controller.forward();
      return;
    }
    _position = position..addListener(_evaluate);
    _evaluate();
  }

  void _evaluate() {
    if (!mounted || _controller.isAnimating || _controller.value == 1) return;

    final box = context.findRenderObject();
    final scrollableBox = Scrollable.maybeOf(context)?.context
        .findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    if (scrollableBox is! RenderBox || !scrollableBox.hasSize) return;

    final childLeft = box.localToGlobal(Offset.zero).dx;
    final childRight = childLeft + box.size.width;
    final viewportLeft = scrollableBox.localToGlobal(Offset.zero).dx;
    final viewportRight = viewportLeft + scrollableBox.size.width;

    if (childRight < viewportLeft) {
      _controller.value = 1;
      _removeListener();
      return;
    }
    if (childLeft > viewportRight) return;

    _direction = childLeft >= viewportLeft ? 1 : -1;
    _removeListener();
    _controller.forward();
  }

  void _removeListener() {
    _position?.removeListener(_evaluate);
    _position = null;
  }

  @override
  void dispose() {
    _removeListener();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: FractionalTranslation(
            translation: Offset(_direction * 0.08 * (1 - progress), 0),
            child: child,
          ),
        );
      },
    );
  }
}

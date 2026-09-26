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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/database/radio_stations.db.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/radio_model.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/harmony_dialogs.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/custom_search_bar.dart';
import 'package:musify/widgets/harmony_reveal.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/radio_station_card.dart';
import 'package:musify/widgets/section_title.dart';
import 'package:musify/widgets/song_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

// Global ValueNotifier for search history to make it reactive
final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  Hive.box('user').get('searchHistory', defaultValue: []),
);

/// Query handed over by a search entry point outside this page, e.g. the
/// floating search box of the home header. Consumed and cleared on arrival.
final ValueNotifier<String?> pendingSearchQuery = ValueNotifier<String?>(null);

void reloadSearchHistoryFromStorage() {
  searchHistoryNotifier.value = Hive.box('user')
      .get('searchHistory', defaultValue: []);
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  int maxSongsInList = 15;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<RadioStation> _radioStationsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSuggestionRequest = 0;
  int _latestSearchRequest = 0;

  Future<void> _submitSearch([String? query]) async {
    if (query != null) {
      _searchBar.text = query;
      _searchBar.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchBar.text.length),
      );
    }

    _latestSuggestionRequest++;
    _debounce?.cancel();
    _suggestionsList = [];
    if (mounted) setState(() {});

    await search();
    _inputNode.unfocus();
  }

  @override
  void initState() {
    super.initState();
    pendingSearchQuery.addListener(_consumePendingSearchQuery);
    // The query can be handed over before this page is first built into the
    // shell's indexed stack, so one is also picked up on the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingSearchQuery();
    });
  }

  @override
  void dispose() {
    pendingSearchQuery.removeListener(_consumePendingSearchQuery);
    _searchBar.dispose();
    _inputNode.dispose();
    _fetchingSongs.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _consumePendingSearchQuery() {
    final query = pendingSearchQuery.value;
    if (query == null) return;
    pendingSearchQuery.value = null;
    if (!mounted) return;
    unawaited(_submitSearch(query));
  }

  Future<void> search() async {
    final query = _searchBar.text.trim();
    final requestId = ++_latestSearchRequest;

    if (query.isEmpty) {
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _albumsSearchResult = [];
      _playlistsSearchResult = [];
      _radioStationsSearchResult = [];
      _suggestionsList = [];
      if (mounted) setState(() {});
      return;
    }
    _fetchingSongs.value = true;

    _songsSearchResult = [];
    _artistsSearchResult = [];
    _albumsSearchResult = [];
    _playlistsSearchResult = [];
    _radioStationsSearchResult = radioStationsDB
        .where(
          (station) =>
              station.name.toLowerCase().contains(query.toLowerCase()) ||
              (station.genre?.toLowerCase().contains(query.toLowerCase()) ??
                  false),
        )
        .toList();
    if (mounted) setState(() {});

    if (!searchHistoryNotifier.value.contains(query)) {
      final updatedHistory = List.from(searchHistoryNotifier.value)
        ..insert(0, query);
      searchHistoryNotifier.value = updatedHistory;
      unawaited(addOrUpdateData<List>('user', 'searchHistory', updatedHistory));
    }

    try {
      final artistsFuture = searchArtists(query);

      Future<void> publishSongs() async {
        try {
          var songs = await fetchSongsList(query);
          if (!mounted || requestId != _latestSearchRequest) return;

          if (songs.isEmpty) {
            final artists = await artistsFuture;
            if (!mounted || requestId != _latestSearchRequest) return;
            if (_artistsSearchResult.isEmpty) {
              _artistsSearchResult = artists
                  .whereType<Map>()
                  .map(Map<String, dynamic>.from)
                  .toList();
            }
            if (_artistsSearchResult.isNotEmpty) {
              songs = await _fetchSongsForResolvedArtist(query);
            }
          }

          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() => _songsSearchResult = songs);
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online songs',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      Future<void> publishArtists() async {
        try {
          final artists = await artistsFuture;
          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() {
            _artistsSearchResult = artists
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .toList();
          });
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online artists',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      Future<void> publishAlbums() async {
        try {
          final albums = await getPlaylists(query: query, type: 'album');
          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() => _albumsSearchResult = albums);
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online albums',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      Future<void> publishPlaylists() async {
        try {
          final playlists = await getPlaylists(query: query, type: 'playlist');
          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() => _playlistsSearchResult = playlists);
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online playlists',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      await Future.wait([
        publishSongs(),
        publishArtists(),
        publishAlbums(),
        publishPlaylists(),
      ]);
    } catch (e, stackTrace) {
      logger.log(
        'Error while searching online songs',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (requestId == _latestSearchRequest) {
        _fetchingSongs.value = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<List<dynamic>> _fetchSongsForResolvedArtist(String query) async {
    final artistName = _artistsSearchResult.first['title']?.toString().trim();
    if (artistName == null || artistName.isEmpty) return [];

    final fallbackQueries = <String>{
      if (artistName.toLowerCase() != query.trim().toLowerCase()) artistName,
      '$artistName songs',
      '$artistName music',
    };

    for (final fallbackQuery in fallbackQueries) {
      final songs = await fetchSongsList(fallbackQuery);
      if (songs.isNotEmpty) return songs;
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final searchCardSurface = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.72,
    );
    final searchCardBorder = Border.all(
      color: colorScheme.primary.withValues(alpha: 0.16),
      width: 1,
    );
    final searchCardShadow = <BoxShadow>[
      BoxShadow(
        color: colorScheme.primary.withValues(alpha: 0.10),
        blurRadius: 14,
        spreadRadius: 0,
      ),
    ];
    final searchCardRadius = BorderRadius.circular(18);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.search)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final bar = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 600 : double.infinity,
                  ),
                  child: CustomSearchBar(
                    loadingProgressNotifier: _fetchingSongs,
                    controller: _searchBar,
                    focusNode: _inputNode,
                    labelText: '${context.l10n!.search}...',
                    onChanged: (value) {
                      // debounce suggestions to avoid rapid API calls
                      _debounce?.cancel();
                      final query = value;
                      final requestId = ++_latestSuggestionRequest;

                      // Clear suggestions immediately if input is empty
                      if (query.isEmpty) {
                        _suggestionsList = [];
                        if (mounted) setState(() {});
                        return;
                      }

                      _debounce = Timer(
                        const Duration(milliseconds: 300),
                        () async {
                          final searchSuggestions = await getSearchSuggestions(
                            query,
                          );

                          if (!mounted ||
                              requestId != _latestSuggestionRequest ||
                              _searchBar.text != query) {
                            return;
                          }

                          _suggestionsList = List<String>.from(
                            searchSuggestions,
                          );
                          if (mounted) setState(() {});
                        },
                      );
                    },
                    onSubmitted: (String value) {
                      _submitSearch();
                    },
                  ),
                );
                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [bar],
                  );
                } else {
                  return bar;
                }
              },
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  (_suggestionsList.isNotEmpty ||
                      (_songsSearchResult.isEmpty &&
                          _artistsSearchResult.isEmpty &&
                          _albumsSearchResult.isEmpty &&
                          _playlistsSearchResult.isEmpty &&
                          _radioStationsSearchResult.isEmpty))
                  ? ValueListenableBuilder<List>(
                      valueListenable: searchHistoryNotifier,
                      builder: (context, searchHistory, _) {
                        final items = _suggestionsList.isEmpty
                            ? searchHistory
                            : _suggestionsList;

                        return Column(
                          key: ValueKey(
                            'history-${_suggestionsList.length}-${_searchBar.text}-${searchHistory.length}',
                          ),
                          children: [
                            for (int index = 0; index < items.length; index++)
                              Builder(
                                builder: (context) {
                                  final query = items[index];

                                  return _withCardGap(
                                    isLast: index == items.length - 1,
                                    child: HarmonyReveal(
                                      child: CustomBar(
                                        query,
                                        FluentIcons.search_24_regular,
                                        borderRadius: searchCardRadius,
                                        backgroundColor: searchCardSurface,
                                        border: searchCardBorder,
                                        boxShadow: searchCardShadow,
                                        onTap: () async {
                                          await _submitSearch(query.toString());
                                        },
                                        onLongPress: () async {
                                          final confirm =
                                              await _showConfirmationDialog(
                                                context,
                                              ) ??
                                              false;
                                          if (confirm &&
                                              searchHistory.contains(query)) {
                                            final updatedHistory = List.from(
                                              searchHistory,
                                            )..remove(query);
                                            searchHistoryNotifier.value =
                                                updatedHistory;
                                            unawaited(
                                              addOrUpdateData<List>(
                                                'user',
                                                'searchHistory',
                                                updatedHistory,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    )
                  : _buildSearchResults(
                      context,
                      primaryColor,
                      searchCardSurface,
                      searchCardBorder,
                      searchCardShadow,
                      searchCardRadius,
                    ),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _withCardGap({required bool isLast, required Widget child}) {
    return Padding(
      padding: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      child: child,
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    Color primaryColor,
    Color cardSurface,
    BoxBorder cardBorder,
    List<BoxShadow> cardShadow,
    BorderRadius cardRadius,
  ) {
    final widgets = <Widget>[];

    // Artists section
    if (_artistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.artists,
          primaryColor,
          icon: FluentIcons.person_24_filled,
        ),
      );

      final artists = _artistsSearchResult.take(3).toList();
      for (var index = 0; index < artists.length; index++) {
        final artist = Map<String, dynamic>.from(artists[index]);
        final artistId =
            artist['ytid']?.toString() ?? artist['title']?.toString() ?? '';
        if (artistId.isEmpty) continue;

        widgets.add(
          _withCardGap(
            isLast: index == artists.length - 1,
            child: HarmonyReveal(
              child: ArtistBar(
                key: listItemKey('search_artist', index, artist),
                artist: artist,
                borderRadius: cardRadius,
                backgroundColor: cardSurface,
                border: cardBorder,
                boxShadow: cardShadow,
                onTap: () {
                  context.push(
                    '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistId)}',
                    extra: artist,
                  );
                },
              ),
            ),
          ),
        );
      }
    }

    // Songs section
    if (_songsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.songs,
          primaryColor,
          icon: FluentIcons.music_note_1_24_filled,
        ),
      );

      final songsCount = _songsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _songsSearchResult.length;

      for (var index = 0; index < songsCount; index++) {
        final song = _songsSearchResult[index];
        widgets.add(
          _withCardGap(
            isLast: index == songsCount - 1,
            child: HarmonyReveal(
              child: SongBar(
                song,
                true,
                key: listItemKey('search_song', index, song),
                showMusicDuration: true,
                borderRadius: cardRadius,
                backgroundColor: cardSurface,
                border: cardBorder,
                boxShadow: cardShadow,
              ),
            ),
          ),
        );
      }
    }

    // Albums section
    if (_albumsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.albums,
          primaryColor,
          icon: FluentIcons.album_24_filled,
        ),
      );

      final albumsCount = _albumsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _albumsSearchResult.length;

      for (var index = 0; index < albumsCount; index++) {
        final playlist = _albumsSearchResult[index];

        widgets.add(
          _withCardGap(
            isLast: index == albumsCount - 1,
            child: HarmonyReveal(
              child: PlaylistBar(
                key: listItemKey('search_album', index, playlist),
                playlist['title'],
                playlistId: playlist['ytid'],
                playlistArtwork: playlist['image'],
                cubeIcon: FluentIcons.cd_16_filled,
                isAlbum: true,
                onPressed: () {
                  final playlistId = playlist['ytid']?.toString() ?? '';
                  if (playlistId.isEmpty) return;
                  context.push(
                    NavigationManager.albumPath(context, playlistId),
                  );
                },
                borderRadius: cardRadius,
                backgroundColor: cardSurface,
                border: cardBorder,
                boxShadow: cardShadow,
              ),
            ),
          ),
        );
      }
    }

    // Playlists section
    if (_playlistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.playlists,
          primaryColor,
          icon: FluentIcons.text_bullet_list_24_filled,
        ),
      );

      final playlistsCount = _playlistsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _playlistsSearchResult.length;

      for (var index = 0; index < playlistsCount; index++) {
        final playlist = _playlistsSearchResult[index];
        final isLast = index == playlistsCount - 1;

        widgets.add(
          Padding(
            padding: isLast
                ? commonListViewBottomPadding
                : const EdgeInsets.only(bottom: 10),
            child: HarmonyReveal(
              child: PlaylistBar(
                key: listItemKey('search_playlist', index, playlist),
                playlist['title'],
                playlistId: playlist['ytid'],
                playlistArtwork: playlist['image'],
                cubeIcon: FluentIcons.apps_list_24_filled,
                onPressed: () {
                  final playlistId = playlist['ytid']?.toString() ?? '';
                  if (playlistId.isEmpty) return;
                  context.push(
                    '${NavigationManager.searchPath}/playlist/${Uri.encodeComponent(playlistId)}',
                  );
                },
                borderRadius: cardRadius,
                backgroundColor: cardSurface,
                border: cardBorder,
                boxShadow: cardShadow,
              ),
            ),
          ),
        );
      }
    }

    // Radio Stations section
    if (_radioStationsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.radioStations,
          primaryColor,
          icon: FluentIcons.speaker_2_24_filled,
        ),
      );

      final stationsCount = _radioStationsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _radioStationsSearchResult.length;

      for (var index = 0; index < stationsCount; index++) {
        final station = _radioStationsSearchResult[index];
        final isLast = index == stationsCount - 1;

        widgets.add(
          Padding(
            padding: isLast
                ? commonListViewBottomPadding
                : const EdgeInsets.only(bottom: 10),
            child: HarmonyReveal(
              child: RadioStationCard(
                key: listItemKey('search_radio_station', index, station),
                station: station,
                borderRadius: cardRadius,
                backgroundColor: cardSurface,
                border: cardBorder,
                boxShadow: cardShadow,
                onPressed: () async {
                  final success = await audioHandler.playRadioStream(
                    id: station.id,
                    name: station.name,
                    streamUrl: station.streamUrl,
                    image: station.image,
                    genre: station.genre,
                  );
                  if (!success && context.mounted) {
                    showToast(context, context.l10n!.failedPlayingRadio);
                  }
                },
              ),
            ),
          ),
        );
      }
    }

    return Column(
      key: ValueKey(
        'results-${_songsSearchResult.length}-${_artistsSearchResult.length}-${_albumsSearchResult.length}-${_playlistsSearchResult.length}',
      ),
      children: widgets,
    );
  }

  Future<bool?> _showConfirmationDialog(BuildContext context) {
    return showHarmonyDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmationMessage: context.l10n!.removeSearchQueryQuestion,
          submitMessage: context.l10n!.confirm,
          onCancel: () {
            Navigator.of(context).pop(false);
          },
          onSubmit: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );
  }
}

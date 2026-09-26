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

import 'package:audio_service/audio_service.dart';
import 'package:musify/services/settings_manager.dart';

/// The artist a now playing item points at, as far as the item itself knows.
typedef NowPlayingArtist = ({
  String artist,
  String artistId,
  String sourceSongId,
  String videoAuthor,
});

NowPlayingArtist extractNowPlayingArtist(MediaItem metadata) {
  return (
    artist: metadata.artist?.trim() ?? '',
    artistId: metadata.extras?['artistId']?.toString().trim() ?? '',
    sourceSongId: metadata.extras?['ytid']?.toString().trim() ?? '',
    videoAuthor: metadata.extras?['videoAuthor']?.toString().trim() ?? '',
  );
}

/// The id the artist page is opened with: the channel when the item carries
/// one, otherwise the artist name, otherwise the song it was opened from.
String nowPlayingArtistLookup(NowPlayingArtist info) {
  if (info.artistId.isNotEmpty) return info.artistId;
  if (info.artist.isNotEmpty) return info.artist;
  return info.sourceSongId;
}

/// Whether the artist page can be reached from this item right now. Offline
/// the artist is only its downloaded songs, so there is nothing to open.
bool canOpenNowPlayingArtist(MediaItem metadata) {
  return !offlineMode.value &&
      nowPlayingArtistLookup(extractNowPlayingArtist(metadata)).isNotEmpty;
}

/// The seed handed to the artist page, so it shows the right artist before its
/// own lookup answers.
Map<String, dynamic> nowPlayingArtistSeed(NowPlayingArtist info) {
  final lookup = nowPlayingArtistLookup(info);
  return {
    'ytid': info.artistId.isNotEmpty ? info.artistId : lookup,
    if (info.artist.isNotEmpty) 'title': info.artist,
    if (info.sourceSongId.isNotEmpty) 'sourceSongId': info.sourceSongId,
    if (info.videoAuthor.isNotEmpty) 'videoAuthor': info.videoAuthor,
    // The artist id is the song's real channel id, so the page may trust it
    // when its fallback name search would otherwise reject the artist.
    'isVerifiedArtist': info.artistId.isNotEmpty,
    'source': 'youtube-artist',
    'isArtist': true,
    'list': [],
  };
}

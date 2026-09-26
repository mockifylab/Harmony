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

/// Spotify-inspired presentation tokens. Playback, downloads, and data
/// layers do not depend on these values.
abstract final class SpotifyColors {
  static const background = Color(0xFF121212);
  static const card = Color(0xFF181818);
  static const elevated = Color(0xFF282828);
  static const green = Color(0xFF1DB954);

  /// Darker sibling of [green] used for accents and text on light (cream)
  /// surfaces, where [green] itself lacks contrast.
  static const deepGreen = Color(0xFF127A42);
  static const muted = Color(0xFFB3B3B3);
  static const white = Color(0xFFFFFFFF);
}

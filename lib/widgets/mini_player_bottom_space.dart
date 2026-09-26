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
import 'package:musify/main.dart';
import 'package:musify/widgets/mini_player.dart';

/// Height of the floating navigation bar, measured from the bottom edge of
/// the screen to the bar's top edge (excluding the system inset).
const double _bottomBarHeight = 10 + 64;

/// Gap the mini player leaves between itself and the navigation bar.
const double _playerGap = 80 - _bottomBarHeight;

/// Breathing room kept under the last item so it does not sit flush against
/// the floating chrome.
const double _clearance = 12;

double _chromeHeight(BuildContext context, bool hasMediaItem) {
  final bottomInset = MediaQuery.paddingOf(context).bottom;
  final chromeTop = hasMediaItem
      ? _bottomBarHeight + _playerGap + MiniPlayer.playerHeight
      : _bottomBarHeight;
  return chromeTop + _clearance + bottomInset;
}

/// Reserves the vertical space the floating mini player and navigation bar
/// occupy, so the last item of a scrollable column stays visible above them.
class MiniPlayerBottomSpace extends StatelessWidget {
  const MiniPlayerBottomSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      initialData: audioHandler.mediaItem.value != null,
      stream: audioHandler.mediaItem.map((item) => item != null).distinct(),
      builder: (context, snapshot) {
        return SizedBox(
          height: _chromeHeight(context, snapshot.data ?? false),
        );
      },
    );
  }
}

/// Sliver variant of [MiniPlayerBottomSpace] for custom scroll views.
class SliverMiniPlayerBottomSpace extends StatelessWidget {
  const SliverMiniPlayerBottomSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      initialData: audioHandler.mediaItem.value != null,
      stream: audioHandler.mediaItem.map((item) => item != null).distinct(),
      builder: (context, snapshot) {
        return SliverToBoxAdapter(
          child: SizedBox(
            height: _chromeHeight(context, snapshot.data ?? false),
          ),
        );
      },
    );
  }
}

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
 */

import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/widgets/playlist_cube.dart';

class PlaylistHeroArtwork extends StatelessWidget {
  const PlaylistHeroArtwork(
    this.playlist, {
    super.key,
    this.cubeIcon = FluentIcons.text_bullet_list_24_filled,
    this.styled = false,
  });

  final Map playlist;
  final IconData cubeIcon;

  /// Renders as a square 18px-rounded card with the green edge and glow
  /// instead of the multi-point star clip.
  final bool styled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.sizeOf(context);
        final preferredSize = screenSize.width > screenSize.height
            ? 240.0
            : screenSize.width / (commonPlaylistArtworkDivision - 0.1);
        final size = preferredSize
            .clamp(0.0, min(constraints.maxWidth, constraints.maxHeight))
            .toDouble();
        final artwork = PlaylistCube(
          playlist,
          size: size,
          cubeIcon: cubeIcon,
          borderRadius: styled ? 18 : 16,
          showTypeLabel: false,
        );

        if (styled) {
          final colorScheme = Theme.of(context).colorScheme;
          final radius = BorderRadius.circular(18);
          return Container(
            decoration: BoxDecoration(
              color: getHarmonyCardColor(colorScheme),
              borderRadius: radius,
              border: getHarmonyCardBorder(colorScheme),
              boxShadow: getHarmonyCardShadow(colorScheme),
            ),
            child: ClipRRect(borderRadius: radius, child: artwork),
          );
        }

        return ClipPath(
          clipper: const ShapeBorderClipper(
            shape: StarBorder(
              points: 8,
              pointRounding: 0.8,
              valleyRounding: 0.2,
              innerRadiusRatio: 0.6,
            ),
          ),
          child: artwork,
        );
      },
    );
  }
}

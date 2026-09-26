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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/models/radio_model.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/widgets/shapes/eight_leaf_clover_shape.dart';

class RadioStationCard extends StatefulWidget {
  const RadioStationCard({
    super.key,
    required this.station,
    required this.onPressed,
    this.onFavoritesChanged,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final RadioStation station;
  final VoidCallback onPressed;
  final VoidCallback? onFavoritesChanged;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final BorderRadius borderRadius;

  @override
  State<RadioStationCard> createState() => _RadioStationCardState();
}

class _RadioStationCardState extends State<RadioStationCard> {
  late final ValueNotifier<bool> _isFavorited = ValueNotifier<bool>(
    isRadioStationLiked(widget.station.id),
  );

  @override
  void initState() {
    super.initState();
    userLikedRadioStations.addListener(_onFavoritesUpdated);
  }

  void _onFavoritesUpdated() {
    final newStatus = isRadioStationLiked(widget.station.id);
    if (_isFavorited.value != newStatus) {
      _isFavorited.value = newStatus;
    }
  }

  @override
  void dispose() {
    userLikedRadioStations.removeListener(_onFavoritesUpdated);
    _isFavorited.dispose();
    super.dispose();
  }

  Future<void> _handleFavoriteTap() async {
    final wasFavorited = _isFavorited.value;
    _isFavorited.value = !wasFavorited;

    try {
      if (wasFavorited) {
        await removeRadioStationFromLiked(widget.station.id);
      } else {
        await addRadioStationToLiked(widget.station.id);
      }
      widget.onFavoritesChanged?.call();
    } catch (e) {
      _isFavorited.value = wasFavorited; // revert on failure
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? colorScheme.surfaceContainer,
        borderRadius: widget.borderRadius,
        border: widget.border,
        boxShadow: widget.boxShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image(
                  image: ArtworkProvider.get(widget.station.image),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 56,
                    height: 56,
                    color: colorScheme.primaryContainer,
                    child: Icon(
                      FluentIcons.sound_source_24_regular,
                      color: colorScheme.onPrimaryContainer,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.station.name,
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.station.genre ?? 'Radio Station',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              ValueListenableBuilder<bool>(
                valueListenable: _isFavorited,
                builder: (context, isFavorited, _) {
                  return IconButton(
                    onPressed: _handleFavoriteTap,
                    icon: Icon(
                      isFavorited
                          ? FluentIcons.heart_24_filled
                          : FluentIcons.heart_24_regular,
                      size: 18,
                    ),
                    style:
                        getHarmonyCircleActionStyle(
                          colorScheme,
                          active: isFavorited,
                        ).copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                            Size(36, 36),
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                  );
                },
              ),
              const SizedBox(width: 5),
              EightLeafClover(
                size: 48,
                color: colorScheme.secondaryContainer,
                onTap: widget.onPressed,
                child: Icon(
                  FluentIcons.play_24_filled,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

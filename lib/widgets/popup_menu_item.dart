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
import 'package:musify/theme/app_themes.dart';

/// Creates a PopupMenuItem with consistent icon + label styling
PopupMenuItem<T> buildPopupMenuItem<T>({
  required T value,
  required IconData icon,
  required String label,
  required ColorScheme colorScheme,
  Color? iconColor,
  TextStyle? labelStyle,
  double iconSize = 24,
  double spacing = 8,
}) {
  return PopupMenuItem<T>(
    value: value,
    child: Row(
      children: [
        Icon(icon, color: iconColor ?? colorScheme.primary, size: iconSize),
        SizedBox(width: spacing),
        Text(
          label,
          style: labelStyle ?? TextStyle(color: colorScheme.onSurface),
        ),
      ],
    ),
  );
}

/// Separator between menu sections, wearing the same subtle accent stroke as
/// the Harmony list cards.
PopupMenuDivider buildPopupMenuDivider(ColorScheme colorScheme) {
  return PopupMenuDivider(
    height: 13,
    indent: 12,
    endIndent: 12,
    color: getHarmonyCardBorder(colorScheme).top.color,
  );
}

/// Inserts a [buildPopupMenuDivider] before the first entry of every section
/// listed in [startsSection], keeping the original order untouched.
List<PopupMenuEntry<T>> buildPopupMenuSections<T>(
  ColorScheme colorScheme,
  List<PopupMenuEntry<T>> items, {
  required Set<T> startsSection,
}) {
  final result = <PopupMenuEntry<T>>[];
  for (final item in items) {
    final value = item is PopupMenuItem<T> ? item.value : null;
    if (value != null && startsSection.contains(value) && result.isNotEmpty) {
      result.add(buildPopupMenuDivider(colorScheme));
    }
    result.add(item);
  }
  return result;
}

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

import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/screens/bottom_navigation_page.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/widgets/harmony_popup_controller.dart';
import 'package:musify/widgets/mini_player.dart';

/// Space kept between the menu's bottom edge and whatever bar sits below it:
/// the Mini Player when present, otherwise the bottom navigation bar.
const double _kMiniPlayerClearance = 4;

/// The framework's own screen inset for popup menus.
const double _kMenuScreenInset = 8;

/// Vertical padding the framework puts around the menu's entries.
const double _kMenuVerticalPadding = 16;

/// Width range the framework gives popup menus. Repeated here because passing
/// custom [BoxConstraints] replaces those defaults, and only the height is
/// meant to be constrained below.
const BoxConstraints _kMenuWidth = BoxConstraints(minWidth: 112, maxWidth: 280);

/// Three-dot trigger for the Harmony card menus. The menu wears the app's card
/// chrome and is laid out so the Mini Player can never cover it.
class OverflowMenuButton<T> extends StatefulWidget {
  const OverflowMenuButton({
    super.key,
    required this.onSelected,
    required this.itemBuilder,
    this.icon,
    this.iconSize = 24,
    this.color,
  });

  final void Function(T value) onSelected;
  final List<PopupMenuEntry<T>> Function(BuildContext context) itemBuilder;

  final IconData? icon;
  final double iconSize;
  final Color? color;

  @override
  State<OverflowMenuButton<T>> createState() => _OverflowMenuButtonState<T>();
}

class _OverflowMenuButtonState<T> extends State<OverflowMenuButton<T>> {
  bool _isMenuExpanded = false;

  /// The menu's height is known before it is laid out, which is what lets it
  /// be anchored above the Mini Player without overlapping it.
  double _estimatedHeight(List<PopupMenuEntry<T>> items) {
    var height = _kMenuVerticalPadding;
    for (final item in items) {
      if (item is PopupMenuItem) {
        height += item.height;
      } else if (item is PopupMenuDivider) {
        height += item.height;
      } else {
        height += kMinInteractiveDimension;
      }
    }
    return height;
  }

  Future<void> _showMenu() async {
    final overlay = Navigator.of(context).overlay;
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    final buttonBox = context.findRenderObject() as RenderBox?;
    if (overlay == null || overlayBox == null || buttonBox == null) return;

    final items = widget.itemBuilder(context);
    if (items.isEmpty) return;

    final colorScheme = Theme.of(context).colorScheme;
    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final buttonBottomRight = buttonBox.localToGlobal(
      buttonBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );

    var top = buttonTopLeft.dy;
    BoxConstraints? constraints;

    // The closest bar below the button bounds the menu: the Mini Player when
    // one is visible (it sits above the navbar), otherwise the navbar itself.
    double? obstructionTop;
    final miniPlayer = MiniPlayer.currentBounds();
    if (miniPlayer != null) {
      obstructionTop = miniPlayer.topLeft.dy;
    }
    final navbar = BottomNavigationPage.bottomBarBounds();
    if (navbar != null) {
      final navbarTop = navbar.topLeft.dy;
      obstructionTop = obstructionTop == null
          ? navbarTop
          : math.min(obstructionTop, navbarTop);
    }
    if (obstructionTop != null) {
      final clearance =
          overlayBox.globalToLocal(Offset(0, obstructionTop)).dy -
          _kMiniPlayerClearance;
      top = math.min(top, clearance - _estimatedHeight(items));
      top = math.max(
        top,
        _kMenuScreenInset + MediaQuery.paddingOf(overlay.context).top,
      );
      constraints = _kMenuWidth.copyWith(
        maxHeight: math.max(0, clearance - top),
      );
    }

    setState(() => _isMenuExpanded = true);

    // Let the centralized root pointer listener close this menu the instant the
    // user starts a meaningful swipe, since the modal barrier would otherwise
    // swallow the drag and leave the menu floating over scrolling content.
    final navigator = Navigator.of(context);
    void dismissOpenMenu() {
      if (mounted && _isMenuExpanded && navigator.canPop()) {
        navigator.pop();
      }
    }

    HarmonyPopupController.instance.register(dismissOpenMenu);
    T? value;
    try {
      value = await showMenu<T>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromPoints(
            Offset(buttonTopLeft.dx, top),
            Offset(buttonBottomRight.dx, top + buttonBox.size.height),
          ),
          Offset.zero & overlayBox.size,
        ),
        constraints: constraints,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: getHarmonyCardBorder(colorScheme).top,
        ),
        color: Color.alphaBlend(
          getHarmonyCardColor(colorScheme),
          colorScheme.surface,
        ),
        elevation: 6,
        shadowColor: getHarmonyCardShadow(colorScheme).first.color,
        surfaceTintColor: Colors.transparent,
        menuPadding: const EdgeInsets.symmetric(vertical: 8),
        clipBehavior: Clip.antiAlias,
        popUpAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        ),
        items: items,
      );
    } finally {
      HarmonyPopupController.instance.unregister(dismissOpenMenu);
    }
    if (!mounted) return;
    setState(() => _isMenuExpanded = false);
    if (value != null) widget.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      padding: EdgeInsets.zero,
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onPressed: _showMenu,
      icon: Semantics(
        expanded: _isMenuExpanded,
        child: Icon(
          widget.icon ?? FluentIcons.more_vertical_24_regular,
          size: widget.iconSize,
          color: widget.color ?? colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

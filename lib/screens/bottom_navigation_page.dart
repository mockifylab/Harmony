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

import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/settings_page.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart'
    show closeCurrentBottomSheet;
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/widgets/mini_player.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({required this.child, super.key});

  final StatefulNavigationShell child;

  /// Geometry of the bottom bar, so popup menus can be kept above it. Null
  /// on large screens, where navigation is a rail instead of a bottom bar.
  static final GlobalKey bottomBarKey = GlobalKey();

  static Rect? bottomBarBounds() {
    final box =
        bottomBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  late final _miniPlayerVisibilityStream = audioHandler.mediaItem
      .map((mediaItem) => mediaItem != null)
      .distinct();

  bool? _previousOfflineMode;

  /// Track the previously selected shell branch to detect reselects.
  int? _previousShellIndex;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.child.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final currentIndex = widget.child.currentIndex;
        if (currentIndex != 0) {
          widget.child.goBranch(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: offlineMode,
        builder: (context, isOfflineMode, _) {
          if (_previousOfflineMode != null &&
              _previousOfflineMode != isOfflineMode) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _handleOfflineModeChange(isOfflineMode);
            });
          }
          _previousOfflineMode = isOfflineMode;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = MediaQuery.of(context).size.width >= 600;
              final items = _getNavigationItems(isOfflineMode);

              return Scaffold(
                body: Row(
                  children: [
                    if (isLargeScreen)
                      SafeArea(
                        right: false,
                        child: NavigationRail(
                          labelType: NavigationRailLabelType.selected,
                          destinations: items
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: Icon(item.icon),
                                  selectedIcon: Icon(item.selectedIcon),
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                          selectedIndex: _getCurrentIndex(items, isOfflineMode),
                          onDestinationSelected: (index) =>
                              _onTabTapped(index, items),
                        ),
                      ),
                    Expanded(
                      child: StreamBuilder<bool>(
                        initialData: audioHandler.mediaItem.value != null,
                        stream: _miniPlayerVisibilityStream,
                        builder: (context, snapshot) {
                          final mediaQuery = MediaQuery.of(context);
                          final bottomInset = mediaQuery.padding.bottom;
                          return ValueListenableBuilder<bool>(
                            valueListenable: settingsDrawerOpen,
                            builder: (context, isSettingsOpen, _) {
                              return Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    transform: Matrix4.translationValues(
                                      isSettingsOpen ? 58.0 : 0.0,
                                      0,
                                      0,
                                    ),
                                    child: Stack(
                                      children: [
                                        MediaQuery(
                                          data: mediaQuery,
                                          child: widget.child,
                                        ),
                                        Positioned(
                                          left: 20,
                                          right: 20,
                                          bottom: 80 + bottomInset,
                                          child: const MiniPlayer(),
                                        ),
                                        if (!isLargeScreen)
                                          Positioned(
                                            left: 20,
                                            right: 20,
                                            bottom: 10 + bottomInset,
                                            child: _ModernBottomBar(
                                              items: items,
                                              selectedIndex: _getCurrentIndex(
                                                items,
                                                isOfflineMode,
                                              ),
                                              onTap: (index) =>
                                                  _onTabTapped(index, items),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSettingsOpen)
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTap: () =>
                                            settingsDrawerOpen.value = false,
                                        child: Container(
                                          color: Colors.black.withValues(
                                            alpha: 0.58,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: constraints.maxWidth - 58,
                                    child: AnimatedSlide(
                                      offset: isSettingsOpen
                                          ? Offset.zero
                                          : const Offset(-1, 0),
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      child: SettingsPage(
                                        isOpen: isSettingsOpen,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<_NavigationItem> _getNavigationItems(bool isOfflineMode) {
    final items = <_NavigationItem>[
      _NavigationItem(
        icon: FluentIcons.home_24_regular,
        selectedIcon: FluentIcons.home_24_filled,
        label: context.l10n?.home ?? 'Home',
        shellIndex: 0,
      ),
    ];

    // Only add search tab in online mode
    if (!isOfflineMode) {
      items.add(
        _NavigationItem(
          icon: FluentIcons.search_24_regular,
          selectedIcon: FluentIcons.search_24_filled,
          label: context.l10n?.search ?? 'Search',
          shellIndex: 1,
        ),
      );
    }

    items.addAll([
      _NavigationItem(
        icon: FluentIcons.library_24_regular,
        selectedIcon: FluentIcons.library_24_filled,
        label: context.l10n?.library ?? 'Library',
        shellIndex: 2,
      ),
      const _NavigationItem(
        icon: FluentIcons.add_24_regular,
        selectedIcon: FluentIcons.add_24_filled,
        label: 'Create Playlist',
        isAction: true,
      ),
      const _NavigationItem(
        icon: FluentIcons.history_24_regular,
        selectedIcon: FluentIcons.history_24_filled,
        label: 'History',
        isHistory: true,
      ),
    ]);

    return items;
  }

  void _handleOfflineModeChange(bool isOfflineMode) {
    if (!mounted) return;

    final currentRoute = GoRouterState.of(context).matchedLocation;

    // If we're switching to offline mode and currently on search tab
    if (isOfflineMode && currentRoute.startsWith('/search')) {
      // Navigate to home
      widget.child.goBranch(0);
    }
  }

  void _onTabTapped(int index, List<_NavigationItem> items) {
    if (index < items.length) {
      final item = items[index];

      // Subtle selection tick; deliberately not a long press feedback.
      HapticFeedback.selectionClick();

      // Close any open bottom sheet before handling the action.
      closeCurrentBottomSheet();

      if (item.isAction) {
        showCreatePlaylistDialog(context);
        return;
      }

      if (item.isHistory) {
        context.push('/home/timeMachine');
        return;
      }

      final shellIndex = item.shellIndex;
      if (shellIndex == null) return;

      final isReselect = _previousShellIndex == shellIndex;

      // If user taps the same tab again, reset it to initial state.
      // Otherwise, preserve the branch state.
      if (isReselect) {
        widget.child.goBranch(shellIndex, initialLocation: true);
      } else {
        widget.child.goBranch(shellIndex);
      }

      _previousShellIndex = shellIndex;
    }
  }

  int _getCurrentIndex(List<_NavigationItem> items, bool isOfflineMode) {
    final currentShellIndex = widget.child.currentIndex;

    if (items.isEmpty) return 0;

    final currentLocation = GoRouterState.of(context).uri.toString();
    final historyIndex = items.indexWhere((item) => item.isHistory);

    if (historyIndex != -1 && currentLocation.startsWith('/home/timeMachine')) {
      return historyIndex;
    }

    // Try to find the current shell index in the available items
    final matchedIndex = items.indexWhere(
      (item) => item.shellIndex == currentShellIndex,
    );
    if (matchedIndex != -1) return matchedIndex;

    // If the Search branch (1) is active but Search is hidden in offline mode,
    // fall back to the Home tab.
    if (isOfflineMode && currentShellIndex == 1) return 0;

    // Final fallback: return the first tab to keep UI in a valid state.
    return 0;
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.shellIndex,
    this.isAction = false,
    this.isHistory = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? shellIndex;
  final bool isAction;
  final bool isHistory;
}

class _ModernBottomBar extends StatelessWidget {
  const _ModernBottomBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      key: BottomNavigationPage.bottomBarKey,
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: getGlassSurfaceColor(colorScheme),
            borderRadius: BorderRadius.circular(16),
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
          child: Material(
            color: Colors.transparent,
            child: Row(
              children: List.generate(items.length, (index) {
                return Expanded(
                  child: _ModernNavItem(
                    item: items[index],
                    selected: index == selectedIndex,
                    onTap: () => onTap(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernNavItem extends StatelessWidget {
  const _ModernNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: selected ? const Alignment(0, -0.28) : Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 25,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: selected
                      ? TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 8 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 1,
                              left: 2,
                              right: 2,
                            ),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

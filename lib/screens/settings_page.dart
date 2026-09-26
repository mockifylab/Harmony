import 'dart:ui';
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
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/harmony_dialogs.dart';
import 'package:musify/utilities/language_utils.dart';
import 'package:musify/widgets/bottom_sheet_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/section_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.isOpen});

  final bool isOpen;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final ScrollController _settingsScrollController;

  @override
  void initState() {
    super.initState();
    _settingsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _settingsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: getSettingsGlassColor(colorScheme),
            border: Border(
              right: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
          ),
          child: SingleChildScrollView(
            controller: _settingsScrollController,
            padding: EdgeInsets.fromLTRB(
              18,
              MediaQuery.paddingOf(context).top + 18,
              18,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildSettingsHeader(context),
                const SizedBox(height: 22),
                _buildPreferencesSection(
                  context,
                  colorScheme.primary,
                  colorScheme.secondaryContainer,
                  colorScheme.surfaceContainerHigh,
                ),
                _buildOnlineFeaturesSection(context),
                const SizedBox(height: 20),
                const MiniPlayerBottomSpace(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(
    BuildContext context,
    Color primaryColor,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    return Container(
      child: Column(
        children: [
          SectionHeader(
            title: context.l10n!.preferences,
            icon: FluentIcons.options_24_filled,
          ),
          _buildKitsuneSettingCard(
            context,
            title: context.l10n!.themeMode,
            icon: FluentIcons.weather_sunny_28_regular,
            onTap: () => _showThemeModePicker(context),
          ),
          _buildKitsuneSettingCard(
            context,
            title: context.l10n!.language,
            icon: FluentIcons.translate_24_regular,
            onTap: () => _showLanguagePicker(context),
          ),
          _buildKitsuneSettingCard(
            context,
            title: context.l10n!.audioQuality,
            icon: FluentIcons.music_note_1_24_regular,
            onTap: () => _showAudioQualityPicker(context),
          ),
          _buildKitsuneSettingCard(
            context,
            title: context.l10n!.equalizer,
            icon: FluentIcons.data_histogram_24_regular,
            onTap: () => context.push('/settings/equalizer'),
          ),
          if (themeMode == ThemeMode.dark)
            _buildKitsuneSettingCard(
              context,
              title: context.l10n!.pureBlackTheme,
              icon: FluentIcons.color_background_24_regular,
              description: context.l10n!.pureBlackThemeDescription,
              onTap: () => _togglePureBlack(context, !usePureBlackColor.value),
              trailing: Switch(
                value: usePureBlackColor.value,
                onChanged: (value) => _togglePureBlack(context, value),
              ),
            ),
          _buildKitsuneSettingCard(
            context,
            title: context.l10n!.dynamicColor,
            icon: FluentIcons.toggle_left_24_regular,
            description: context.l10n!.dynamicColorDescription,
            onTap: () => _toggleSystemColor(context, !useSystemColor.value),
            trailing: Switch(
              value: useSystemColor.value,
              onChanged: (value) => _toggleSystemColor(context, value),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: useProxy,
            builder: (_, value, __) {
              return _buildKitsuneSettingCard(
                context,
                title: context.l10n!.useProxy,
                icon: FluentIcons.shield_24_regular,
                description: context.l10n!.useProxyDescription,
                onTap: () {
                  final newValue = !value;
                  useProxy.value = newValue;
                  addOrUpdateData<bool>('settings', 'useProxy', newValue);
                },
                trailing: Switch(
                  value: value,
                  onChanged: (value) {
                    useProxy.value = value;
                    addOrUpdateData<bool>('settings', 'useProxy', value);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineFeaturesSection(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: sponsorBlockSupport,
          builder: (_, value, __) {
            return _buildKitsuneSettingCard(
              context,
              title: 'SponsorBlock',
              icon: FluentIcons.cut_24_regular,
              description: context.l10n!.sponsorBlockDescription,
              onTap: () => _toggleSponsorBlock(context, !value),
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleSponsorBlock(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: playNextSongAutomatically,
          builder: (_, value, __) {
            return _buildKitsuneSettingCard(
              context,
              title: context.l10n!.automaticSongPicker,
              icon: FluentIcons.music_note_2_play_20_regular,
              description: context.l10n!.automaticSongPickerDescription,
              onTap: () => _toggleAutoPlayNext(context, !value),
              trailing: Switch(
                value: value,
                onChanged: (value) {
                  _toggleAutoPlayNext(context, value);
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: externalRecommendations,
          builder: (_, value, __) {
            return _buildKitsuneSettingCard(
              context,
              title: context.l10n!.externalRecommendations,
              icon: FluentIcons.channel_share_24_regular,
              description: context.l10n!.externalRecommendationsDescription,
              onTap: () => _toggleExternalRecommendations(context, !value),
              trailing: Switch(
                value: value,
                onChanged: (value) =>
                    _toggleExternalRecommendations(context, value),
              ),
            );
          },
        ),

        _buildToolsSection(context),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: context.l10n!.tools,
          icon: FluentIcons.toolbox_24_filled,
        ),
        _buildKitsuneSettingCard(
          context,
          title: context.l10n!.clearCache,
          icon: FluentIcons.broom_24_regular,
          onTap: () async {
            final cleared = await clearCache();
            showToast(
              context,
              cleared ? '${context.l10n!.cacheMsg}!' : context.l10n!.error,
            );
          },
        ),
        _buildKitsuneSettingCard(
          context,
          title: context.l10n!.clearSearchHistory,
          icon: FluentIcons.history_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearSearchHistoryQuestion,
            onSubmit: () {
              searchHistoryNotifier.value = [];
              deleteData('user', 'searchHistory');
              showToast(context, '${context.l10n!.searchHistoryMsg}!');
            },
          ),
        ),
        _buildKitsuneSettingCard(
          context,
          title: context.l10n!.clearRecentlyPlayed,
          icon: FluentIcons.receipt_play_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearRecentlyPlayedQuestion,
            onSubmit: () {
              userRecentlyPlayed.value = [];
              deleteData('user', 'recentlyPlayedSongs');
              showToast(context, '${context.l10n!.recentlyPlayedMsg}!');
            },
          ),
        ),
        _buildKitsuneSettingCard(
          context,
          title: context.l10n!.clearListeningStats,
          icon: FluentIcons.data_bar_vertical_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearListeningStatsQuestion,
            onSubmit: () async {
              await listeningStatsService.clearStats();
              showToast(context, context.l10n!.listeningStatsCleared);
            },
          ),
        ),
        _buildKitsuneSettingCard(
          context,
          title: context.l10n!.deleteDownloads,
          icon: FluentIcons.delete_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.deleteDownloadsQuestion,
            onSubmit: () async {
              await OfflinePlaylistService().deleteAllDownloads();
              showToast(context, context.l10n!.downloadsDeleted);
            },
          ),
        ),
        _buildKitsuneSettingCard(
          context,
          title: context.l10n!.importSpotifyPlaylist,
          icon: FluentIcons.arrow_upload_24_regular,
          onTap: () => context.push('/settings/import-spotify-playlist'),
        ),
        _buildKitsuneSettingCard(
          context,
          title: context.l10n!.backupUserData,
          icon: FluentIcons.cloud_sync_24_regular,
          onTap: () => _backupUserData(context),
        ),
        _buildKitsuneSettingCard(
          context,
          title: context.l10n!.restoreUserData,
          icon: FluentIcons.cloud_add_24_regular,
          onTap: () async {
            try {
              final result = await restoreData(context);
              if (result.success) {
                reloadSettingsFromStorage();
                reloadSongLibraryStateFromStorage();
                reloadPlaylistLibraryStateFromStorage();
                reloadSearchHistoryFromStorage();
                listeningStatsService.reload();
                await audioHandler.setShuffleMode(
                  shuffleNotifier.value
                      ? AudioServiceShuffleMode.all
                      : AudioServiceShuffleMode.none,
                );
                await audioHandler.setRepeatMode(repeatNotifier.value);
                themeMode = getThemeMode(themeModeSetting);
                brightness = getBrightnessFromThemeMode(themeMode);
                if (context.mounted) {
                  await Musify.updateAppState(
                    context,
                    newThemeMode: themeMode,
                    newLocale: languageSetting,
                    newAccentColor: primaryColorSetting,
                    useSystemColor: useSystemColor.value,
                  );
                  NavigationManager.refreshRouter();
                }
              }
              if (context.mounted) {
                showToast(
                  context,
                  result.message,
                  icon: result.success
                      ? null
                      : FluentIcons.error_circle_24_regular,
                );
              }
            } catch (e, str) {
              logger.log('Error restoring data', error: e, stackTrace: str);
              if (context.mounted) {
                showToast(
                  context,
                  context.l10n!.error,
                  icon: FluentIcons.error_circle_24_regular,
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildSettingsHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
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
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              FluentIcons.settings_24_filled,
              size: 30,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Harmony By Aasif',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n!.settings,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.72,
                    ),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKitsuneSettingCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    String? description,
    Widget? trailing,
    VoidCallback? onTap,
    bool dangerous = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return _ScrollRevealCard(
      active: widget.isOpen,
      scrollController: _settingsScrollController,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
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
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color:
                            (dangerous
                                    ? colorScheme.error
                                    : colorScheme.primary)
                                .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, size: 21, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (description != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.25,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 10),
                      trailing,
                    ] else if (onTap != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        FluentIcons.chevron_right_20_regular,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showThemeModePicker(BuildContext context) {
    final availableModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    const modeIcons = [
      FluentIcons.phone_24_regular,
      FluentIcons.weather_sunny_24_regular,
      FluentIcons.weather_moon_24_regular,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableModes.length,
        itemBuilder: (context, index) {
          final mode = availableModes[index];
          final modeNames = [
            context.l10n!.themeModeSystem,
            context.l10n!.themeModeLight,
            context.l10n!.themeModeDark,
          ];

          return BottomSheetBar(
            modeNames[mode.index],
            () {
              addOrUpdateData<int>('settings', 'themeIndex', mode.index);
              Musify.updateAppState(context, newThemeMode: mode);
              Navigator.pop(context);
            },
            themeMode == mode,
            icon: modeIcons[mode.index],
          );
        },
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final availableLanguages = appLanguages.toList();
    final activeLanguageCode = Localizations.localeOf(context).languageCode;
    final activeScriptCode = Localizations.localeOf(context).scriptCode;
    final activeLanguageFullCode = activeScriptCode != null
        ? '$activeLanguageCode-$activeScriptCode'
        : activeLanguageCode;

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableLanguages.length,
        itemBuilder: (context, index) {
          final language = availableLanguages[index];
          final newLocale = getLocaleFromLanguageCode(language);
          final newLocaleFullCode = newLocale.scriptCode != null
              ? '${newLocale.languageCode}-${newLocale.scriptCode}'
              : newLocale.languageCode;

          return BottomSheetBar(getLanguageDisplayName(context, language), () {
            addOrUpdateData<String>(
              'settings',
              'languageCode',
              newLocaleFullCode,
            );
            Musify.updateAppState(context, newLocale: newLocale);
            showToast(context, context.l10n!.languageMsg);
            Navigator.pop(context);
          }, activeLanguageFullCode == newLocaleFullCode);
        },
      ),
    );
  }

  void _showAudioQualityPicker(BuildContext context) {
    final availableQualities = ['low', 'medium', 'high'];
    final qualityNames = [
      context.l10n!.audioQualityLow,
      context.l10n!.audioQualityMedium,
      context.l10n!.audioQualityHigh,
    ];
    const qualityIcons = [
      FluentIcons.speaker_1_24_regular,
      FluentIcons.speaker_2_24_regular,
      FluentIcons.speaker_2_24_filled,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableQualities.length,
        itemBuilder: (context, index) {
          final quality = availableQualities[index];

          return BottomSheetBar(
            qualityNames[index],
            () {
              addOrUpdateData<String>('settings', 'audioQuality', quality);
              audioQualitySetting.value = quality;
              showToast(context, context.l10n!.audioQualityMsg);
              Navigator.pop(context);
            },
            audioQualitySetting.value == quality,
            icon: qualityIcons[index],
          );
        },
      ),
    );
  }

  void _toggleSystemColor(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'useSystemColor', value);
    useSystemColor.value = value;
    Musify.updateAppState(
      context,
      newAccentColor: primaryColorSetting,
      useSystemColor: value,
    );
  }

  void _togglePureBlack(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'usePureBlackColor', value);
    usePureBlackColor.value = value;
    Musify.updateAppState(context);
  }

  void _toggleAudioQualityBadge(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'showAudioQualityBadge', value);
    showAudioQualityBadge.value = value;
  }

  Future<void> _toggleWrapped(BuildContext context, bool value) async {
    if (!value) {
      audioHandler.resetListeningStatsSession(
        countCurrentTick: true,
        flushStats: false,
      );
      await listeningStatsService.flush();
    }

    await addOrUpdateData<bool>('settings', 'wrappedEnabled', value);
    wrappedEnabled.value = value;
    listeningStatsService.reload();
    if (value) {
      audioHandler.startListeningStatsSessionIfNeeded();
    }
  }

  void _toggleSponsorBlock(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'sponsorBlockSupport', value);
    sponsorBlockSupport.value = value;
  }

  void _toggleAutoPlayNext(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'playNextSongAutomatically', value);
    playNextSongAutomatically.value = value;
  }

  void _toggleExternalRecommendations(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'externalRecommendations', value);
    externalRecommendations.value = value;
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String confirmationMessage,
    required VoidCallback onSubmit,
    String? submitMessage,
    bool isDangerous = false,
  }) {
    showHarmonyDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          submitMessage: submitMessage ?? context.l10n!.clear,
          confirmationMessage: confirmationMessage,
          isDangerous: isDangerous,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: () {
            Navigator.of(context).pop();
            onSubmit();
          },
        );
      },
    );
  }

  Future<void> _backupUserData(BuildContext context) async {
    try {
      final result = await backupData(context);
      if (context.mounted) {
        showToast(
          context,
          result.message,
          icon: result.success ? null : FluentIcons.error_circle_24_regular,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error backing up data', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        showToast(
          context,
          context.l10n!.error,
          icon: FluentIcons.error_circle_24_regular,
        );
      }
    }
  }
}

class _ScrollRevealCard extends StatefulWidget {
  const _ScrollRevealCard({
    required this.active,
    required this.scrollController,
    required this.child,
  });

  final bool active;
  final ScrollController scrollController;
  final Widget child;

  @override
  State<_ScrollRevealCard> createState() => _ScrollRevealCardState();
}

class _ScrollRevealCardState extends State<_ScrollRevealCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();

  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.active ? 1.0 : 0.0,
    );

    widget.scrollController.addListener(_updateFromScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFromScroll();
    });
  }

  @override
  void didUpdateWidget(covariant _ScrollRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.active && widget.active) {
      _animationController.value = 0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateFromScroll(animate: true);
      });
    } else if (oldWidget.active && !widget.active) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_updateFromScroll);
    _animationController.dispose();
    super.dispose();
  }

  void _updateFromScroll({bool animate = false}) {
    if (!mounted || !widget.active) return;

    final renderObject = _cardKey.currentContext?.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;

    final mediaQuery = MediaQuery.of(context);
    final viewportTop = mediaQuery.padding.top + 18.0;
    final viewportBottom =
        mediaQuery.size.height - mediaQuery.padding.bottom - 18.0;

    const revealDistance = 120.0;

    final fromBottom = ((viewportBottom - top) / revealDistance)
        .clamp(0.0, 1.0)
        .toDouble();

    final fromTop = ((bottom - viewportTop) / revealDistance)
        .clamp(0.0, 1.0)
        .toDouble();

    final target = fromBottom < fromTop ? fromBottom : fromTop;

    if (animate) {
      _animationController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _animationController.value = Curves.easeOutCubic.transform(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final progress = _animationController.value;

        return RepaintBoundary(
          key: _cardKey,
          child: Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(-28.0 * (1.0 - progress), 0),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

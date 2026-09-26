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

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Centralized dismissal for Harmony popup menus.
///
/// A `material_ui` popup menu sits behind a dismissible modal barrier, so a
/// swipe on that barrier never reaches the underlying scrollable and the menu
/// stays floating over content that should have scrolled. Instead of teaching
/// every screen to close its own menu, the overflow menu button registers the
/// one open menu here and a single root-level pointer listener (see
/// `main.dart`) feeds it raw pointer moves. The moment a drag passes
/// [dragThreshold] the open menu is popped, regardless of where it was opened.
class HarmonyPopupController {
  HarmonyPopupController._();

  static final HarmonyPopupController instance = HarmonyPopupController._();

  /// Drag distance, in logical pixels, that counts as a deliberate swipe. Kept
  /// well above incidental pointer jitter so a tap or a tiny wobble never
  /// dismisses the menu, but a real flick does.
  static const double dragThreshold = 16;

  VoidCallback? _dismiss;
  Offset? _downPosition;

  /// Whether a Harmony popup menu is currently registered as open.
  bool get isOpen => _dismiss != null;

  /// Registers the callback that closes the currently opening menu. Only one
  /// Harmony menu is modal at a time, so a single slot is enough.
  void register(VoidCallback dismiss) {
    _dismiss = dismiss;
    _downPosition = null;
  }

  /// Clears the registration, but only if [dismiss] is still the active one, so
  /// a menu that already closed cannot unregister the next menu.
  void unregister(VoidCallback dismiss) {
    if (identical(_dismiss, dismiss)) {
      _dismiss = null;
      _downPosition = null;
    }
  }

  void handlePointerDown(PointerDownEvent event) {
    _downPosition = event.position;
  }

  void handlePointerMove(PointerMoveEvent event) {
    final dismiss = _dismiss;
    final start = _downPosition;
    if (dismiss == null || start == null) return;
    if ((event.position - start).distance >= dragThreshold) {
      _downPosition = null;
      _dismiss = null;
      dismiss();
    }
  }

  void handlePointerUp(PointerUpEvent event) {
    _downPosition = null;
  }

  void handlePointerCancel(PointerCancelEvent event) {
    _downPosition = null;
  }
}

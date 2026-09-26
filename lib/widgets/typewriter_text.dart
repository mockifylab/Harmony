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

import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Types short lines out character by character, holds them, deletes them and
/// moves on to the next. The same restrained rotation the search placeholder
/// uses, packaged for any secondary line. Pass a stable list instance: a new
/// list restarts the rotation.
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.phrases,
    this.style,
    this.hold = const Duration(milliseconds: 2800),
    this.typeSpeed = const Duration(milliseconds: 55),
    this.deleteSpeed = const Duration(milliseconds: 28),
  });

  final List<String> phrases;
  final TextStyle? style;

  /// How long a fully typed phrase stays on screen.
  final Duration hold;
  final Duration typeSpeed;
  final Duration deleteSpeed;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  int _index = 0;
  int _typedLength = 0;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _schedule(widget.typeSpeed);
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phrases == oldWidget.phrases) return;
    _timer?.cancel();
    _index = 0;
    _typedLength = 0;
    _deleting = false;
    _schedule(widget.typeSpeed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _tick);
  }

  void _tick() {
    if (!mounted || widget.phrases.isEmpty) return;
    final phrase = widget.phrases[_index % widget.phrases.length];

    if (_deleting) {
      if (_typedLength == 0) {
        setState(() {
          _deleting = false;
          _index = (_index + 1) % widget.phrases.length;
        });
        _schedule(widget.typeSpeed);
        return;
      }
      setState(() => _typedLength--);
      _schedule(widget.deleteSpeed);
      return;
    }

    if (_typedLength >= phrase.length) {
      setState(() => _deleting = true);
      _schedule(widget.hold);
      return;
    }
    setState(() => _typedLength++);
    _schedule(widget.typeSpeed);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phrases.isEmpty) return const SizedBox.shrink();
    final phrase = widget.phrases[_index % widget.phrases.length];
    final typedLength = _typedLength.clamp(0, phrase.length);
    // A blank space keeps the line box reserved while the phrase is being
    // deleted, so the surrounding layout never jumps.
    final visible = typedLength == 0 ? ' ' : phrase.substring(0, typedLength);

    return Text(
      visible,
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

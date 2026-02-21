import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Lightweight toast notification that uses Liquid Glass on iOS 26+
/// and explicitly prevents inherited text decoration (underline).
class NmToast {
  static final List<_ToastEntry> _queue = [];
  static bool _isShowing = false;

  // ─────────────── Public API ───────────────

  static void show(
    BuildContext context,
    String message, {
    Widget? icon,
    NmToastStyle style = NmToastStyle.normal,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;
    _queue.add(_ToastEntry(context: context, message: message, icon: icon, style: style, duration: duration));
    if (!_isShowing) _showNext();
  }

  static void success(BuildContext context, String message) => show(
    context,
    message,
    icon: const Icon(Icons.check_circle_rounded, color: CupertinoColors.systemGreen, size: 22),
    style: NmToastStyle.success,
  );

  static void error(BuildContext context, String message) => show(
    context,
    message,
    icon: const Icon(Icons.error_rounded, color: CupertinoColors.systemRed, size: 22),
    style: NmToastStyle.error,
  );

  static void info(BuildContext context, String message) => show(
    context,
    message,
    icon: const Icon(Icons.info_rounded, color: CupertinoColors.systemBlue, size: 22),
    style: NmToastStyle.info,
  );

  static void warning(BuildContext context, String message) => show(
    context,
    message,
    icon: const Icon(Icons.warning_rounded, color: CupertinoColors.systemOrange, size: 22),
    style: NmToastStyle.warning,
  );

  static void clear(BuildContext context) => _queue.clear();

  // ─────────────── Internal queue ───────────────

  static void _showNext() {
    if (_queue.isEmpty) {
      _isShowing = false;
      return;
    }
    _isShowing = true;
    final entry = _queue.removeAt(0);

    final overlay = Overlay.of(entry.context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (_) => _ToastWidget(
        entry: entry,
        onDismiss: () {
          if (overlayEntry.mounted) overlayEntry.remove();
          _showNext();
        },
      ),
    );

    overlay.insert(overlayEntry);

    Timer(entry.duration, () {
      if (overlayEntry.mounted) overlayEntry.remove();
      _showNext();
    });
  }
}

// ─────────────── Style enum ───────────────

enum NmToastStyle { normal, success, error, warning, info }

// ─────────────── Queue entry ───────────────

class _ToastEntry {
  const _ToastEntry({
    required this.context,
    required this.message,
    this.icon,
    required this.style,
    required this.duration,
  });

  final BuildContext context;
  final String message;
  final Widget? icon;
  final NmToastStyle style;
  final Duration duration;
}

// ─────────────── Toast widget ───────────────

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.entry, required this.onDismiss});

  final _ToastEntry entry;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _bg(BuildContext context) {
    final isDark = (CupertinoTheme.of(context).brightness ?? Brightness.light) == Brightness.dark;
    return switch (widget.entry.style) {
      NmToastStyle.normal => isDark ? const Color(0xE6333333) : const Color(0xE6FFFFFF),
      NmToastStyle.success => isDark ? const Color(0xE6264D26) : const Color(0xE6E8F5E9),
      NmToastStyle.error => isDark ? const Color(0xE64D2626) : const Color(0xE6FFEBEE),
      NmToastStyle.warning => isDark ? const Color(0xE64D3D26) : const Color(0xE6FFF3E0),
      NmToastStyle.info => isDark ? const Color(0xE626444D) : const Color(0xE6E3F2FD),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bg(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    final useGlass = PlatformVersion.supportsLiquidGlass;

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.entry.icon != null) ...[widget.entry.icon!, const SizedBox(width: 12)],
          Flexible(
            child: Text(
              widget.entry.message,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    content = useGlass
        ? LiquidGlassContainer(
            config: LiquidGlassConfig(effect: CNGlassEffect.regular, shape: CNGlassEffectShape.capsule, tint: bg),
            child: content,
          )
        : Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: content,
          );

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Positioned.fill(
      bottom: bottomPadding + 100,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ScaleTransition(
            scale: _scale,
            child: FadeTransition(
              opacity: _fade,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: content),
            ),
          ),
        ),
      ),
    );
  }
}

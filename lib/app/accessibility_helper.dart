import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Accessibility helper utilities for WCAG 2.1 AA compliance
/// Provides semantic labels, contrast checking, and touch target enforcement
class AccessibilityHelper {
  /// Minimum touch target size (48x48 dp) per WCAG 2.1
  static const double minTouchTarget = 48.0;

  /// Wrap a widget with semantic information for screen readers
  static Widget semanticButton({
    required Widget child,
    required String label,
    String? hint,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: hint,
      onTap: enabled ? onTap : null,
      child: child,
    );
  }

  /// Wrap an icon button with proper semantics
  static Widget semanticIconButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    String? hint,
    Color? color,
    double size = 24,
  }) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      enabled: onPressed != null,
      child: ExcludeSemantics(
        child: IconButton(
          icon: Icon(icon, size: size),
          onPressed: onPressed,
          color: color,
          tooltip: label,
        ),
      ),
    );
  }

  /// Wrap an image with alt text
  static Widget semanticImage({
    required Widget image,
    required String alt,
    String? hint,
  }) {
    return Semantics(
      image: true,
      label: alt,
      hint: hint,
      child: ExcludeSemantics(child: image),
    );
  }

  /// Create a semantic heading for navigation
  static Widget semanticHeading({
    required String text,
    required TextStyle? style,
  }) {
    return Semantics(header: true, child: Text(text, style: style));
  }

  /// Announce a message to screen readers (e.g., for live regions)
  static void announceMessage(BuildContext context, String message) {
    // Use SnackBar with duration 0 for announcement only
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration.zero,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 1000), // Off-screen
      ),
    );

    // Also use SemanticsService for direct announcement
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Check if color contrast meets WCAG AA (4.5:1 for normal text)
  static bool meetsContrastAA(Color foreground, Color background) {
    final ratio = _contrastRatio(foreground, background);
    return ratio >= 4.5;
  }

  /// Check if color contrast meets WCAG AAA (7:1 for normal text)
  static bool meetsContrastAAA(Color foreground, Color background) {
    final ratio = _contrastRatio(foreground, background);
    return ratio >= 7.0;
  }

  /// Calculate contrast ratio between two colors
  static double _contrastRatio(Color foreground, Color background) {
    final fgLuminance = _relativeLuminance(foreground);
    final bgLuminance = _relativeLuminance(background);

    final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
    final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Calculate relative luminance for a color
  static double _relativeLuminance(Color color) {
    final r = _linearize(color.r);
    final g = _linearize(color.g);
    final b = _linearize(color.b);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize RGB channel value
  static double _linearize(double channel) {
    if (channel <= 0.03928) {
      return channel / 12.92;
    }
    return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Wrap a widget to enforce minimum touch target size
  static Widget enforceMinTouchTarget({
    required Widget child,
    double minSize = minTouchTarget,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: child,
    );
  }

  /// Create an accessible card with proper focus handling
  static Widget accessibleCard({
    required Widget child,
    String? semanticLabel,
    String? semanticHint,
    VoidCallback? onTap,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: onTap != null,
      enabled: onTap != null,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  /// Format currency for screen readers (e.g., "5.99 Jordanian Dinars")
  static String formatCurrencyForScreenReader(double amount, String currency) {
    final currencyName = _getCurrencyName(currency);
    return '${amount.toStringAsFixed(2)} $currencyName';
  }

  static String _getCurrencyName(String code) {
    switch (code.toUpperCase()) {
      case 'JOD':
        return 'Jordanian Dinars';
      case 'USD':
        return 'US Dollars';
      case 'EUR':
        return 'Euros';
      case 'GBP':
        return 'British Pounds';
      default:
        return code;
    }
  }

  /// Create a loading indicator with semantic announcement
  static Widget accessibleLoadingIndicator({String message = 'Loading'}) {
    return Semantics(
      label: message,
      liveRegion: true,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  /// Wrap form field with enhanced semantics
  static Widget semanticTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? error,
    bool required = false,
    TextInputType? keyboardType,
    bool obscureText = false,
    int? maxLines = 1,
  }) {
    return Semantics(
      label: label + (required ? ', required' : ''),
      hint: hint,
      textField: true,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: maxLines,
      ),
    );
  }
}

/// User accessibility preferences
class AccessibilityPreferences {
  const AccessibilityPreferences({
    this.textScale = 1.0,
    this.highContrast = false,
    this.reducedMotion = false,
    this.screenReaderEnabled = false,
  });

  final double textScale;
  final bool highContrast;
  final bool reducedMotion;
  final bool screenReaderEnabled;

  AccessibilityPreferences copyWith({
    double? textScale,
    bool? highContrast,
    bool? reducedMotion,
    bool? screenReaderEnabled,
  }) {
    return AccessibilityPreferences(
      textScale: textScale ?? this.textScale,
      highContrast: highContrast ?? this.highContrast,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      screenReaderEnabled: screenReaderEnabled ?? this.screenReaderEnabled,
    );
  }

  /// Detect system accessibility settings
  static AccessibilityPreferences fromMediaQuery(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return AccessibilityPreferences(
      textScale: mediaQuery.textScaler.scale(1.0),
      highContrast: mediaQuery.highContrast,
      reducedMotion: mediaQuery.disableAnimations,
      screenReaderEnabled: mediaQuery.accessibleNavigation,
    );
  }
}

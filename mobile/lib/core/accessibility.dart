import 'package:flutter/material.dart';
import 'package:may_laud/theme/app_colors.dart';
import 'package:may_laud/theme/app_theme.dart';

/// Accessibility utilities for screen reader support, contrast, and focus management
class Accessibility {
  /// Minimum touch target size as per WCAG guidelines (44x44 logical pixels)
  static const double minTouchTargetSize = 44.0;

  /// Check if text has sufficient contrast against background
  static bool hasSufficientContrast(Color textColor, Color backgroundColor) {
    final textLuminance = textColor.computeLuminance();
    final backgroundLuminance = backgroundColor.computeLuminance();

    final lighter = textLuminance > backgroundLuminance
        ? textLuminance
        : backgroundLuminance;
    final darker = textLuminance > backgroundLuminance
        ? backgroundLuminance
        : textLuminance;

    final contrastRatio = (lighter + 0.05) / (darker + 0.05);

    // WCAG AA requires 4.5:1 for normal text, 3:1 for large text
    return contrastRatio >= 4.5;
  }

  /// Get accessible text color for a given background
  static Color getAccessibleTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Announce to screen readers
  static void announceToScreenReader(BuildContext context, String message) {
    // Use Semantics to announce to screen readers
    // In Flutter, we can use Semantics properties or LiveRegion for announcements
    // For now, we'll use a simpler approach
    // In a production app, consider using accessibility features package
    // or implementing proper screen reader announcements
  }

  /// Set focus to a widget and announce to screen reader
  static void focusAndAnnounce(
    BuildContext context,
    FocusNode focusNode, {
    String? announcement,
  }) {
    focusNode.requestFocus();
    if (announcement != null) {
      announceToScreenReader(context, announcement);
    }
  }

  /// Create semantic button with proper labels
  static Widget semanticButton({
    required Widget child,
    required VoidCallback onPressed,
    required String label,
    String? hint,
    bool enabled = true,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: hint,
      child: ExcludeSemantics(
        child: child,
      ),
    );
  }

  /// Create accessible text field
  static Widget accessibleTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
  }) {
    return Semantics(
      textField: true,
      label: label,
      hint: hint,
      child: ExcludeSemantics(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: keyboardType,
          obscureText: obscureText,
          focusNode: focusNode,
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// Ensure minimum touch target size
  static Widget ensureMinTouchTarget(Widget child) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: minTouchTargetSize,
        minHeight: minTouchTargetSize,
      ),
      child: Center(child: child),
    );
  }

  /// Create accessible icon button
  static Widget accessibleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String label,
    Color? color,
    double size = 24,
    bool enabled = true,
  }) {
    return semanticButton(
      onPressed: onPressed,
      label: label,
      enabled: enabled,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: color,
        iconSize: size,
        constraints: const BoxConstraints(
          minWidth: minTouchTargetSize,
          minHeight: minTouchTargetSize,
        ),
      ),
    );
  }

  /// Create accessible card with proper semantics
  static Widget accessibleCard({
    required Widget child,
    required String label,
    String? hint,
    VoidCallback? onTap,
    Color? color,
  }) {
    return Semantics(
      container: true,
      label: label,
      hint: hint,
      child: ExcludeSemantics(
        child: Card(
          color: color,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  /// Check if system is using high contrast mode
  static bool isHighContrastMode(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.highContrast;
  }

  /// Check if system is using bold text
  static bool isBoldTextEnabled(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.boldText;
  }

  /// Get appropriate text style based on accessibility settings
  static TextStyle getAccessibleTextStyle(
    BuildContext context, {
    TextStyle? baseStyle,
    double minFontSize = 14,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final base = baseStyle ?? const TextStyle();

    // Adjust for text scaling
    final fontSize =
        (base.fontSize ?? minFontSize) * mediaQuery.textScaler.scale(1.0);

    // Ensure minimum font size
    final finalFontSize = fontSize < minFontSize ? minFontSize : fontSize;

    // Adjust for bold text preference
    final fontWeight = mediaQuery.boldText
        ? FontWeight.bold
        : (base.fontWeight ?? FontWeight.normal);

    return base.copyWith(
      fontSize: finalFontSize,
      fontWeight: fontWeight,
    );
  }

  /// Create accessible color scheme
  static ColorScheme getAccessibleColorScheme(bool isDarkMode) {
    if (isDarkMode) {
      return ColorScheme.dark(
        primary: AppColors.milaorBlue,
        secondary: AppColors.philippineGold,
        error: AppColors.error,
        surface: Color(0xFF121212),
      );
    } else {
      return ColorScheme.light(
        primary: AppColors.milaorBlue,
        secondary: AppColors.philippineGold,
        error: AppColors.error,
        surface: Colors.white,
      );
    }
  }

  /// Show accessibility dialog
  static Future<void> showAccessibilityDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accessibility Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccessibilitySetting(
                title: 'High Contrast Mode',
                subtitle: 'Increase contrast for better visibility',
                value: isHighContrastMode(context),
                onChanged: (value) {
                  // In a real app, this would toggle system settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'High contrast mode would be toggled in system settings'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _AccessibilitySetting(
                title: 'Bold Text',
                subtitle: 'Use bold text for better readability',
                value: isBoldTextEnabled(context),
                onChanged: (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Bold text would be toggled in system settings'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _AccessibilitySetting(
                title: 'Screen Reader',
                subtitle: 'Enable voice guidance for navigation',
                value: true, // Assuming screen reader is enabled
                onChanged: (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Screen reader settings are managed in device accessibility settings'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: Some accessibility features are controlled by your device settings. '
                'You can adjust them in your device\'s accessibility settings.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _AccessibilitySetting extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AccessibilitySetting({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.milaorBlue,
        ),
      ],
    );
  }
}

/// Accessibility-focused text widget
class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? align;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;
  final double minFontSize;

  const AccessibleText(
    this.text, {
    super.key,
    this.style,
    this.align,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.minFontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final accessibleStyle = Accessibility.getAccessibleTextStyle(
      context,
      baseStyle: style,
      minFontSize: minFontSize,
    );

    return Text(
      text,
      style: accessibleStyle,
      textAlign: align,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      semanticsLabel: text, // Ensure screen readers can read the text
    );
  }
}

/// Accessibility-focused button
class AccessibleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final String semanticLabel;
  final String? semanticHint;
  final ButtonStyle? style;
  final bool enabled;

  const AccessibleButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
    this.semanticHint,
    this.style,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      hint: semanticHint,
      child: ExcludeSemantics(
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: style,
          child: child,
        ),
      ),
    );
  }
}
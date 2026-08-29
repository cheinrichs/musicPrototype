import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/theme.dart';

/// A playful button with "squishy" press animation.
///
/// Visual style ported from the Lumi design system's `.c-action`/`.c-cta`
/// components (see SongStone-UI-Kit/UI/kit.css): a gradient face sitting
/// on top of a solid, hard-edged "step" shadow that shortens on press —
/// giving a painterly, embossed 3D-button look rather than a flat
/// material button with a blurred drop shadow.
class SquishyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color? shadowColor;

  /// Optional gradient face. When set, this is used instead of
  /// [backgroundColor] for the fill — pass one of AppColors' gradients
  /// (e.g. buttonGreenGradient) for the full Lumi look.
  final Gradient? gradient;

  /// Height of the solid "step" shadow below the button face, matching
  /// the CSS `box-shadow: 0 <stepHeight>px 0 <shadowColor>` recipe.
  final double stepHeight;

  final double? width;
  final double? height;
  final EdgeInsets padding;
  final double borderRadius;
  final bool enabled;

  const SquishyButton({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor = AppColors.primary,
    this.shadowColor,
    this.gradient,
    this.stepHeight = 5,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.buttonPadding,
      vertical: AppSpacing.md,
    ),
    this.borderRadius = AppSpacing.radiusLg,
    this.enabled = true,
  });

  @override
  State<SquishyButton> createState() => _SquishyButtonState();
}

class _SquishyButtonState extends State<SquishyButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveShadowColor =
        widget.shadowColor ?? widget.backgroundColor.withValues(alpha: 0.55);
    final currentStep = _isPressed ? widget.stepHeight / 2.5 : widget.stepHeight;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _handleTapDown() : null,
      onTapUp: widget.enabled ? (_) => _handleTapUp() : null,
      onTapCancel: widget.enabled ? _handleTapCancel : null,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.defaultCurve,
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        transform: Matrix4.translationValues(
          0,
          _isPressed ? widget.stepHeight - currentStep : 0,
          0,
        ),
        decoration: BoxDecoration(
          gradient: widget.gradient,
          color: widget.gradient == null
              ? (widget.enabled
                    ? widget.backgroundColor
                    : widget.backgroundColor.withValues(alpha: 0.5))
              : null,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: widget.enabled
              ? [
                  // Hard-edged "step" — the embossed 3D edge
                  BoxShadow(
                    color: effectiveShadowColor,
                    offset: Offset(0, currentStep),
                  ),
                  // Soft ambient shadow for depth
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: _isPressed ? 6 : 14,
                    offset: Offset(0, _isPressed ? 3 : 7),
                  ),
                ]
              : null,
        ),
        child: Center(child: widget.child),
      ),
    );
  }

  void _handleTapDown() {
    setState(() => _isPressed = true);
  }

  void _handleTapUp() {
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }
}

/// A large game button for High/Low choices
class GameChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  const GameChoiceButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SquishyButton(
          onTap: onTap,
          backgroundColor: color,
          enabled: enabled,
          width: AppSpacing.gameButtonSize,
          height: AppSpacing.gameButtonSize,
          padding: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppSpacing.radiusXl,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: AppColors.textOnPrimary),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: AppTypography.buttonMedium),
            ],
          ),
        )
        .animate(target: enabled ? 0 : 1)
        .fade(begin: 1, end: 0.5, duration: AppAnimations.fast);
  }
}

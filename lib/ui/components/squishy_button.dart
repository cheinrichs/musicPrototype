import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/theme.dart';

/// A playful button with "squishy" press animation
/// Used throughout the app for primary interactions
class SquishyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color? shadowColor;
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
        widget.shadowColor ?? widget.backgroundColor.withValues(alpha: 0.3);

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _handleTapDown() : null,
      onTapUp: widget.enabled ? (_) => _handleTapUp() : null,
      onTapCancel: widget.enabled ? _handleTapCancel : null,
      child: AnimatedScale(
        scale: _isPressed ? AppAnimations.buttonPressScale : 1.0,
        duration: _isPressed
            ? AppAnimations.buttonPressDown
            : AppAnimations.buttonPressUp,
        curve: _isPressed ? Curves.easeOut : AppAnimations.bounceCurve,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.enabled
                ? widget.backgroundColor
                : widget.backgroundColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: effectiveShadowColor,
                blurRadius: _isPressed ? 4 : 8,
                offset: Offset(0, _isPressed ? 2 : 4),
              ),
            ],
          ),
          child: Center(child: widget.child),
        ),
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

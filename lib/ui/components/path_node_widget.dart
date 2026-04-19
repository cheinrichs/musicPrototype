import 'package:flutter/material.dart';
import '../../models/path_node.dart';
import '../theme/theme.dart';
import 'squishy_button.dart';

/// A single node on the learning path.
/// Displays as a colored circle with icon + label below.
/// Active nodes have a pulsing ring and squishy tap feedback.
/// Locked nodes are dimmed and non-interactive.
class PathNodeWidget extends StatelessWidget {
  final PathNode node;
  final VoidCallback? onTap;

  static const double _circleSize = 72;
  static const double _ringSize = 88;
  static const double _iconSize = 32;

  const PathNodeWidget({super.key, required this.node, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNodeCircle(),
        const SizedBox(height: AppSpacing.xs),
        _buildLabel(),
      ],
    );
  }

  Widget _buildNodeCircle() {
    switch (node.state) {
      case NodeState.completed:
        return _buildSimpleCircle(AppColors.correct, Icons.check_rounded);

      case NodeState.active:
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing glow ring — uses AnimationController (Ticker-based,
            // not flutter_animate Timer) so it disposes cleanly in tests.
            _PulsingRing(size: _ringSize, color: AppColors.primary),
            // Tappable squishy button
            SquishyButton(
              onTap: onTap ?? () {},
              backgroundColor: AppColors.primary,
              width: _circleSize,
              height: _circleSize,
              padding: EdgeInsets.zero,
              borderRadius: _circleSize / 2,
              child: Icon(
                node.icon,
                color: AppColors.textOnPrimary,
                size: _iconSize,
              ),
            ),
          ],
        );

      case NodeState.locked:
        return AbsorbPointer(
          child: _buildSimpleCircle(AppColors.textSecondary, node.icon),
        );
    }
  }

  Widget _buildSimpleCircle(Color color, IconData icon) {
    return Container(
      width: _circleSize,
      height: _circleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.textOnPrimary, size: _iconSize + 4),
    );
  }

  Widget _buildLabel() {
    final color = node.state == NodeState.locked
        ? AppColors.textSecondary
        : AppColors.textPrimary;
    return Text(
      node.title,
      style: AppTypography.label.copyWith(color: color),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------
// Pulsing ring animation — uses AnimationController (Ticker-based) so the
// framework disposes it correctly at the end of widget tests.
// ---------------------------------------------------------------------------

class _PulsingRing extends StatefulWidget {
  final double size;
  final Color color;

  const _PulsingRing({required this.size, required this.color});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _scale = Tween<double>(
      begin: 0.85,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacity = Tween<double>(begin: 0.7, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: _scale.value,
          child: Opacity(
            opacity: _opacity.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

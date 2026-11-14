import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/rail_shell.dart';
import '../../app/router.dart';
import '../theme/theme.dart';

/// Small circular icon button styled to match the parchment-card look used
/// elsewhere in the Lumi design system, rather than a flat Material
/// IconButton. Originally built inline for the High/Low header's
/// close/skip controls; shared here so every screen's back/close
/// affordance looks and feels identical (Trello card 49).
///
/// [size]/[iconSize] and [elevated] default to the original quiet
/// header-control look; a caller that needs a more findable control (e.g.
/// High/Low's child-facing move-on button — Trello card, "the move-on
/// arrow is for the child too") can size it up and add [elevated]'s drop
/// shadow without duplicating this styling.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final bool elevated;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
    this.iconSize = 22,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: onTap == null ? 0.4 : 1,
          duration: AppAnimations.fast,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardEdge, width: 1.5),
              boxShadow: elevated
                  ? const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: iconSize),
          ),
        ),
      ),
    );
  }
}

/// A [CircleIconButton] that goes HOME — the Journey. The Games library
/// and the Playground sit in the rail beside it, so inside the rail this
/// just selects the Journey; anywhere else it navigates there. (It used to
/// go to the SongStone landing page, which is the player picker now — a
/// child must not reach a sibling's profile with one big tap, card 194.)
class BackHomeButton extends StatelessWidget {
  const BackHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Back',
      onTap: () {
        final rail = Provider.of<RailController?>(context, listen: false);
        if (rail != null) {
          rail.select(RailDestination.journey);
        } else {
          context.go(AppRoutes.journey);
        }
      },
    );
  }
}

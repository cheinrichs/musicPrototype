import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// A small, deliberately unremarkable tap target that gates something
/// meant for an adult, not a child (Trello card rDHLTn8u, built for the
/// credits screen but named and placed generically because parent
/// settings will need the exact same pattern later — a shared door
/// rather than a one-off).
///
/// This is not a child lock in any technical sense — a curious four-
/// year-old who taps it gets through just as easily as an adult. The
/// goal is narrower and achievable: don't *invite* a tap the way every
/// other control on the home screen deliberately does. Small (well under
/// the app's usual large-tap-target sizing), low-contrast against the
/// background, a plain outline icon rather than anything that reads as a
/// toy or a game control, and no label competing for attention next to
/// the colourful menu pills. An adult scanning the screen for "is there
/// a settings/about button" finds it; a child playing has no reason to.
class AdultDoor extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const AdultDoor({
    super.key,
    this.icon = Icons.info_outline,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // The tap target is padded well past the visible icon (a small
          // fingertip still needs to be able to land this reliably) —
          // generous hit area, deliberately unremarkable appearance are
          // not in tension with each other.
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.warmGray.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

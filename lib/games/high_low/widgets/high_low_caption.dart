import 'package:flutter/material.dart';
import '../../../ui/theme/theme.dart';

/// The round's caption, shown at the top of [HighLowScreen]'s header
/// (extracted from `_buildPromptArea` so the header's controls and its
/// caption area are two separately readable pieces — Trello, "Split Skip
/// into two controls: escape and move-on" and its sibling cards land a lot
/// of change on this screen at once, and this extraction is a pure move
/// with no behavior change, landed on its own first).
///
/// Reserves two lines' worth of height even when [text] is null so the
/// header doesn't jump as it toggles on and off between rounds.
class HighLowCaption extends StatelessWidget {
  final String? text;

  const HighLowCaption({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height:
          AppTypography.heading3.fontSize! * AppTypography.heading3.height! * 2,
      child: Center(
        child: AnimatedSwitcher(
          duration: AppAnimations.medium,
          child: text == null
              ? const SizedBox.shrink(key: ValueKey('caption-empty'))
              : Text(
                  text!,
                  key: ValueKey('caption-$text'),
                  style: AppTypography.heading3,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }
}

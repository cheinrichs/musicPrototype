import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/round_order.dart';
import 'package:ear_trainer/games/high_low/state/high_low_game_state.dart';

/// Regression coverage for a caption-truncation bug Cooper found driving
/// the simulator (twice now, per his own note): the header is tight
/// between the close button and the Skip pill, and a caption long enough
/// to need a third line ellipsizes *before* the pole word it exists to
/// carry — "Let them tap both and find the …" tells a half-attending
/// parent nothing.
///
/// This checks a character budget, not a pixel measurement. A real
/// pixel-fit check was tried first (`RenderParagraph.didExceedMaxLines`
/// against the real `HighLowHeader`) and abandoned: `google_fonts` can't
/// reach the network in a widget test, and the fallback Flutter substitutes
/// for the unregistered font family measures nothing like the real one —
/// the Skip pill's own text measured 349px wide against a real, on-device
/// width nowhere near that, which starved the caption of room it actually
/// has and made even the shortest caption look like it was overflowing.
/// Loading the real font files via `FontLoader` didn't fix it either — the
/// measured width was bit-for-bit identical before and after loading, and
/// a minimal isolated repro (a bare `Text` in a width-constrained
/// `SizedBox`) didn't respect the constraint at all in this harness. That's
/// a real, reproducible dead end in this environment, not a tuning
/// problem, so this test doesn't claim to simulate the device's rendering.
///
/// The budget below (see [_maxCaptionLength]) is a character count derived
/// from Cooper's own shortened example ("Let them tap both and find the
/// higher one.", 43 characters) plus a little margin — cruder than a real
/// fit check, but honest about what it actually verifies: nobody
/// accidentally reintroduces a caption long enough to be the kind of
/// regression that caused this bug (the original, sparkle-clause version
/// this replaced was 89 characters). It cannot prove a caption fits any
/// particular device's screen.
///
/// Every (stage, pole) primary caption and every secondary caption is
/// generated from the real [HighLowGameState] getters rather than
/// hand-copied here — the copy will keep changing (this is the second
/// time it's caused a real bug), so the test needs to keep up
/// automatically rather than needing a matching hand-edit every time.
void main() {
  // Cooper's own shortened example ("Let them tap both and find the higher
  // one.") is 43 characters; the six captions here landed at 42-47. A
  // round number a few characters above that is enough to catch a real
  // regression (a caption creeping back toward the old ~89-character
  // version) without being so tight it breaks on a one-word tweak.
  const maxCaptionLength = 50;

  /// Every primary caption (both poles, every stage) and every secondary
  /// caption (Participate only — see
  /// [HighLowGameState.secondaryCaptionText]'s doc comment for why
  /// Observe/Trigger's secondary nudge is the move-on control instead of
  /// text). Round 1 is always "higher" and round 2 always "lower" under
  /// blocked order once totalPrompts >= 3 (see RoundSequencer.sequence) —
  /// two separate states per stage, one escaped once, rather than relying
  /// on a third round (whose direction RoundSequencer leaves random).
  Future<List<String>> allCaptions(WidgetTester tester) async {
    final captions = <String>[];

    for (final stage in AgencyStage.values) {
      final higherState = HighLowGameState(
        totalPrompts: 3,
        agencyStage: stage,
        roundOrder: RoundOrder.blocked,
      );
      higherState.startGame();
      captions.add(higherState.captionText!);
      if (stage == AgencyStage.participate) {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4700));
        await tester.pump(const Duration(seconds: 6));
        captions.add(higherState.secondaryCaptionText!);
      }
      higherState.dispose();

      final lowerState = HighLowGameState(
        totalPrompts: 3,
        agencyStage: stage,
        roundOrder: RoundOrder.blocked,
      );
      lowerState.startGame();
      lowerState.escape();
      captions.add(lowerState.captionText!);
      if (stage == AgencyStage.participate) {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4700));
        await tester.pump(const Duration(seconds: 6));
        captions.add(lowerState.secondaryCaptionText!);
      }
      lowerState.dispose();
    }

    return captions;
  }

  testWidgets(
    'no caption exceeds the character budget, at any stage or pole '
    '(Cooper, driving the simulator: "\'Find the …\' tells them nothing")',
    (tester) async {
      final captions = await allCaptions(tester);
      expect(
        captions.toSet(),
        hasLength(7),
        reason:
            '5 distinct primary captions (Observe\'s two poles collapse '
            'to one string by design, plus Participate\'s 2 and '
            'Trigger\'s 2) + 2 secondary (Participate only) = 7 distinct '
            'captions expected — a length mismatch means this test '
            'itself needs updating alongside the copy, not that a '
            'caption is missing',
      );

      for (final caption in captions) {
        expect(
          caption.length,
          lessThanOrEqualTo(maxCaptionLength),
          reason:
              'caption is ${caption.length} characters, over the '
              '$maxCaptionLength budget — shorten it, don\'t grow the '
              'caption block: "$caption"',
        );
      }
    },
  );
}

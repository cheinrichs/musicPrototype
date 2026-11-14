import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The reading gate (modelled on reading.com's): three numbers spelled as
/// WORDS, tapped in order from a 3×3 grid of NUMERALS. The barrier is
/// reading, so a numeral never leaks into the prompt.
///
/// ⚠️ A SIGNPOST, NOT A LOCK (Cooper: "the gate is more a reminder that
/// you're on mommy's special dev profile, not yours. Go back."). So:
/// - the EXIT is the important part — one large, obvious top-corner tap,
///   no sense of having done anything wrong;
/// - the grid is plain (no hardened distractors);
/// - a wrong tap quietly resets the attempt, never scolds;
/// - no voice line.
///
/// REUSABLE: the dev profile is its first caller, a parent settings area
/// on the picker its next. It holds NOTHING: a fresh prompt every time,
/// nothing entered is stored, and passing it sets no "adult verified" flag
/// — [ReadingGate.ask] re-asks on every use, so a child who just watched a
/// parent pass it meets it again.
class ReadingGate extends StatefulWidget {
  final ReadingGatePuzzle puzzle;

  const ReadingGate({super.key, required this.puzzle});

  /// Shows the gate over everything; true once passed, false if the person
  /// backed out. Every call is a new puzzle.
  static Future<bool> ask(BuildContext context, {math.Random? random}) async {
    final passed = await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) =>
            ReadingGate(puzzle: ReadingGatePuzzle.generate(random)),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    return passed ?? false;
  }

  @override
  State<ReadingGate> createState() => _ReadingGateState();
}

class _ReadingGateState extends State<ReadingGate> {
  /// How many of the targets have been tapped, in order.
  int _progress = 0;

  void _tap(int number) {
    final targets = widget.puzzle.targets;
    if (number != targets[_progress]) {
      // Quietly start over: no shake, no sound, no message.
      setState(() => _progress = 0);
      return;
    }
    if (_progress + 1 == targets.length) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _progress++);
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.puzzle;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl + AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('For grown-ups', style: AppTypography.heading2),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Tap these numbers in order:',
                          style: AppTypography.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final words in puzzle.words)
                          Text(
                            words,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  AspectRatio(aspectRatio: 1, child: _grid(puzzle)),
                ],
              ),
            ),
            // THE WAY OUT: large, top corner, one tap.
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: Semantics(
                button: true,
                label: 'Go back',
                child: Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.cardEdge, width: 2),
                  ),
                  child: InkWell(
                    key: const ValueKey('reading-gate-exit'),
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(false),
                    child: const SizedBox.square(
                      dimension: AppSpacing.xxxl,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 36,
                        color: AppColors.inkBrown,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(ReadingGatePuzzle puzzle) => GridView.count(
    crossAxisCount: 3,
    mainAxisSpacing: AppSpacing.sm,
    crossAxisSpacing: AppSpacing.sm,
    physics: const NeverScrollableScrollPhysics(),
    children: [
      for (final n in puzzle.grid)
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InkWell(
            key: ValueKey('reading-gate-$n'),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: () => _tap(n),
            child: Center(
              child: Text(
                '$n',
                style: AppTypography.heading2.copyWith(fontSize: 26),
              ),
            ),
          ),
        ),
    ],
  );
}

/// One gate's numbers: three targets, in order, and the nine shown.
class ReadingGatePuzzle {
  final List<int> targets;
  final List<int> grid;

  /// [grid] holds nine numbers, [targets] three of them.
  const ReadingGatePuzzle({required this.targets, required this.grid});

  /// Nine distinct two-digit numbers, three of them the targets — plain,
  /// as the gate is a signpost (no hardened distractors).
  factory ReadingGatePuzzle.generate([math.Random? random]) {
    final r = random ?? math.Random();
    final pool = <int>{};
    while (pool.length < 9) {
      pool.add(21 + r.nextInt(79)); // 21–99: every one two words
    }
    final grid = pool.toList()..shuffle(r);
    final targets = (List.of(grid)..shuffle(r)).take(3).toList();
    return ReadingGatePuzzle(targets: targets, grid: grid);
  }

  /// The targets as the prompt shows them: WORDS, never numerals.
  List<String> get words => [for (final t in targets) numberInWords(t)];
}

const _units = [
  '',
  'ONE',
  'TWO',
  'THREE',
  'FOUR',
  'FIVE',
  'SIX',
  'SEVEN',
  'EIGHT',
  'NINE',
];
const _teens = [
  'TEN',
  'ELEVEN',
  'TWELVE',
  'THIRTEEN',
  'FOURTEEN',
  'FIFTEEN',
  'SIXTEEN',
  'SEVENTEEN',
  'EIGHTEEN',
  'NINETEEN',
];
const _tens = [
  '',
  '',
  'TWENTY',
  'THIRTY',
  'FORTY',
  'FIFTY',
  'SIXTY',
  'SEVENTY',
  'EIGHTY',
  'NINETY',
];

/// 1–99 in capitals: "FORTY-TWO".
String numberInWords(int n) {
  assert(n >= 1 && n <= 99);
  if (n < 10) return _units[n];
  if (n < 20) return _teens[n - 10];
  final unit = n % 10;
  return unit == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]}-${_units[unit]}';
}

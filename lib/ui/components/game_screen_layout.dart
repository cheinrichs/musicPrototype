import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Shared scaffold for the per-prompt ear-training game screens.
///
/// The original screens stacked `header -> Spacer() -> content -> Spacer()
/// -> controls` and relied on portrait's generous vertical space for the
/// Spacers to lay things out nicely. Now that the app is locked to
/// landscape (much shorter, wider viewport), that pattern would overflow
/// or squash badly, so this shell instead centers a scrollable [body]
/// between a fixed [header] and an optional fixed [footer] — it degrades
/// gracefully at any height instead of assuming one.
class GameScreenLayout extends StatelessWidget {
  final Widget header;
  final Widget body;
  final Widget? footer;
  final Widget? background;

  /// Whether [body] sits in a [SingleChildScrollView] between [header] and
  /// [footer]. Defaults to true — most screens' bodies size to their own
  /// content and this is a graceful fallback for the rare tight viewport
  /// where that content would otherwise overflow.
  ///
  /// Set false when a screen both (a) already guarantees its body never
  /// overflows (e.g. its own `FittedBox(fit: BoxFit.scaleDown)` budget) and
  /// (b) stacks interactive content — drag targets, draggables — in
  /// [background] beneath this shell: a `Scrollable`'s hit-testing claims
  /// its *entire* viewport, not just the area its content actually paints,
  /// so it silently absorbs every touch meant for that layer underneath
  /// (High/Low, Trello card — drag-to-answer stopped landing because the
  /// scroll view in front of it intercepted the gesture before it reached
  /// the characters/instruments). With this false, [body] sits in a plain
  /// `Center` instead, which only hit-tests where it actually paints.
  final bool scrollableBody;

  const GameScreenLayout({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.background,
    this.scrollableBody = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (background != null) background!,
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: Center(
                      child: scrollableBody
                          ? SingleChildScrollView(child: body)
                          : body,
                    ),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

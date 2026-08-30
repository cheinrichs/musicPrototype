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

  const GameScreenLayout({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.background,
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
                      child: SingleChildScrollView(child: body),
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

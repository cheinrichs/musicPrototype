import 'package:flutter/material.dart';
import '../../app/build_info.dart';
import '../../app/credits_data.dart';
import '../theme/theme.dart';

/// Plain scrolling attribution list, behind the home screen's
/// [AdultDoor] (Trello card rDHLTn8u) — a prerequisite for shipping the
/// InspectorJ hand bells, which are CC BY and require credit.
///
/// Deliberately unstyled beyond basic Material defaults: no character
/// art, no animation, nothing that would read as an invitation to a
/// child rather than the "nobody reads it, everybody expects it to
/// exist" reference page it actually is. Content lives in
/// [creditSections] (credits_data.dart) — this screen only renders
/// whatever's there, so a future sample source is a new entry in that
/// file, not a change here.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About & Credits')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final section in creditSections) ...[
            _SectionHeading(section.heading),
            for (final entry in section.entries) _EntryTile(entry),
            const SizedBox(height: AppSpacing.lg),
          ],
          _SectionHeading('App'),
          const _BuildInfoTile(),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final CreditEntry entry;
  const _EntryTile(this.entry);

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.title, style: Theme.of(context).textTheme.bodyLarge),
          if (entry.creator != null) Text(entry.creator!, style: bodyStyle),
          if (entry.license != null) Text(entry.license!, style: bodyStyle),
          if (entry.sourceUrl != null) Text(entry.sourceUrl!, style: bodyStyle),
          if (entry.note != null) Text(entry.note!, style: bodyStyle),
        ],
      ),
    );
  }
}

/// App version/build number, read live from the installed binary rather
/// than stated anywhere as static text — the whole point is that it's
/// always right for whatever build a tester actually has open (Trello
/// card rDHLTn8u: "exactly what you want a tester able to read out when
/// something goes wrong"). [BuildInfo.current] hits a platform channel
/// that widget tests can't satisfy — this shows nothing rather than an
/// error in that case, since a missing version line here is harmless and
/// the failure is expected outside a real device/simulator.
class _BuildInfoTile extends StatelessWidget {
  const _BuildInfoTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BuildInfo>(
      future: BuildInfo.current(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            'Version ${info.appVersion} (build ${info.buildNumber})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}

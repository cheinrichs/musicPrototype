import 'package:flutter/material.dart';

import '../../app/state/profile_state.dart';
import '../../journey/journey_art.dart';
import '../../models/agency_stage.dart';
import '../../models/profile.dart';
import '../theme/theme.dart';

/// The setup quiz (Trello card 202): the few things we must ask a parent.
///
/// ⚠️ FOUR QUESTIONS, NEVER MORE — a parent with two children does this
/// twice before anyone has played: the name, a picture, the drag question
/// (→ agency), the age band. Anything that can be inferred from play is.
///
/// Plain and warm: the app talking to a parent, not the characters to a
/// child. Every answer is a STARTING POINT, not a verdict — play overrides
/// it — and re-takeable from behind the adult door.
class SetupQuizScreen extends StatefulWidget {
  /// Avatars other children on this device already wear: not offered, so
  /// no two siblings share a face.
  final Set<int> takenAvatars;

  const SetupQuizScreen({super.key, this.takenAvatars = const {}});

  /// Runs the quiz; its answers, or null if it was abandoned. ⚠️ Nothing is
  /// written until it COMPLETES: the answers live only in this screen, so
  /// backing out leaves no half-made profile (Cooper, 2026-11-15).
  static Future<SetupAnswers?> run(
    BuildContext context, {
    Set<int> takenAvatars = const {},
  }) => Navigator.of(context, rootNavigator: true).push<SetupAnswers>(
    MaterialPageRoute(
      builder: (_) => SetupQuizScreen(takenAvatars: takenAvatars),
    ),
  );

  @override
  State<SetupQuizScreen> createState() => _SetupQuizScreenState();
}

/// The drag question's three answers (card 202), asked about the GESTURE,
/// never the age.
const dragAnswers = {
  AgencyStage.observe: 'Not yet — they watch',
  AgencyStage.explore: 'They tap and poke at things',
  AgencyStage.decide: 'Yes, they drag things',
};

class _SetupQuizScreenState extends State<SetupQuizScreen> {
  static const _questions = 4;
  int _page = 0;
  late final TextEditingController _name;
  int? _avatar;
  AgencyStage? _agency;
  AgeBand? _ageBand;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canGoOn => switch (_page) {
    0 => _name.text.trim().isNotEmpty,
    1 => _avatar != null,
    2 => _agency != null,
    _ => _ageBand != null,
  };

  void _next() {
    if (!_canGoOn) return;
    if (_page < _questions - 1) {
      FocusScope.of(context).unfocus();
      setState(() => _page++);
      return;
    }
    Navigator.of(context).pop(
      SetupAnswers(
        name: _name.text.trim(),
        avatar: _avatar!,
        agency: _agency!,
        ageBand: _ageBand!,
      ),
    );
  }

  /// ONE TAP ABANDONS, from ANY question (Cooper): back does not step
  /// through the questions, it leaves the whole flow, and nothing is saved.
  /// A child three questions in escapes in a single tap. Losing a parent's
  /// partial answers is fine: settings can edit every field afterwards.
  void _abandon() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('quiz-back'),
                    tooltip: 'Back to the players',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _abandon,
                  ),
                  const Spacer(),
                  Text(
                    '${_page + 1} of $_questions',
                    style: AppTypography.label,
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('quiz-next'),
                    onPressed: _canGoOn ? _next : null,
                    child: Text(_page == _questions - 1 ? 'Done' : 'Next'),
                  ),
                ],
              ),
              Expanded(
                child: switch (_page) {
                  0 => _namePage(),
                  1 => _picturePage(),
                  2 => _choicePage(
                    title: 'Can your child drag things around on a screen?',
                    note:
                        'This sets where play starts. The games adjust as '
                        'they go.',
                    options: dragAnswers,
                    selected: _agency,
                    onSelected: (a) => setState(() => _agency = a),
                  ),
                  _ => _choicePage(
                    title: 'How old is your child?',
                    note: 'An age range, never a birthday.',
                    options: {for (final b in AgeBand.values) b: b.label},
                    selected: _ageBand,
                    onSelected: (b) => setState(() => _ageBand = b),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String note) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTypography.heading3),
      const SizedBox(height: AppSpacing.xs),
      Text(note, style: AppTypography.bodyMedium),
      const SizedBox(height: AppSpacing.sm),
    ],
  );

  Widget _namePage() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          "What's your child's name?",
          'Shown only on the player picker.',
        ),
        TextField(
          key: const ValueKey('quiz-name'),
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _next(),
        ),
      ],
    ),
  );

  Widget _picturePage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Choose a picture',
        "If your child is with you, let them pick — it's how they'll find "
            'their player.',
      ),
      Expanded(
        child: AvatarGrid(
          taken: widget.takenAvatars,
          selected: _avatar,
          onSelected: (i) => setState(() => _avatar = i),
        ),
      ),
    ],
  );

  Widget _choicePage<T>({
    required String title,
    required String note,
    required Map<T, String> options,
    required T? selected,
    required ValueChanged<T> onSelected,
  }) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(title, note),
        for (final MapEntry(:key, :value) in options.entries) ...[
          _Choice(
            key: ValueKey('quiz-choice-$key'),
            label: value,
            selected: selected == key,
            onTap: () => onSelected(key),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    ),
  );
}

/// The sixteen avatars, minus any [taken] by another child on this device
/// (hidden, not greyed: a greyed face is a thing withheld). Two rows of
/// eight, fitting a landscape phone. Shared by the setup quiz and the
/// settings chooser.
class AvatarGrid extends StatelessWidget {
  final Set<int> taken;
  final int? selected;
  final ValueChanged<int> onSelected;

  const AvatarGrid({
    super.key,
    required this.taken,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const perRow = 8;
      final side = ((c.maxWidth - (perRow - 1) * AppSpacing.sm) / perRow)
          .clamp(0.0, (c.maxHeight - AppSpacing.sm) / 2)
          .toDouble();
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (var i = 0; i < Profile.avatarCount; i++)
            if (!taken.contains(i))
              _AvatarChoice(
                index: i,
                side: side,
                selected: selected == i,
                onTap: () => onSelected(i),
              ),
        ],
      );
    },
  );
}

class _AvatarChoice extends StatelessWidget {
  final int index;
  final double side;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarChoice({
    required this.index,
    required this.side,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('quiz-avatar-$index'),
    onTap: onTap,
    child: AnimatedContainer(
      duration: AppAnimations.fast,
      width: side,
      height: side,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.gold : Colors.transparent,
          width: 4,
        ),
      ),
      child: AvatarBadge(index: index),
    ),
  );
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.ivoryDeep : AppColors.surface,
    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.cardEdge,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.bodyLarge)),
            if (selected)
              const Icon(Icons.check_rounded, color: AppColors.goldDeep),
          ],
        ),
      ),
    ),
  );
}

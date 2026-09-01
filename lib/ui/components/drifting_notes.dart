import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/theme.dart';

/// Two small music notes that drift up and fade while a character's note
/// is sounding — shared between the High/Low game and the Sound Playground
/// (Trello card 96) so tapping/playing an instrument reads the same way
/// everywhere. Deliberately understated: this is a listening game for young
/// children, so the motion must read as a light echo of the sound, not
/// compete with it for attention.
class DriftingNotes extends StatelessWidget {
  final double size;
  final bool active;

  const DriftingNotes({super.key, required this.size, required this.active});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: AppAnimations.fast,
        child: SizedBox(
          width: size,
          height: size * 0.6,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _note(left: size * 0.12, delay: Duration.zero, dx: -size * 0.12),
              _note(
                left: size * 0.58,
                delay: const Duration(milliseconds: 400),
                dx: size * 0.12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _note({
    required double left,
    required Duration delay,
    required double dx,
  }) {
    return Positioned(
      left: left,
      bottom: 0,
      child:
          Text(
                '♪',
                style: TextStyle(fontSize: size * 0.2, color: AppColors.gold),
              )
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(delay: delay, duration: const Duration(milliseconds: 250))
              .moveY(
                begin: 0,
                end: -size * 0.5,
                delay: delay,
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOut,
              )
              .moveX(
                begin: 0,
                end: dx,
                delay: delay,
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOut,
              )
              .fadeOut(
                delay: delay + const Duration(milliseconds: 700),
                duration: const Duration(milliseconds: 400),
              ),
    );
  }
}

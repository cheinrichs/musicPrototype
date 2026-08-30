import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/router.dart';
import '../../app/state/progress_state.dart';
import '../../models/path_node.dart';
import '../components/path_node_widget.dart';
import '../theme/theme.dart';

class LearningPathScreen extends StatelessWidget {
  const LearningPathScreen({super.key});

  // Layout constants
  static const double _topPadding = 80;
  static const double _rowHeight = 140;
  static const double _bottomPadding = 60;
  static const double _nodeWidgetWidth = 100;
  static const double _circleHalf = 44;
  static const double _leftX = 88;
  static const double _rightInset = 88;
  static const double _markerSize = 40;

  // Node definitions — state is computed dynamically from ProgressState.
  static const List<PathNode> _nodeDefinitions = [
    PathNode(
      id: 'high_low',
      title: 'High vs Low',
      icon: Icons.arrow_upward_rounded,
      state: NodeState.locked,
      gameRoute: AppRoutes.highLow,
    ),
    PathNode(
      id: 'same_different',
      title: 'Same or Different?',
      icon: Icons.compare_arrows_rounded,
      state: NodeState.locked,
      gameRoute: AppRoutes.sameDifferent,
    ),
    PathNode(
      id: 'match_note',
      title: 'Match the Note',
      icon: Icons.music_note_rounded,
      state: NodeState.locked,
      gameRoute: AppRoutes.matchNote,
    ),
    PathNode(
      id: 'scale_direction',
      title: 'Scale Direction',
      icon: Icons.trending_up_rounded,
      state: NodeState.locked,
      gameRoute: AppRoutes.scaleDirection,
    ),
    PathNode(
      id: 'interval_id',
      title: 'Intervals',
      icon: Icons.linear_scale_rounded,
      state: NodeState.locked,
      gameRoute: AppRoutes.intervalId,
    ),
    PathNode(
      id: 'chord_id',
      title: 'Chord ID',
      icon: Icons.library_music_rounded,
      state: NodeState.locked,
      gameRoute: AppRoutes.chordId,
    ),
    PathNode(
      id: 'timbre_id',
      title: 'Which Instrument?',
      icon: Icons.spatial_audio_rounded,
      state: NodeState.locked,
      gameRoute: AppRoutes.timbreId,
    ),
    PathNode(
      id: 'rhythm_id',
      title: 'Same Beat?',
      icon: Icons.av_timer_rounded,
      state: NodeState.locked,
      gameRoute: AppRoutes.rhythmId,
    ),
    PathNode(
      id: 'pitch_name',
      title: 'Name That Note',
      icon: Icons.music_note_rounded,
      state: NodeState.locked,
      gameRoute: AppRoutes.pitchName,
    ),
  ];

  /// Derive NodeState for each node from the persisted completed set.
  List<PathNode> _computeNodes(Set<String> completedIds) {
    bool activeAssigned = false;
    return _nodeDefinitions.map((node) {
      if (completedIds.contains(node.id)) {
        return PathNode(
          id: node.id,
          title: node.title,
          icon: node.icon,
          state: NodeState.completed,
          gameRoute: node.gameRoute,
        );
      } else if (!activeAssigned) {
        activeAssigned = true;
        return PathNode(
          id: node.id,
          title: node.title,
          icon: node.icon,
          state: NodeState.active,
          gameRoute: node.gameRoute,
        );
      }
      return node; // locked
    }).toList();
  }

  double _xFor(int index, double width) {
    switch (index % 3) {
      case 0:
        return _leftX;
      case 1:
        return width / 2;
      case 2:
        return width - _rightInset;
      default:
        return width / 2;
    }
  }

  double _yFor(int index) {
    return _topPadding + index * _rowHeight + _circleHalf;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Forest backdrop — from SongStone-UI-Kit
          // (assets/images/backgrounds/learning_paths/Forest.png). Every
          // node currently uses this one background; per-node/per-stage
          // art can be swapped in once unlock milestones are designed.
          Image.asset(
            'assets/images/backgrounds/learning_paths/Forest.png',
            fit: BoxFit.cover,
          ),
          // Soft scrim so text/nodes stay legible over the illustration.
          Container(color: AppColors.background.withValues(alpha: 0.55)),
          SafeArea(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'Learning Path',
            style: AppTypography.heading2.copyWith(color: AppColors.primary),
          ),
        ),
            Expanded(
              child: Consumer<ProgressState>(
                builder: (context, progress, _) {
                  final nodes = _computeNodes(progress.completedNodeIds);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final centers = List.generate(
                        nodes.length,
                        (i) => Offset(_xFor(i, width), _yFor(i)),
                      );
                      final totalHeight =
                          _topPadding +
                          nodes.length * _rowHeight +
                          _bottomPadding;
                      final activeIndex = nodes.indexWhere(
                        (n) => n.state == NodeState.active,
                      );

                      return SingleChildScrollView(
                        child: SizedBox(
                          width: width,
                          height: totalHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Connection lines
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _PathLinePainter(
                                    nodeCenters: centers,
                                  ),
                                ),
                              ),
                              // Player marker — AnimatedPositioned slides
                              // smoothly when activeIndex changes.
                              if (activeIndex != -1)
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOutCubic,
                                  left:
                                      centers[activeIndex].dx - _markerSize / 2,
                                  top:
                                      centers[activeIndex].dy -
                                      _circleHalf -
                                      _markerSize -
                                      6,
                                  child: const _PlayerMarker(),
                                ),
                              // Nodes
                              for (int i = 0; i < nodes.length; i++)
                                Positioned(
                                  left: centers[i].dx - _nodeWidgetWidth / 2,
                                  top: centers[i].dy - _circleHalf,
                                  width: _nodeWidgetWidth,
                                  child: PathNodeWidget(
                                    node: nodes[i],
                                    onTap:
                                        nodes[i].state == NodeState.active &&
                                            nodes[i].gameRoute != null
                                        ? () => context.go(
                                            nodes[i].gameRoute!,
                                            extra: {
                                              'fromPath': true,
                                              'nodeId': nodes[i].id,
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              // All-done banner when every node is completed
                              if (activeIndex == -1)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: _bottomPadding,
                                  child: Center(
                                    child: Text(
                                      '🎉 Path complete!',
                                      style: AppTypography.heading3.copyWith(
                                        color: AppColors.correct,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
  }
}

// ---------------------------------------------------------------------------
// Player marker
// ---------------------------------------------------------------------------

class _PlayerMarker extends StatelessWidget {
  const _PlayerMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
    );
  }
}

// ---------------------------------------------------------------------------
// CustomPainter — curved lines connecting nodes
// ---------------------------------------------------------------------------

class _PathLinePainter extends CustomPainter {
  final List<Offset> nodeCenters;

  const _PathLinePainter({required this.nodeCenters});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodeCenters.length < 2) return;

    final paint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.55)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < nodeCenters.length - 1; i++) {
      final start = nodeCenters[i];
      final end = nodeCenters[i + 1];
      final midY = (start.dy + end.dy) / 2;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PathLinePainter oldDelegate) =>
      oldDelegate.nodeCenters != nodeCenters;
}

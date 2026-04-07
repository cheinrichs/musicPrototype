import 'package:flutter/material.dart';

enum NodeState { completed, active, locked }

class PathNode {
  final String id;
  final String title;
  final IconData icon;
  final NodeState state;
  final String? gameRoute;

  const PathNode({
    required this.id,
    required this.title,
    required this.icon,
    required this.state,
    this.gameRoute,
  });
}

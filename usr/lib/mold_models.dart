import 'package:flutter/material.dart';
import 'math_utils.dart';

enum NodeType {
  spore,      // Initial seed
  explorer,   // Seeks food, moves actively
  structural, // Forms the backbone, transfers energy
  sporangium  // Reproductive, creates new spores when energy is high
}

class MoldNode {
  Vec2 pos;
  Vec2 oldPos;
  double radius;
  NodeType type;
  double energy;
  double maxEnergy;
  bool isFixed;

  MoldNode({
    required this.pos,
    required this.type,
    this.radius = 4.0,
    this.energy = 50.0,
    this.maxEnergy = 100.0,
    this.isFixed = false,
  }) : oldPos = pos.clone();

  Color get color {
    switch (type) {
      case NodeType.spore:
        return Colors.white;
      case NodeType.explorer:
        return Colors.cyanAccent;
      case NodeType.structural:
        return Colors.purpleAccent.withOpacity(0.8);
      case NodeType.sporangium:
        return Colors.orangeAccent;
    }
  }
}

class MoldLink {
  MoldNode nodeA;
  MoldNode nodeB;
  double restLength;
  double stiffness;

  MoldLink({
    required this.nodeA,
    required this.nodeB,
    required this.restLength,
    this.stiffness = 0.5,
  });
}

enum EnvType { food, toxin }

class EnvironmentItem {
  Vec2 pos;
  EnvType type;
  double amount;
  double radius;

  EnvironmentItem({
    required this.pos,
    required this.type,
    this.amount = 100.0,
    this.radius = 8.0,
  });
}

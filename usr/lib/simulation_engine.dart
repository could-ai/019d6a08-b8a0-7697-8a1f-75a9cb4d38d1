import 'dart:math';
import 'package:flutter/foundation.dart';
import 'math_utils.dart';
import 'mold_models.dart';

class SimulationEngine extends ChangeNotifier {
  final List<MoldNode> nodes = [];
  final List<MoldLink> links = [];
  final List<EnvironmentItem> environment = [];
  
  final double width;
  final double height;
  final Random _random = Random();

  // Simulation parameters
  final double friction = 0.92; // Fluid drag
  final int constraintIterations = 3;
  final double reproductionEnergy = 80.0;
  final double linkRestLength = 15.0;

  SimulationEngine(this.width, this.height);

  void spawnSpore(Vec2 pos) {
    nodes.add(MoldNode(
      pos: pos,
      type: NodeType.spore,
      energy: 100,
      radius: 6.0,
    ));
    notifyListeners();
  }

  void addEnvironmentItem(Vec2 pos, EnvType type) {
    environment.add(EnvironmentItem(
      pos: pos,
      type: type,
      amount: type == EnvType.food ? 200.0 : 100.0,
      radius: type == EnvType.food ? 6.0 : 10.0,
    ));
    notifyListeners();
  }

  void update(double dt) {
    _applyAI();
    _updatePhysics(dt);
    _satisfyConstraints();
    _handleEnvironmentInteractions();
    _manageEnergyAndEvolution();
    notifyListeners();
  }

  void _applyAI() {
    for (var node in nodes) {
      if (node.type == NodeType.explorer || node.type == NodeType.spore) {
        // Chemotaxis: Find nearest food
        EnvironmentItem? nearestFood;
        double minDistance = double.infinity;

        for (var item in environment) {
          if (item.type == EnvType.food) {
            double dist = node.pos.distanceTo(item.pos);
            if (dist < 150.0 && dist < minDistance) {
              minDistance = dist;
              nearestFood = item;
            }
          }
        }

        if (nearestFood != null) {
          // Apply force towards food
          Vec2 dir = Vec2.subVec(nearestFood.pos, node.pos);
          dir.normalize();
          dir.scale(0.5); // Movement speed
          node.pos.add(dir);
        } else {
          // Random exploration (Brownian motion)
          node.pos.x += (_random.nextDouble() - 0.5) * 1.0;
          node.pos.y += (_random.nextDouble() - 0.5) * 1.0;
        }
      }
    }
  }

  void _updatePhysics(double dt) {
    for (var node in nodes) {
      if (node.isFixed) continue;

      // Verlet integration
      Vec2 velocity = Vec2.subVec(node.pos, node.oldPos);
      velocity.scale(friction); // Apply fluid drag
      
      node.oldPos = node.pos.clone();
      node.pos.add(velocity);

      // Boundary collisions (Petri dish walls)
      if (node.pos.x < node.radius) {
        node.pos.x = node.radius;
        node.oldPos.x = node.pos.x + velocity.x * 0.5;
      } else if (node.pos.x > width - node.radius) {
        node.pos.x = width - node.radius;
        node.oldPos.x = node.pos.x + velocity.x * 0.5;
      }

      if (node.pos.y < node.radius) {
        node.pos.y = node.radius;
        node.oldPos.y = node.pos.y + velocity.y * 0.5;
      } else if (node.pos.y > height - node.radius) {
        node.pos.y = height - node.radius;
        node.oldPos.y = node.pos.y + velocity.y * 0.5;
      }
    }
  }

  void _satisfyConstraints() {
    for (int i = 0; i < constraintIterations; i++) {
      // Link constraints (Springs)
      for (var link in links) {
        Vec2 delta = Vec2.subVec(link.nodeB.pos, link.nodeA.pos);
        double dist = delta.length();
        if (dist == 0) continue;

        double difference = (dist - link.restLength) / dist;
        Vec2 offset = Vec2.scaleVec(delta, difference * 0.5 * link.stiffness);

        if (!link.nodeA.isFixed) link.nodeA.pos.add(offset);
        if (!link.nodeB.isFixed) link.nodeB.pos.sub(offset);
      }

      // Node repulsion (prevent collapsing into a single point)
      // O(N^2) - optimized by only checking nearby nodes in a real scenario, 
      // but fine for small/medium networks.
      for (int j = 0; j < nodes.length; j++) {
        for (int k = j + 1; k < nodes.length; k++) {
          var n1 = nodes[j];
          var n2 = nodes[k];
          Vec2 delta = Vec2.subVec(n1.pos, n2.pos);
          double distSq = delta.lengthSquared();
          double minDist = n1.radius + n2.radius + 2.0;
          
          if (distSq < minDist * minDist && distSq > 0) {
            double dist = sqrt(distSq);
            Vec2 offset = Vec2.scaleVec(delta, (minDist - dist) / dist * 0.5);
            if (!n1.isFixed) n1.pos.add(offset);
            if (!n2.isFixed) n2.pos.sub(offset);
          }
        }
      }
    }
  }

  void _handleEnvironmentInteractions() {
    List<EnvironmentItem> toRemove = [];

    for (var node in nodes) {
      // Base energy cost for living
      node.energy -= 0.05;

      for (var item in environment) {
        double dist = node.pos.distanceTo(item.pos);
        
        if (item.type == EnvType.food && dist < node.radius + item.radius + 5.0) {
          // Consume food
          double consumeRate = min(2.0, item.amount);
          item.amount -= consumeRate;
          node.energy = min(node.maxEnergy, node.energy + consumeRate * 2.0);
          
          if (item.amount <= 0) {
            toRemove.add(item);
          }
        } else if (item.type == EnvType.toxin && dist < node.radius + item.radius + 10.0) {
          // Take damage from toxin
          node.energy -= 1.0;
          // Toxin repels nodes
          Vec2 repel = Vec2.subVec(node.pos, item.pos);
          repel.normalize();
          repel.scale(2.0);
          node.pos.add(repel);
        }
      }
    }

    environment.removeWhere((item) => toRemove.contains(item));
    
    // Remove dead nodes
    List<MoldNode> deadNodes = nodes.where((n) => n.energy <= 0).toList();
    nodes.removeWhere((n) => n.energy <= 0);
    links.removeWhere((l) => deadNodes.contains(l.nodeA) || deadNodes.contains(l.nodeB));
  }

  void _manageEnergyAndEvolution() {
    // Energy sharing across the mycelium network
    for (var link in links) {
      double diff = link.nodeA.energy - link.nodeB.energy;
      if (diff.abs() > 5.0) {
        double transfer = diff * 0.05; // 5% transfer rate
        link.nodeA.energy -= transfer;
        link.nodeB.energy += transfer;
      }
    }

    // Evolution and Reproduction
    List<MoldNode> newNodes = [];
    List<MoldLink> newLinks = [];

    for (var node in nodes) {
      // Role switching based on network position and energy
      if (node.type == NodeType.spore && node.energy > 60) {
        node.type = NodeType.explorer;
      }

      // Reproduction
      if (node.energy > reproductionEnergy && nodes.length < 300) {
        node.energy -= 40.0; // Cost of reproduction
        
        // Determine new node type
        NodeType newType = NodeType.explorer;
        if (_random.nextDouble() > 0.7) {
          node.type = NodeType.structural; // Parent becomes structural
        }

        // Spawn slightly offset
        Vec2 offset = Vec2((_random.nextDouble() - 0.5) * 10, (_random.nextDouble() - 0.5) * 10);
        Vec2 newPos = Vec2.addVec(node.pos, offset);
        
        MoldNode child = MoldNode(
          pos: newPos,
          type: newType,
          energy: 40.0,
        );
        
        newNodes.add(child);
        newLinks.add(MoldLink(
          nodeA: node,
          nodeB: child,
          restLength: linkRestLength,
        ));
      }
    }

    nodes.addAll(newNodes);
    links.addAll(newLinks);
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'math_utils.dart';

enum NodeType {
  spore,      // Dormant reproductive unit
  explorer,   // Actively growing hyphal tip (apical cell)
  structural, // Mature hyphal segment (provides support)
  sporangium  // Reproductive structure (produces spores)
}

enum CellState {
  dormant,     // Metabolically inactive
  active,      // Normal growth and metabolism
  stressed,    // Low resources, reduced activity
  reproducing, // Actively producing spores
  dead         // Non-functional
}

class NutrientStore {
  double glucose;
  double nitrogen;
  double phosphorus;
  
  NutrientStore({
    this.glucose = 0.0,
    this.nitrogen = 0.0,
    this.phosphorus = 0.0,
  });
  
  double totalAmount() => glucose + nitrogen + phosphorus;
  
  NutrientStore clone() => NutrientStore(
    glucose: glucose,
    nitrogen: nitrogen,
    phosphorus: phosphorus,
  );
}

class Genome {
  double growthRate;         // 0.5 - 2.0: Speed of hyphal extension
  double branchingRate;      // 0.1 - 1.0: Frequency of branch formation
  double chemotaxisSensitivity; // 0.5 - 2.0: Response to nutrient gradients
  double sporulationRate;    // 0.1 - 1.0: Likelihood of spore production
  double thigmotropism;      // 0.0 - 1.0: Attraction to surfaces
  
  Genome({
    this.growthRate = 1.0,
    this.branchingRate = 0.5,
    this.chemotaxisSensitivity = 1.0,
    this.sporulationRate = 0.3,
    this.thigmotropism = 0.5,
  });
  
  factory Genome.random(Random rng) {
    return Genome(
      growthRate: 0.5 + rng.nextDouble() * 1.5,
      branchingRate: 0.1 + rng.nextDouble() * 0.9,
      chemotaxisSensitivity: 0.5 + rng.nextDouble() * 1.5,
      sporulationRate: 0.1 + rng.nextDouble() * 0.9,
      thigmotropism: rng.nextDouble(),
    );
  }
  
  Genome clone() => Genome(
    growthRate: growthRate,
    branchingRate: branchingRate,
    chemotaxisSensitivity: chemotaxisSensitivity,
    sporulationRate: sporulationRate,
    thigmotropism: thigmotropism,
  );
  
  void mutate(Random rng) {
    // Small random mutations (±10%)
    if (rng.nextDouble() < 0.3) {
      growthRate = (growthRate * (0.9 + rng.nextDouble() * 0.2)).clamp(0.5, 2.0);
    }
    if (rng.nextDouble() < 0.3) {
      branchingRate = (branchingRate * (0.9 + rng.nextDouble() * 0.2)).clamp(0.1, 1.0);
    }
    if (rng.nextDouble() < 0.3) {
      chemotaxisSensitivity = (chemotaxisSensitivity * (0.9 + rng.nextDouble() * 0.2)).clamp(0.5, 2.0);
    }
    if (rng.nextDouble() < 0.3) {
      sporulationRate = (sporulationRate * (0.9 + rng.nextDouble() * 0.2)).clamp(0.1, 1.0);
    }
    if (rng.nextDouble() < 0.3) {
      thigmotropism = (thigmotropism * (0.9 + rng.nextDouble() * 0.2)).clamp(0.0, 1.0);
    }
  }
}

class MoldNode {
  Vec2 pos;
  Vec2 oldPos;
  double radius;
  NodeType type;
  CellState state;
  
  // Biochemistry
  double energy;
  double maxEnergy;
  NutrientStore nutrients;
  double metabolicRate;
  
  // Structural properties
  double biomass;           // Accumulated cellular mass
  double turgorPressure;    // Internal osmotic pressure (drives growth)
  double wallIntegrity;     // Cell wall strength (0-1)
  
  // Life cycle
  double age;              // Time since creation
  Genome genes;            // Genetic traits
  
  bool isFixed;

  MoldNode({
    required this.pos,
    required this.type,
    this.radius = 4.0,
    this.energy = 50.0,
    this.maxEnergy = 100.0,
    required this.nutrients,
    this.state = CellState.active,
    this.biomass = 1.0,
    this.turgorPressure = 1.0,
    this.wallIntegrity = 1.0,
    this.age = 0.0,
    this.metabolicRate = 0.02,
    required this.genes,
    this.isFixed = false,
  }) : oldPos = pos.clone();

  Color get color {
    // Color based on type and state
    Color baseColor;
    
    switch (type) {
      case NodeType.spore:
        baseColor = Colors.white;
        break;
      case NodeType.explorer:
        baseColor = Colors.cyanAccent;
        break;
      case NodeType.structural:
        baseColor = Colors.purpleAccent;
        break;
      case NodeType.sporangium:
        baseColor = Colors.orangeAccent;
        break;
    }
    
    // Modify opacity based on state
    double alpha = 1.0;
    switch (state) {
      case CellState.dormant:
        alpha = 0.5;
        break;
      case CellState.stressed:
        alpha = 0.7;
        break;
      case CellState.dead:
        alpha = 0.3;
        baseColor = Colors.grey;
        break;
      default:
        alpha = (energy / maxEnergy).clamp(0.3, 1.0);
    }
    
    return baseColor.withOpacity(alpha);
  }
}

enum LinkType {
  hypha,      // Normal hyphal connection
  rhizomorph  // Specialized thick strand (not yet implemented)
}

class MoldLink {
  MoldNode nodeA;
  MoldNode nodeB;
  double restLength;
  double stiffness;
  LinkType type;
  double integrity;  // 0-1: Structural health

  MoldLink({
    required this.nodeA,
    required this.nodeB,
    required this.restLength,
    this.stiffness = 0.5,
    this.type = LinkType.hypha,
    this.integrity = 1.0,
  });
}

enum EnvType { food, toxin }

class EnvironmentItem {
  Vec2 pos;
  EnvType type;
  double amount;
  double radius;
  NutrientStore nutrients;

  EnvironmentItem({
    required this.pos,
    required this.type,
    this.amount = 100.0,
    this.radius = 8.0,
    required this.nutrients,
  });
}
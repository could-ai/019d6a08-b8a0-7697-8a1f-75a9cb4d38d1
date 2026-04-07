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

  // Advanced physics parameters
  final double friction = 0.96; // Cytoplasmic viscosity
  final int constraintIterations = 8; // More iterations for stability
  final double linkRestLength = 12.0;
  final double minLinkLength = 8.0;
  final double maxLinkLength = 25.0;
  
  // Biochemistry
  final double baseMetabolicRate = 0.02;
  final double anaerobicEfficiency = 0.4; // vs aerobic = 1.0
  
  // Environmental grid for diffusion (simplified spatial hashing)
  final int gridSize = 20;
  late List<List<EnvironmentCell>> envGrid;
  
  // Time tracking
  double simulationTime = 0.0;
  
  SimulationEngine(this.width, this.height) {
    _initializeEnvironmentGrid();
  }

  void _initializeEnvironmentGrid() {
    int cols = (width / gridSize).ceil();
    int rows = (height / gridSize).ceil();
    envGrid = List.generate(
      rows,
      (y) => List.generate(
        cols,
        (x) => EnvironmentCell(
          oxygen: 1.0,
          pH: 6.5,
          moisture: 0.8,
          temperature: 25.0,
        ),
      ),
    );
  }

  void spawnSpore(Vec2 pos) {
    nodes.add(MoldNode(
      pos: pos,
      type: NodeType.spore,
      energy: 100,
      radius: 5.0,
      nutrients: NutrientStore(
        glucose: 80.0,
        nitrogen: 40.0,
        phosphorus: 20.0,
      ),
      state: CellState.dormant,
      genes: Genome.random(_random),
    ));
    notifyListeners();
  }

  void addEnvironmentItem(Vec2 pos, EnvType type) {
    environment.add(EnvironmentItem(
      pos: pos,
      type: type,
      amount: type == EnvType.food ? 300.0 : 100.0,
      radius: type == EnvType.food ? 8.0 : 12.0,
      nutrients: type == EnvType.food
          ? NutrientStore(glucose: 200.0, nitrogen: 60.0, phosphorus: 40.0)
          : NutrientStore(glucose: 0.0, nitrogen: 0.0, phosphorus: 0.0),
    ));
    notifyListeners();
  }

  void update(double dt) {
    simulationTime += dt;
    
    _updateEnvironmentDiffusion(dt);
    _updateCellularBiochemistry(dt);
    _applyAdvancedAI(dt);
    _updateHyphalGrowth(dt);
    _updatePhysics(dt);
    _satisfyConstraints();
    _handleEnvironmentInteractions(dt);
    _manageReproduction(dt);
    _manageCellDeath();
    _cytoplasmaticStreaming(dt);
    
    notifyListeners();
  }

  void _updateEnvironmentDiffusion(double dt) {
    // Simulate oxygen and nutrient diffusion in the environment
    for (int y = 0; y < envGrid.length; y++) {
      for (int x = 0; x < envGrid[y].length; x++) {
        var cell = envGrid[y][x];
        
        // Oxygen diffusion from air
        cell.oxygen = min(1.0, cell.oxygen + dt * 0.5 * cell.moisture);
        
        // Moisture evaporation
        cell.moisture = max(0.3, cell.moisture - dt * 0.01);
        
        // pH buffering towards neutral
        cell.pH += (7.0 - cell.pH) * dt * 0.05;
      }
    }
    
    // Oxygen consumption by nodes
    for (var node in nodes) {
      var gridPos = _worldToGrid(node.pos);
      if (_isValidGridPos(gridPos)) {
        var cell = envGrid[gridPos.y.toInt()][gridPos.x.toInt()];
        cell.oxygen = max(0.0, cell.oxygen - dt * 0.1 * (node.metabolicRate / 100.0));
      }
    }
  }

  void _updateCellularBiochemistry(double dt) {
    for (var node in nodes) {
      if (node.state == CellState.dead) continue;
      
      // Get environmental conditions
      var gridPos = _worldToGrid(node.pos);
      double oxygen = 1.0;
      double pH = 7.0;
      
      if (_isValidGridPos(gridPos)) {
        var envCell = envGrid[gridPos.y.toInt()][gridPos.x.toInt()];
        oxygen = envCell.oxygen;
        pH = envCell.pH;
      }
      
      // Metabolic rate influenced by environment
      double tempFactor = 1.0 - (25.0 - 25.0).abs() / 40.0; // Optimal at 25°C
      double pHFactor = 1.0 - (pH - 6.5).abs() / 3.0; // Optimal at pH 6.5
      pHFactor = max(0.1, pHFactor);
      
      node.metabolicRate = baseMetabolicRate * tempFactor * pHFactor;
      
      // ATP production via cellular respiration
      double glucoseUsed = node.metabolicRate * dt * 10.0;
      double efficiency = oxygen > 0.2 ? 1.0 : anaerobicEfficiency;
      
      if (node.nutrients.glucose > glucoseUsed) {
        node.nutrients.glucose -= glucoseUsed;
        node.energy = min(node.maxEnergy, node.energy + glucoseUsed * efficiency * 3.0);
      } else {
        // Starvation
        node.energy -= node.metabolicRate * dt * 50.0;
      }
      
      // Protein synthesis (growth)
      if (node.nutrients.nitrogen > 0.1 && node.nutrients.phosphorus > 0.05) {
        node.nutrients.nitrogen -= dt * 0.05;
        node.nutrients.phosphorus -= dt * 0.02;
        node.biomass += dt * 0.1;
        
        // Size increase with biomass
        node.radius = 4.0 + sqrt(node.biomass) * 0.5;
      }
      
      // Turgor pressure (drives growth)
      node.turgorPressure = (node.nutrients.totalAmount() / 300.0) * 1.5;
      node.turgorPressure = node.turgorPressure.clamp(0.5, 2.0);
      
      // Cell wall stress
      if (node.turgorPressure > 1.8) {
        node.wallIntegrity -= dt * 0.1;
      } else {
        node.wallIntegrity = min(1.0, node.wallIntegrity + dt * 0.05);
      }
      
      // Aging
      node.age += dt;
      if (node.age > 300.0) {
        node.wallIntegrity -= dt * 0.02;
        node.energy -= dt * 0.5;
      }
      
      // State transitions
      if (node.state == CellState.dormant && node.nutrients.glucose > 50) {
        node.state = CellState.active;
      }
      
      if (node.state == CellState.active && node.energy < 10) {
        node.state = CellState.stressed;
      }
      
      if (node.state == CellState.stressed && node.energy > 30) {
        node.state = CellState.active;
      }
    }
  }

  void _applyAdvancedAI(double dt) {
    for (var node in nodes) {
      if (node.state == CellState.dead || node.state == CellState.dormant) continue;
      if (node.type != NodeType.explorer && node.type != NodeType.spore) continue;
      
      // Chemotaxis with gradient sensing
      Vec2 chemotaxisForce = _calculateChemotaxisGradient(node);
      
      // Gravitropism (slight downward bias)
      Vec2 gravitropism = Vec2(0, 0.05);
      
      // Thigmotropism (surface seeking)
      Vec2 thigmotropism = _calculateSurfaceAttraction(node);
      
      // Phototropism (away from light - negative phototropism for mold)
      Vec2 phototropism = Vec2(
        (width / 2 - node.pos.x) * -0.01,
        (height / 2 - node.pos.y) * -0.01,
      );
      
      // Combined tropism response
      Vec2 totalForce = Vec2.zero();
      totalForce.add(Vec2.scaleVec(chemotaxisForce, node.genes.chemotaxisSensitivity));
      totalForce.add(Vec2.scaleVec(gravitropism, 0.1));
      totalForce.add(Vec2.scaleVec(thigmotropism, node.genes.thigmotropism));
      totalForce.add(Vec2.scaleVec(phototropism, 0.05));
      
      // Apply force with energy cost
      if (node.energy > 5) {
        double forceMagnitude = totalForce.length();
        node.energy -= forceMagnitude * dt * 0.5;
        node.pos.add(Vec2.scaleVec(totalForce, dt * 2.0));
      } else {
        // Brownian motion when low energy
        node.pos.x += (_random.nextDouble() - 0.5) * 0.3;
        node.pos.y += (_random.nextDouble() - 0.5) * 0.3;
      }
    }
  }

  Vec2 _calculateChemotaxisGradient(MoldNode node) {
    Vec2 gradient = Vec2.zero();
    double sampleDistance = 20.0;
    
    // Sample environment in multiple directions
    List<double> directions = [0, pi / 4, pi / 2, 3 * pi / 4, pi, 5 * pi / 4, 3 * pi / 2, 7 * pi / 4];
    
    for (double angle in directions) {
      Vec2 samplePos = Vec2(
        node.pos.x + cos(angle) * sampleDistance,
        node.pos.y + sin(angle) * sampleDistance,
      );
      
      double nutrientConcentration = _getNutrientConcentrationAt(samplePos);
      double toxinConcentration = _getToxinConcentrationAt(samplePos);
      
      Vec2 direction = Vec2(cos(angle), sin(angle));
      gradient.add(Vec2.scaleVec(direction, nutrientConcentration - toxinConcentration));
    }
    
    if (gradient.length() > 0) {
      gradient.normalize();
    }
    
    return gradient;
  }

  Vec2 _calculateSurfaceAttraction(MoldNode node) {
    // Mold prefers to grow along surfaces
    Vec2 attraction = Vec2.zero();
    double edgeDistance = 50.0;
    
    if (node.pos.x < edgeDistance) attraction.x = 0.5;
    if (node.pos.x > width - edgeDistance) attraction.x = -0.5;
    if (node.pos.y < edgeDistance) attraction.y = 0.5;
    if (node.pos.y > height - edgeDistance) attraction.y = -0.5;
    
    return attraction;
  }

  double _getNutrientConcentrationAt(Vec2 pos) {
    double concentration = 0.0;
    for (var item in environment) {
      if (item.type == EnvType.food) {
        double dist = pos.distanceTo(item.pos);
        // Exponential decay of concentration
        concentration += item.amount * exp(-dist / 30.0);
      }
    }
    return concentration;
  }

  double _getToxinConcentrationAt(Vec2 pos) {
    double concentration = 0.0;
    for (var item in environment) {
      if (item.type == EnvType.toxin) {
        double dist = pos.distanceTo(item.pos);
        concentration += item.amount * exp(-dist / 40.0);
      }
    }
    return concentration;
  }

  void _updateHyphalGrowth(double dt) {
    List<MoldNode> newNodes = [];
    List<MoldLink> newLinks = [];
    
    for (var node in nodes) {
      if (node.state != CellState.active) continue;
      if (node.type != NodeType.explorer) continue;
      if (node.energy < 30 || node.biomass < 5) continue;
      if (nodes.length > 500) break;
      
      // Apical growth (tip extends)
      if (_random.nextDouble() < node.genes.growthRate * dt * 0.3) {
        // Find growth direction
        Vec2 growthDir = _determineGrowthDirection(node);
        
        // Create new tip cell
        Vec2 newPos = Vec2.addVec(
          node.pos,
          Vec2.scaleVec(growthDir, linkRestLength),
        );
        
        MoldNode newTip = MoldNode(
          pos: newPos,
          type: NodeType.explorer,
          energy: 25.0,
          radius: 3.5,
          nutrients: NutrientStore(
            glucose: 20.0,
            nitrogen: 10.0,
            phosphorus: 5.0,
          ),
          state: CellState.active,
          genes: node.genes.clone(),
        );
        
        newNodes.add(newTip);
        newLinks.add(MoldLink(
          nodeA: node,
          nodeB: newTip,
          restLength: linkRestLength,
          stiffness: 0.6,
          type: LinkType.hypha,
        ));
        
        // Convert parent to structural
        node.type = NodeType.structural;
        
        // Transfer nutrients to new tip
        node.nutrients.glucose -= 15.0;
        node.nutrients.nitrogen -= 8.0;
        node.nutrients.phosphorus -= 4.0;
      }
      
      // Branching
      if (_random.nextDouble() < node.genes.branchingRate * dt * 0.1) {
        double branchAngle = (pi / 3) + (_random.nextDouble() - 0.5) * pi / 6;
        branchAngle *= _random.nextBool() ? 1 : -1;
        
        Vec2 branchDir = _determineGrowthDirection(node);
        branchDir = _rotateVector(branchDir, branchAngle);
        
        Vec2 branchPos = Vec2.addVec(
          node.pos,
          Vec2.scaleVec(branchDir, linkRestLength * 0.8),
        );
        
        MoldNode branch = MoldNode(
          pos: branchPos,
          type: NodeType.explorer,
          energy: 20.0,
          radius: 3.0,
          nutrients: NutrientStore(
            glucose: 15.0,
            nitrogen: 8.0,
            phosphorus: 4.0,
          ),
          state: CellState.active,
          genes: node.genes.clone(),
        );
        
        newNodes.add(branch);
        newLinks.add(MoldLink(
          nodeA: node,
          nodeB: branch,
          restLength: linkRestLength * 0.8,
          stiffness: 0.5,
          type: LinkType.hypha,
        ));
        
        node.nutrients.glucose -= 12.0;
        node.nutrients.nitrogen -= 6.0;
      }
    }
    
    nodes.addAll(newNodes);
    links.addAll(newLinks);
  }

  Vec2 _determineGrowthDirection(MoldNode node) {
    // Average direction from existing connections
    Vec2 avgDir = Vec2.zero();
    int count = 0;
    
    for (var link in links) {
      if (link.nodeA == node) {
        Vec2 dir = Vec2.subVec(node.pos, link.nodeB.pos);
        dir.normalize();
        avgDir.add(dir);
        count++;
      } else if (link.nodeB == node) {
        Vec2 dir = Vec2.subVec(node.pos, link.nodeA.pos);
        dir.normalize();
        avgDir.add(dir);
        count++;
      }
    }
    
    if (count > 0) {
      avgDir.scale(1.0 / count);
    } else {
      // Random if no connections
      double angle = _random.nextDouble() * 2 * pi;
      avgDir = Vec2(cos(angle), sin(angle));
    }
    
    // Add some randomness
    double perturbation = (_random.nextDouble() - 0.5) * pi / 4;
    avgDir = _rotateVector(avgDir, perturbation);
    
    if (avgDir.length() > 0) {
      avgDir.normalize();
    } else {
      avgDir = Vec2(1, 0);
    }
    
    return avgDir;
  }

  Vec2 _rotateVector(Vec2 v, double angle) {
    double cos_a = cos(angle);
    double sin_a = sin(angle);
    return Vec2(
      v.x * cos_a - v.y * sin_a,
      v.x * sin_a + v.y * cos_a,
    );
  }

  void _updatePhysics(double dt) {
    for (var node in nodes) {
      if (node.isFixed || node.state == CellState.dead) continue;

      // Verlet integration with damping
      Vec2 velocity = Vec2.subVec(node.pos, node.oldPos);
      velocity.scale(friction);
      
      node.oldPos = node.pos.clone();
      node.pos.add(velocity);

      // Turgor pressure expansion
      if (node.turgorPressure > 1.2 && node.biomass > 3) {
        Vec2 expansion = Vec2.scaleVec(velocity, (node.turgorPressure - 1.0) * 0.1);
        node.pos.add(expansion);
      }

      // Boundary collisions with realistic response
      double restitution = 0.3; // Energy loss on collision
      
      if (node.pos.x < node.radius) {
        node.pos.x = node.radius;
        node.oldPos.x = node.pos.x + velocity.x * restitution;
        node.wallIntegrity -= 0.01; // Damage from collision
      } else if (node.pos.x > width - node.radius) {
        node.pos.x = width - node.radius;
        node.oldPos.x = node.pos.x + velocity.x * restitution;
        node.wallIntegrity -= 0.01;
      }

      if (node.pos.y < node.radius) {
        node.pos.y = node.radius;
        node.oldPos.y = node.pos.y + velocity.y * restitution;
        node.wallIntegrity -= 0.01;
      } else if (node.pos.y > height - node.radius) {
        node.pos.y = height - node.radius;
        node.oldPos.y = node.pos.y + velocity.y * restitution;
        node.wallIntegrity -= 0.01;
      }
    }
  }

  void _satisfyConstraints() {
    for (int i = 0; i < constraintIterations; i++) {
      // Hyphal link constraints with realistic mechanics
      for (var link in links) {
        if (link.nodeA.state == CellState.dead || link.nodeB.state == CellState.dead) continue;
        
        Vec2 delta = Vec2.subVec(link.nodeB.pos, link.nodeA.pos);
        double dist = delta.length();
        if (dist < 0.001) continue;

        // Cell wall elasticity and plasticity
        double avgWallIntegrity = (link.nodeA.wallIntegrity + link.nodeB.wallIntegrity) / 2;
        double effectiveStiffness = link.stiffness * avgWallIntegrity;
        
        // Allow some stretching before breaking
        double strain = (dist - link.restLength) / link.restLength;
        
        if (strain.abs() > 0.5) {
          // Plastic deformation
          link.restLength += strain * 0.1;
          link.integrity -= 0.001;
        }
        
        if (strain.abs() > 1.0) {
          // Link breaking
          link.integrity -= 0.01;
        }
        
        double difference = (dist - link.restLength) / dist;
        Vec2 offset = Vec2.scaleVec(delta, difference * 0.5 * effectiveStiffness);

        if (!link.nodeA.isFixed && link.nodeA.state == CellState.active) {
          link.nodeA.pos.add(offset);
        }
        if (!link.nodeB.isFixed && link.nodeB.state == CellState.active) {
          link.nodeB.pos.sub(offset);
        }
      }

      // Cell-cell repulsion with realistic mechanics
      for (int j = 0; j < nodes.length; j++) {
        for (int k = j + 1; k < nodes.length; k++) {
          var n1 = nodes[j];
          var n2 = nodes[k];
          
          if (n1.state == CellState.dead || n2.state == CellState.dead) continue;
          
          Vec2 delta = Vec2.subVec(n1.pos, n2.pos);
          double distSq = delta.lengthSquared();
          double minDist = n1.radius + n2.radius;
          
          if (distSq < minDist * minDist && distSq > 0) {
            double dist = sqrt(distSq);
            double overlap = minDist - dist;
            
            // Soft-body collision response
            Vec2 offset = Vec2.scaleVec(delta, overlap / dist * 0.5);
            
            // Apply turgor pressure resistance
            double resistance1 = n1.turgorPressure * 0.3;
            double resistance2 = n2.turgorPressure * 0.3;
            
            if (!n1.isFixed) n1.pos.add(Vec2.scaleVec(offset, 1.0 + resistance1));
            if (!n2.isFixed) n2.pos.sub(Vec2.scaleVec(offset, 1.0 + resistance2));
            
            // Compression damage
            if (overlap > n1.radius * 0.3) {
              n1.wallIntegrity -= 0.005;
              n2.wallIntegrity -= 0.005;
            }
          }
        }
      }
    }
  }

  void _handleEnvironmentInteractions(double dt) {
    List<EnvironmentItem> toRemove = [];

    for (var node in nodes) {
      if (node.state == CellState.dead) continue;

      for (var item in environment) {
        double dist = node.pos.distanceTo(item.pos);
        
        if (item.type == EnvType.food && dist < node.radius + item.radius + 10.0) {
          // Enzyme secretion and extracellular digestion
          double digestRate = min(3.0 * dt * 10.0, item.amount);
          item.amount -= digestRate;
          
          // Nutrient absorption
          double absorptionEfficiency = 0.7;
          node.nutrients.glucose += item.nutrients.glucose / item.amount * digestRate * absorptionEfficiency;
          node.nutrients.nitrogen += item.nutrients.nitrogen / item.amount * digestRate * absorptionEfficiency;
          node.nutrients.phosphorus += item.nutrients.phosphorus / item.amount * digestRate * absorptionEfficiency;
          
          // Decrease food nutrient content
          item.nutrients.glucose -= item.nutrients.glucose / item.amount * digestRate;
          item.nutrients.nitrogen -= item.nutrients.nitrogen / item.amount * digestRate;
          item.nutrients.phosphorus -= item.nutrients.phosphorus / item.amount * digestRate;
          
          if (item.amount <= 0) {
            toRemove.add(item);
          }
        } else if (item.type == EnvType.toxin && dist < node.radius + item.radius + 15.0) {
          // Toxin damage (oxidative stress, membrane damage)
          double toxinDamage = dt * 2.0 * (1.0 - dist / (node.radius + item.radius + 15.0));
          node.wallIntegrity -= toxinDamage * 0.1;
          node.energy -= toxinDamage * 5.0;
          
          // Stress response (costs energy)
          if (node.energy > 10) {
            node.energy -= dt * 1.0; // Active detoxification
          }
          
          // Repulsion from toxin
          Vec2 repel = Vec2.subVec(node.pos, item.pos);
          if (repel.length() > 0) {
            repel.normalize();
            repel.scale(3.0 * dt * 10.0);
            node.pos.add(repel);
          }
        }
      }
    }

    environment.removeWhere((item) => toRemove.contains(item));
  }

  void _cytoplasmaticStreaming(double dt) {
    // Nutrient transport through the mycelium network
    for (var link in links) {
      if (link.integrity < 0.3) continue;
      if (link.nodeA.state == CellState.dead || link.nodeB.state == CellState.dead) continue;
      
      // Bidirectional flow based on concentration gradients
      double glucoseDiff = link.nodeA.nutrients.glucose - link.nodeB.nutrients.glucose;
      double nitrogenDiff = link.nodeA.nutrients.nitrogen - link.nodeB.nutrients.nitrogen;
      double phosphorusDiff = link.nodeA.nutrients.phosphorus - link.nodeB.nutrients.phosphorus;
      
      // Flow rate proportional to pressure difference and link integrity
      double flowRate = dt * 0.15 * link.integrity;
      
      double glucoseFlow = glucoseDiff * flowRate;
      double nitrogenFlow = nitrogenDiff * flowRate;
      double phosphorusFlow = phosphorusDiff * flowRate;
      
      link.nodeA.nutrients.glucose -= glucoseFlow;
      link.nodeB.nutrients.glucose += glucoseFlow;
      
      link.nodeA.nutrients.nitrogen -= nitrogenFlow;
      link.nodeB.nutrients.nitrogen += nitrogenFlow;
      
      link.nodeA.nutrients.phosphorus -= phosphorusFlow;
      link.nodeB.nutrients.phosphorus += phosphorusFlow;
    }
  }

  void _manageReproduction(double dt) {
    List<MoldNode> newSpores = [];
    
    for (var node in nodes) {
      if (node.state != CellState.active) continue;
      if (node.energy < 80 || node.nutrients.glucose < 60) continue;
      if (node.age < 50) continue;
      if (nodes.length > 400) break;
      
      // Environmental stress triggers sporulation
      var gridPos = _worldToGrid(node.pos);
      double oxygen = 1.0;
      if (_isValidGridPos(gridPos)) {
        oxygen = envGrid[gridPos.y.toInt()][gridPos.x.toInt()].oxygen;
      }
      
      double sporulationProbability = node.genes.sporulationRate * dt * 0.05;
      if (oxygen < 0.3 || node.state == CellState.stressed) {
        sporulationProbability *= 3.0; // Stress-induced sporulation
      }
      
      if (_random.nextDouble() < sporulationProbability) {
        // Create sporangium
        node.type = NodeType.sporangium;
        node.state = CellState.reproducing;
        
        // Produce spores
        int sporeCount = 3 + _random.nextInt(5);
        double energyCost = 60.0;
        node.energy -= energyCost;
        node.nutrients.glucose -= 50.0;
        node.nutrients.nitrogen -= 20.0;
        
        for (int i = 0; i < sporeCount; i++) {
          double angle = (2 * pi * i) / sporeCount + (_random.nextDouble() - 0.5) * 0.5;
          Vec2 sporePos = Vec2(
            node.pos.x + cos(angle) * (node.radius + 8),
            node.pos.y + sin(angle) * (node.radius + 8),
          );
          
          // Genetic variation (mutation)
          Genome sporeGenome = node.genes.clone();
          if (_random.nextDouble() < 0.1) {
            sporeGenome.mutate(_random);
          }
          
          MoldNode spore = MoldNode(
            pos: sporePos,
            type: NodeType.spore,
            energy: 100,
            radius: 4.0,
            nutrients: NutrientStore(
              glucose: 70.0,
              nitrogen: 30.0,
              phosphorus: 15.0,
            ),
            state: CellState.dormant,
            genes: sporeGenome,
          );
          
          // Initial velocity (spore dispersal)
          spore.oldPos = Vec2(
            spore.pos.x - cos(angle) * 5.0,
            spore.pos.y - sin(angle) * 5.0,
          );
          
          newSpores.add(spore);
        }
        
        // Parent cell depleted after sporulation
        node.energy = 5.0;
      }
    }
    
    nodes.addAll(newSpores);
  }

  void _manageCellDeath() {
    // Remove dead nodes and associated links
    List<MoldNode> deadNodes = [];
    
    for (var node in nodes) {
      bool shouldDie = false;
      
      // Death conditions
      if (node.energy <= 0) shouldDie = true;
      if (node.wallIntegrity <= 0) shouldDie = true;
      if (node.nutrients.totalAmount() < 0) shouldDie = true;
      if (node.age > 500 && _random.nextDouble() < 0.001) shouldDie = true; // Senescence
      
      if (shouldDie && node.state != CellState.dead) {
        node.state = CellState.dead;
        deadNodes.add(node);
      }
    }
    
    // Remove dead nodes after delay (autolysis)
    nodes.removeWhere((n) => n.state == CellState.dead && n.age > n.age + 10);
    
    // Remove broken links
    links.removeWhere((l) => 
      l.integrity <= 0 || 
      deadNodes.contains(l.nodeA) || 
      deadNodes.contains(l.nodeB) ||
      !nodes.contains(l.nodeA) ||
      !nodes.contains(l.nodeB)
    );
  }

  Vec2 _worldToGrid(Vec2 worldPos) {
    return Vec2(
      (worldPos.x / gridSize).floorToDouble(),
      (worldPos.y / gridSize).floorToDouble(),
    );
  }

  bool _isValidGridPos(Vec2 gridPos) {
    return gridPos.x >= 0 && 
           gridPos.x < envGrid[0].length && 
           gridPos.y >= 0 && 
           gridPos.y < envGrid.length;
  }
}

class EnvironmentCell {
  double oxygen;
  double pH;
  double moisture;
  double temperature;
  
  EnvironmentCell({
    required this.oxygen,
    required this.pH,
    required this.moisture,
    required this.temperature,
  });
}
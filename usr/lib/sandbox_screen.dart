import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'math_utils.dart';
import 'mold_models.dart';
import 'simulation_engine.dart';

class SandboxScreen extends StatefulWidget {
  const SandboxScreen({super.key});

  @override
  State<SandboxScreen> createState() => _SandboxScreenState();
}

class _SandboxScreenState extends State<SandboxScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  SimulationEngine? _engine;
  String _selectedTool = 'food'; // 'food', 'toxin', 'spore'

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_engine == null) {
      final size = MediaQuery.of(context).size;
      _engine = SimulationEngine(size.width, size.height);
      // Spawn initial spore in the center
      _engine!.spawnSpore(Vec2(size.width / 2, size.height / 2));
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    // Fixed time step for physics stability
    _engine?.update(0.016); // ~60fps
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    if (_engine == null) return;
    Vec2 pos = Vec2(details.localPosition.dx, details.localPosition.dy);
    
    if (_selectedTool == 'food') {
      _engine!.addEnvironmentItem(pos, EnvType.food);
    } else if (_selectedTool == 'toxin') {
      _engine!.addEnvironmentItem(pos, EnvType.toxin);
    } else if (_selectedTool == 'spore') {
      _engine!.spawnSpore(pos);
    }
  }

  void _handlePan(DragUpdateDetails details) {
    if (_engine == null) return;
    // Allow painting food/toxins by dragging
    if (_selectedTool != 'spore') {
      Vec2 pos = Vec2(details.localPosition.dx, details.localPosition.dy);
      // Throttle adding items slightly based on random chance to avoid flooding
      if (DateTime.now().millisecond % 3 == 0) {
        _engine!.addEnvironmentItem(pos, _selectedTool == 'food' ? EnvType.food : EnvType.toxin);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17), // Deep microscope background
      body: Stack(
        children: [
          // Simulation Canvas
          if (_engine != null)
            GestureDetector(
              onTapDown: _handleTap,
              onPanUpdate: _handlePan,
              child: AnimatedBuilder(
                animation: _engine!,
                builder: (context, child) {
                  return CustomPaint(
                    painter: MoldPainter(_engine!),
                    size: Size.infinite,
                  );
                },
              ),
            ),
            
          // UI Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MOLD EVOLUTION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_engine != null)
                    AnimatedBuilder(
                      animation: _engine!,
                      builder: (context, child) {
                        return Text(
                          'Cells: ${_engine!.nodes.length} | Links: ${_engine!.links.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        );
                      },
                    ),
                  const Spacer(),
                  // Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToolButton('food', Icons.eco, Colors.greenAccent),
                        const SizedBox(width: 16),
                        _buildToolButton('toxin', Icons.coronavirus, Colors.redAccent),
                        const SizedBox(width: 16),
                        _buildToolButton('spore', Icons.bubble_chart, Colors.cyanAccent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(String tool, IconData icon, Color color) {
    final isSelected = _selectedTool == tool;
    return GestureDetector(
      onTap: () => setState(() => _selectedTool = tool),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? color : Colors.white54,
          size: 28,
        ),
      ),
    );
  }
}

class MoldPainter extends CustomPainter {
  final SimulationEngine engine;

  MoldPainter(this.engine);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Environment
    final foodPaint = Paint()..style = PaintingStyle.fill;
    final toxinPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.redAccent.withOpacity(0.6);

    for (var item in engine.environment) {
      if (item.type == EnvType.food) {
        foodPaint.color = Colors.greenAccent.withOpacity((item.amount / 200.0).clamp(0.2, 1.0));
        canvas.drawCircle(Offset(item.pos.x, item.pos.y), item.radius, foodPaint);
      } else {
        canvas.drawCircle(Offset(item.pos.x, item.pos.y), item.radius, toxinPaint);
      }
    }

    // Draw Links (Mycelium network)
    final linkPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var link in engine.links) {
      canvas.drawLine(
        Offset(link.nodeA.pos.x, link.nodeA.pos.y),
        Offset(link.nodeB.pos.x, link.nodeB.pos.y),
        linkPaint,
      );
    }

    // Draw Nodes (Cells)
    final nodePaint = Paint()..style = PaintingStyle.fill;
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black87;

    for (var node in engine.nodes) {
      // Outer membrane
      nodePaint.color = node.color.withOpacity((node.energy / node.maxEnergy).clamp(0.2, 1.0));
      canvas.drawCircle(Offset(node.pos.x, node.pos.y), node.radius, nodePaint);
      
      // Inner core
      canvas.drawCircle(Offset(node.pos.x, node.pos.y), node.radius * 0.4, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant MoldPainter oldDelegate) => true;
}

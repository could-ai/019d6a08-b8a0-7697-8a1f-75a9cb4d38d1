import 'package:flutter/material.dart';
import 'sandbox_screen.dart';

void main() {
  runApp(const MoldEvolutionApp());
}

class MoldEvolutionApp extends StatelessWidget {
  const MoldEvolutionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mold Evolution',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SandboxScreen(),
      },
    );
  }
}

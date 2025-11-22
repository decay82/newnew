import 'package:flutter/material.dart';
import 'screens/analyze_screen.dart';
import 'screens/game_screen.dart';

void main() {
  runApp(const BadukCoachApp());
}

class BadukCoachApp extends StatelessWidget {
  const BadukCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '바둑 AI 코치',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final _screens = const [
    GameScreen(),
    AnalyzeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_on),
            selectedIcon: Icon(Icons.grid_on, color: Colors.brown),
            label: 'AI 대국',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: Colors.brown),
            label: '기보 분석',
          ),
        ],
      ),
    );
  }
}

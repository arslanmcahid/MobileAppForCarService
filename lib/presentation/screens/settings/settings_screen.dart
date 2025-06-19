import 'package:flutter/material.dart';
import '../../../presentation/widgets/bottom_navigation.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: const Center(
        child: Text('Ayarlar ekranı - Yakında gelecek'),
      ),
      bottomNavigationBar: const BottomNavigation(currentIndex: 3),
    );
  }
} 
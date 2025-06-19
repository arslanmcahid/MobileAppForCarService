import 'package:flutter/material.dart';
import '../../../presentation/widgets/bottom_navigation.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bakım İşlemleri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Bakım ekleme
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Bakım ekranı - Yakında gelecek'),
      ),
      bottomNavigationBar: const BottomNavigation(currentIndex: 2),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/car.dart';
import '../../../data/models/maintenance.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../../widgets/bottom_navigation.dart';

class MaintenanceRecordItem {
  final Car car;
  final Maintenance maintenance;

  MaintenanceRecordItem({required this.car, required this.maintenance});
}

final maintenanceHistoryProvider =
    FutureProvider<List<MaintenanceRecordItem>>((ref) async {
  final repo = MaintenanceRepository();
  final data = await repo.getMaintenanceHistory();
  return data.map<MaintenanceRecordItem>((row) {
    final car = Car.fromMap(row['cars']);
    final maintenance = Maintenance.fromMap(row);
    return MaintenanceRecordItem(car: car, maintenance: maintenance);
  }).toList();
});

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(maintenanceHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bakım İşlemleri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/maintenance/add'),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Text(
                'Henüz bakım kaydı yok',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.refresh(maintenanceHistoryProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) => _buildRecordCard(context, records[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Hata: $error')),
      ),
      bottomNavigationBar: const BottomNavigation(currentIndex: 2),
    );
  }

  Widget _buildRecordCard(BuildContext context, MaintenanceRecordItem item) {
    final maintenance = item.maintenance;
    final car = item.car;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  maintenance.type == MaintenanceType.general
                      ? Icons.build
                      : Icons.engineering,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${car.brand} ${car.model}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(maintenance.title),
            const SizedBox(height: 4),
            Text(
              maintenance.datePerformed.toIso8601String().split('T').first,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (maintenance.mileageAtService != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${maintenance.mileageAtService} km'),
              ),
            if (maintenance.cost != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('₺${maintenance.cost!.toStringAsFixed(0)}'),
              ),
          ],
        ),
      ),
    );
  }
}

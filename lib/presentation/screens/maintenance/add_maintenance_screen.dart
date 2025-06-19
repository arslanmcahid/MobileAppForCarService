import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/car.dart';
import '../../../data/repositories/car_repository.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../home_screen.dart' as home_screen;

// Bekleyen bakım öğesi modeli
class PendingMaintenanceItem {
  final Car car;
  final String maintenanceType;
  final String title;
  final int remainingKm;
  final bool isOverdue;
  final int? lastServiceKm;

  PendingMaintenanceItem({
    required this.car,
    required this.maintenanceType,
    required this.title,
    required this.remainingKm,
    required this.isOverdue,
    this.lastServiceKm,
  });
}

// Bekleyen bakımlar provider
final pendingMaintenanceItemsProvider = FutureProvider<List<PendingMaintenanceItem>>((ref) async {
  final repository = CarRepository();
  final maintenanceRepository = MaintenanceRepository();
  final cars = await repository.getAllCars();
  
  List<PendingMaintenanceItem> pendingItems = [];
  
  for (final car in cars) {
    if (car.mileage == null) continue;
    
    final maintenanceInfo = await maintenanceRepository.getMaintenanceInfo(car.id);
    
    // Genel bakım kontrolü
    final generalStatus = _calculateMaintenanceStatus(
      car: car,
      lastServiceKm: maintenanceInfo['lastGeneralServiceKm'],
      maintenanceType: 'general',
    );
    
    if (generalStatus['remainingKm'] <= 5000) {
      pendingItems.add(PendingMaintenanceItem(
        car: car,
        maintenanceType: 'general',
        title: 'Genel Bakım',
        remainingKm: generalStatus['remainingKm'],
        isOverdue: generalStatus['remainingKm'] <= 0,
        lastServiceKm: maintenanceInfo['lastGeneralServiceKm'],
      ));
    }
    
    // Ağır bakım kontrolü
    final heavyStatus = _calculateMaintenanceStatus(
      car: car,
      lastServiceKm: maintenanceInfo['lastHeavyServiceKm'],
      maintenanceType: 'heavy',
    );
    
    if (heavyStatus['remainingKm'] <= 10000) {
      pendingItems.add(PendingMaintenanceItem(
        car: car,
        maintenanceType: 'heavy',
        title: 'Ağır Bakım',
        remainingKm: heavyStatus['remainingKm'],
        isOverdue: heavyStatus['remainingKm'] <= 0,
        lastServiceKm: maintenanceInfo['lastHeavyServiceKm'],
      ));
    }
  }
  
  // Önce gecikmiş olanları, sonra yaklaşanları sırala
  pendingItems.sort((a, b) {
    if (a.isOverdue && !b.isOverdue) return -1;
    if (!a.isOverdue && b.isOverdue) return 1;
    return a.remainingKm.compareTo(b.remainingKm);
  });
  
  return pendingItems;
});

// Bakım durumu hesaplama fonksiyonu (home_screen'den kopyalandı)
Map<String, dynamic> _calculateMaintenanceStatus({
  required Car car,
  required int? lastServiceKm,
  required String maintenanceType,
}) {
  if (car.mileage == null || lastServiceKm == null) {
    return {'isUrgent': false, 'remainingKm': 999999};
  }
  
  final currentKm = car.mileage!;
  
  int interval;
  if (maintenanceType == 'general') {
    if (currentKm >= 100000) {
      interval = 10000;
    } else {
      switch (car.brand.toLowerCase()) {
        case 'toyota':
        case 'honda':
        case 'nissan':
          interval = 10000;
          break;
        default:
          interval = 15000;
          break;
      }
    }
  } else {
    interval = 80000;
  }
  
  final nextServiceKm = lastServiceKm + interval;
  final remainingKm = nextServiceKm - currentKm;
  
  return {
    'isUrgent': remainingKm <= 2000,
    'remainingKm': remainingKm,
  };
}

class AddMaintenanceScreen extends ConsumerStatefulWidget {
  final String? carId;

  const AddMaintenanceScreen({super.key, this.carId});

  @override
  ConsumerState<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends ConsumerState<AddMaintenanceScreen> {
  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingMaintenanceItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bekleyen Bakımlar'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
      ),
      body: pendingAsync.when(
        data: (pendingItems) => _buildPendingList(pendingItems),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(error.toString()),
      ),
    );
  }

  Widget _buildPendingList(List<PendingMaintenanceItem> items) {
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildMaintenanceCard(item);
      },
    );
  }

  Widget _buildMaintenanceCard(PendingMaintenanceItem item) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (item.isOverdue) {
      statusColor = Colors.red;
      statusText = 'GECİKMİŞ';
      statusIcon = Icons.error;
    } else if (item.remainingKm <= 2000) {
      statusColor = Colors.orange;
      statusText = 'ACİL';
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.blue;
      statusText = 'YAKLAŞAN';
      statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: InkWell(
        onTap: () => _showMaintenanceUpdateDialog(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    item.maintenanceType == 'general' ? Icons.build : Icons.engineering,
                    color: statusColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.car.brand} ${item.car.model}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          item.title,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.speed, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    item.isOverdue
                        ? '${item.remainingKm.abs()} km geçmiş'
                        : '${item.remainingKm} km kaldı',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Güncel: ${item.car.mileage!.toStringAsFixed(0)} km',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green[400],
          ),
          const SizedBox(height: 16),
          Text(
            '🎉 Tebrikler!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bekleyen bakım yok',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Tüm araçlarınız bakım açısından iyi durumda',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Hata: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.refresh(pendingMaintenanceItemsProvider),
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceUpdateDialog(PendingMaintenanceItem item) {
    // Bakım güncelleme dialog'unu göster
    showDialog(
      context: context,
      builder: (context) => MaintenanceUpdateDialog(item: item),
    ).then((updated) {
      if (updated == true) {
        // Provider'ları yenile
        ref.refresh(pendingMaintenanceItemsProvider);
        ref.refresh(home_screen.pendingMaintenanceProvider);
      }
    });
  }
}

// Bakım güncelleme dialog'u
class MaintenanceUpdateDialog extends StatefulWidget {
  final PendingMaintenanceItem item;

  const MaintenanceUpdateDialog({super.key, required this.item});

  @override
  State<MaintenanceUpdateDialog> createState() => _MaintenanceUpdateDialogState();
}

class _MaintenanceUpdateDialogState extends State<MaintenanceUpdateDialog> {
  final _kmController = TextEditingController();
  final _costController = TextEditingController();
  final _providerController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Varsayılan olarak şu anki kilometreyi koy
    _kmController.text = widget.item.car.mileage?.toString() ?? '';
  }

  @override
  void dispose() {
    _kmController.dispose();
    _costController.dispose();
    _providerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.item.title} Tamamla'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.item.car.brand} ${widget.item.car.model}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _kmController,
              decoration: const InputDecoration(
                labelText: 'Bakım Kilometresi',
                suffixText: 'km',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costController,
              decoration: const InputDecoration(
                labelText: 'Maliyet (Opsiyonel)',
                suffixText: '₺',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _providerController,
              decoration: const InputDecoration(
                labelText: 'Servis Sağlayıcı (Opsiyonel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notlar (Opsiyonel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateMaintenance,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Tamamla'),
        ),
      ],
    );
  }

  Future<void> _updateMaintenance() async {
    final km = int.tryParse(_kmController.text.trim());
    if (km == null || km <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir kilometre değeri girin')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = MaintenanceRepository();
      
      final cost = double.tryParse(_costController.text.trim());
      final provider = _providerController.text.trim();
      final notes = _notesController.text.trim();

      if (widget.item.maintenanceType == 'general') {
        await repository.saveMaintenanceInfo(
          carId: widget.item.car.id,
          lastGeneralServiceKm: km,
          generalCost: cost,
          generalServiceProvider: provider.isEmpty ? null : provider,
          generalNotes: notes.isEmpty ? null : notes,
        );
      } else {
        await repository.saveMaintenanceInfo(
          carId: widget.item.car.id,
          lastHeavyServiceKm: km,
          heavyCost: cost,
          heavyServiceProvider: provider.isEmpty ? null : provider,
          heavyNotes: notes.isEmpty ? null : notes,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Bakım başarıyla tamamlandı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 
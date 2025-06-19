import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/car.dart';
import '../../../data/repositories/car_repository.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../home_screen.dart' as home_screen;

// Provider for specific car
final carProvider = FutureProvider.family<Car?, String>((ref, carId) async {
  final repository = CarRepository();
  return await repository.getCarById(carId);
});

// Provider for maintenance info
final maintenanceInfoProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, carId) async {
  final repository = MaintenanceRepository();
  return await repository.getMaintenanceInfo(carId);
});

class CarDetailScreen extends ConsumerStatefulWidget {
  final String carId;

  const CarDetailScreen({super.key, required this.carId});

  @override
  ConsumerState<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends ConsumerState<CarDetailScreen> {
  final TextEditingController _lastGeneralServiceKmController = TextEditingController();
  final TextEditingController _lastHeavyServiceKmController = TextEditingController();
  final TextEditingController _generalNotesController = TextEditingController();
  final TextEditingController _heavyNotesController = TextEditingController();
  final TextEditingController _generalCostController = TextEditingController();
  final TextEditingController _heavyCostController = TextEditingController();
  final TextEditingController _generalServiceProviderController = TextEditingController();
  final TextEditingController _heavyServiceProviderController = TextEditingController();
  final TextEditingController _currentMileageController = TextEditingController();

  // Bakım verileri
  int? _lastGeneralServiceKm;
  int? _lastHeavyServiceKm;
  String? _generalNotes;
  String? _heavyNotes;
  double? _generalCost;
  double? _heavyCost;
  String? _generalServiceProvider;
  String? _heavyServiceProvider;
  bool _isLoading = false;
  bool _showMileageReminder = false;

  @override
  void initState() {
    super.initState();
    _checkMileageUpdateReminder();
  }

  // Haftalık kilometre güncelleme hatırlatıcısı kontrolü
  Future<void> _checkMileageUpdateReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getString('last_mileage_update_${widget.carId}');
    final lastReminder = prefs.getString('last_mileage_reminder_${widget.carId}');
    final reminderPostponed = prefs.getString('mileage_reminder_postponed_${widget.carId}');
    final postponeDays = prefs.getInt('mileage_reminder_postpone_days_${widget.carId}') ?? 7;
    
    final now = DateTime.now();
    
    // Eğer kullanıcı erteleme yapmışsa kontrol et
    if (reminderPostponed != null) {
      final postponedDate = DateTime.parse(reminderPostponed);
      final daysSincePostponed = now.difference(postponedDate).inDays;
      
      if (daysSincePostponed < postponeDays) {
        // Henüz belirlenen gün sayısı geçmemiş, hatırlatıcı gösterme
        print('🔕 Reminder postponed for ${postponeDays - daysSincePostponed} more days');
        return;
      } else {
        // Belirlenen gün sayısı geçmiş, postpone kayıtlarını sil
        await prefs.remove('mileage_reminder_postponed_${widget.carId}');
        await prefs.remove('mileage_reminder_postpone_days_${widget.carId}');
        print('✅ Postpone period ended, clearing postpone records');
      }
    }
    
    // Son hatırlatıcıdan bu yana geçen süreyi kontrol et
    if (lastReminder != null) {
      final lastReminderDate = DateTime.parse(lastReminder);
      final daysSinceReminder = now.difference(lastReminderDate).inDays;
      
      // Son hatırlatıcıdan 1 gün geçmemişse gösterme (çok sık göstermeyi önle)
      if (daysSinceReminder < 1) {
        print('🔕 Reminder shown less than 1 day ago');
        return;
      }
    }
    
    // Ana kilometre güncelleme mantığı
    if (lastUpdate != null) {
      final lastUpdateDate = DateTime.parse(lastUpdate);
      final daysSinceUpdate = now.difference(lastUpdateDate).inDays;
      
      if (daysSinceUpdate >= 7) {
        setState(() {
          _showMileageReminder = true;
        });
        // Son hatırlatıcı zamanını kaydet
        await prefs.setString('last_mileage_reminder_${widget.carId}', now.toIso8601String());
        print('🔔 Showing mileage reminder (${daysSinceUpdate} days since last update)');
      }
    } else {
      // İlk kez açılıyorsa, ama sadece bir kez göster
      if (lastReminder == null) {
        setState(() {
          _showMileageReminder = true;
        });
        await prefs.setString('last_mileage_reminder_${widget.carId}', now.toIso8601String());
        print('🔔 Showing first-time mileage reminder');
      }
    }
  }

  @override
  void dispose() {
    _lastGeneralServiceKmController.dispose();
    _lastHeavyServiceKmController.dispose();
    _generalNotesController.dispose();
    _heavyNotesController.dispose();
    _generalCostController.dispose();
    _heavyCostController.dispose();
    _generalServiceProviderController.dispose();
    _heavyServiceProviderController.dispose();
    _currentMileageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final carAsync = ref.watch(carProvider(widget.carId));
    final maintenanceAsync = ref.watch(maintenanceInfoProvider(widget.carId));

    // Bakım verilerini yükle
    maintenanceAsync.whenData((data) {
      if (_lastGeneralServiceKm == null && _lastHeavyServiceKm == null) {
        _lastGeneralServiceKm = data['lastGeneralServiceKm'];
        _lastHeavyServiceKm = data['lastHeavyServiceKm'];
        _generalNotes = data['generalNotes'];
        _heavyNotes = data['heavyNotes'];
        _generalCost = data['generalCost'];
        _heavyCost = data['heavyCost'];
        _generalServiceProvider = data['generalServiceProvider'];
        _heavyServiceProvider = data['heavyServiceProvider'];
        
        _lastGeneralServiceKmController.text = _lastGeneralServiceKm?.toString() ?? '';
        _lastHeavyServiceKmController.text = _lastHeavyServiceKm?.toString() ?? '';
        _generalNotesController.text = _generalNotes ?? '';
        _heavyNotesController.text = _heavyNotes ?? '';
        _generalCostController.text = _generalCost?.toString() ?? '';
        _heavyCostController.text = _heavyCost?.toString() ?? '';
        _generalServiceProviderController.text = _generalServiceProvider ?? '';
        _heavyServiceProviderController.text = _heavyServiceProvider ?? '';
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Detayı'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Düzenle'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Sil', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: carAsync.when(
        data: (car) => car != null ? _buildCarDetail(car) : _buildNotFound(),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(error.toString()),
      ),
    );
  }

  Widget _buildCarDetail(Car car) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kilometre güncelleme hatırlatıcısı
          if (_showMileageReminder) _buildMileageReminderCard(car),
          if (_showMileageReminder) const SizedBox(height: 20),
          
          _buildCarInfoCard(car),
          const SizedBox(height: 20),
          _buildMaintenanceInfoCard(car),
          const SizedBox(height: 20),
          _buildUpcomingMaintenanceCard(car),
        ],
      ),
    );
  }

  Widget _buildMileageReminderCard(Car car) {
    return Card(
      color: Colors.orange.shade50,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.speed,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊 Kilometre Güncelleme Zamanı!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Doğru bakım önerileri için araç kilometrenizi güncelleyin',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _postponeReminder(),
                  icon: Icon(Icons.close, color: Colors.orange.shade600),
                  tooltip: 'Bu hafta sorma',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _currentMileageController,
                    decoration: InputDecoration(
                      labelText: 'Güncel Kilometre',
                      hintText: car.mileage?.toString() ?? '120000',
                      suffixText: 'km',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.speed),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _updateMileage(car),
                  icon: const Icon(Icons.update, size: 18),
                  label: const Text('Güncelle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _postponeReminder(days: 3),
                  icon: const Icon(Icons.schedule, size: 16),
                  label: const Text('3 Gün Sonra'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _postponeReminder(days: 7),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Bu Hafta Sorma'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Hatırlatıcıyı ertele
  Future<void> _postponeReminder({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    final postponeUntil = DateTime.now().add(Duration(days: days));
    
    await prefs.setString('mileage_reminder_postponed_${widget.carId}', postponeUntil.toIso8601String());
    await prefs.setInt('mileage_reminder_postpone_days_${widget.carId}', days);
    
    setState(() {
      _showMileageReminder = false;
    });

    String message;
    if (days == 3) {
      message = '📅 3 gün sonra tekrar hatırlatılacak';
    } else {
      message = '📅 Bu hafta bir daha sorulmayacak';
    }

    print('⏰ Reminder postponed for $days days');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildCarInfoCard(Car car) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${car.brand} ${car.model}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (car.licensePlate.isNotEmpty)
                        Text(
                          car.licensePlate,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow('Model Yılı', car.year),
            if (car.color != null) _buildInfoRow('Renk', car.color!),
            if (car.mileage != null) _buildInfoRow('Kilometre', '${car.mileage!.toStringAsFixed(0)} km'),
            _buildInfoRow('Eklenme Tarihi', _formatDate(car.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceInfoCard(Car car) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Bakım Bilgileri',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastGeneralServiceKmController,
              decoration: const InputDecoration(
                labelText: 'Son Genel Bakım Kilometresi',
                hintText: 'ör: 108000',
                suffixText: 'km',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.speed),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastHeavyServiceKmController,
              decoration: const InputDecoration(
                labelText: 'Son Ağır Bakım Kilometresi',
                hintText: 'ör: 108000',
                suffixText: 'km',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.speed),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _generalNotesController,
              decoration: const InputDecoration(
                labelText: 'Genel Bakım Notları',
                hintText: 'Genel bakım hakkında ek bilgiler...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _heavyNotesController,
              decoration: const InputDecoration(
                labelText: 'Ağır Bakım Notları',
                hintText: 'Ağır bakım hakkında ek bilgiler...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _generalCostController,
              decoration: const InputDecoration(
                labelText: 'Genel Bakım Maliyeti',
                hintText: 'Genel bakım maliyeti...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _heavyCostController,
              decoration: const InputDecoration(
                labelText: 'Ağır Bakım Maliyeti',
                hintText: 'Ağır bakım maliyeti...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _generalServiceProviderController,
              decoration: const InputDecoration(
                labelText: 'Genel Bakım Servis Sağlayıcısı',
                hintText: 'Genel bakım servis sağlayıcısı...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _heavyServiceProviderController,
              decoration: const InputDecoration(
                labelText: 'Ağır Bakım Servis Sağlayıcısı',
                hintText: 'Ağır bakım servis sağlayıcısı...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _saveMaintenanceInfo(),
                icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Kaydediliyor...' : 'Bilgileri Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingMaintenanceCard(Car car) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Yaklaşan Bakımlar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Genel Bakım
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Genel Bakım',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMaintenanceRecommendation(car, 'general'),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Ağır Bakım
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.engineering, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Ağır Bakım',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMaintenanceRecommendation(car, 'heavy'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceRecommendation(Car car, String type) {
    if (car.mileage == null) {
      return Text(
        'Kilometre bilgisi gerekli',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      );
    }

    String recommendation;
    String nextService;
    Color statusColor;

    if (type == 'general') {
      final result = _calculateGeneralMaintenance(car);
      recommendation = result['recommendation']!;
      nextService = result['nextService']!;
      statusColor = result['color']!;
    } else {
      final result = _calculateHeavyMaintenance(car);
      recommendation = result['recommendation']!;
      nextService = result['nextService']!;
      statusColor = result['color']!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                recommendation,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            nextService,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateGeneralMaintenance(Car car) {
    final currentKm = car.mileage!;
    final lastServiceKm = _lastGeneralServiceKm ?? 0;
    
    // Genel bakım aralığı hesapla
    int interval;
    if (currentKm >= 100000) {
      interval = 10000; // 100.000+ km için 10.000 km
    } else {
      // 100.000 km altı için marka bazlı 10.000-15.000 km
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

    final kmSinceLastService = currentKm - lastServiceKm;
    final nextServiceKm = lastServiceKm + interval;
    final remainingKm = nextServiceKm - currentKm;

    String recommendation;
    String nextService;
    Color color;

    if (lastServiceKm == 0) {
      recommendation = 'Son genel bakım bilgisi girilmedi';
      nextService = 'Lütfen son bakım kilometresini girin';
      color = Colors.grey;
    } else if (remainingKm <= 0) {
      recommendation = 'ACİL: Genel bakım gerekli!';
      nextService = '${kmSinceLastService.abs()} km geçmiş (${nextServiceKm} km\'de olmalıydı)';
      color = Colors.red;
    } else if (remainingKm <= 2000) {
      recommendation = 'Yakında genel bakım gerekli';
      nextService = '$remainingKm km kaldı (${nextServiceKm} km\'de)';
      color = Colors.orange;
    } else {
      recommendation = 'Genel bakım durumu iyi';
      nextService = '$remainingKm km kaldı (${nextServiceKm} km\'de)';
      color = Colors.green;
    }

    return {
      'recommendation': recommendation,
      'nextService': nextService,
      'color': color,
    };
  }

  Map<String, dynamic> _calculateHeavyMaintenance(Car car) {
    final currentKm = car.mileage!;
    final lastServiceKm = _lastHeavyServiceKm ?? 0;
    
    // Ağır bakım aralığı: 70.000-90.000 km (ortalama 80.000 km)
    const interval = 80000;

    final kmSinceLastService = currentKm - lastServiceKm;
    final nextServiceKm = lastServiceKm + interval;
    final remainingKm = nextServiceKm - currentKm;

    String recommendation;
    String nextService;
    Color color;

    if (lastServiceKm == 0) {
      recommendation = 'Son ağır bakım bilgisi girilmedi';
      nextService = 'Lütfen son ağır bakım kilometresini girin';
      color = Colors.grey;
    } else if (remainingKm <= 0) {
      recommendation = 'ACİL: Ağır bakım gerekli!';
      nextService = '${kmSinceLastService.abs()} km geçmiş (${nextServiceKm} km\'de olmalıydı)';
      color = Colors.red;
    } else if (remainingKm <= 10000) {
      recommendation = 'Yakında ağır bakım gerekli';
      nextService = '$remainingKm km kaldı (${nextServiceKm} km\'de)';
      color = Colors.orange;
    } else {
      recommendation = 'Ağır bakım durumu iyi';
      nextService = '$remainingKm km kaldı (${nextServiceKm} km\'de)';
      color = Colors.green;
    }

    return {
      'recommendation': recommendation,
      'nextService': nextService,
      'color': color,
    };
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Araç bulunamadı'),
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
            onPressed: () => ref.refresh(carProvider(widget.carId)),
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _saveMaintenanceInfo() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = MaintenanceRepository();
      
      final generalServiceKm = int.tryParse(_lastGeneralServiceKmController.text);
      final heavyServiceKm = int.tryParse(_lastHeavyServiceKmController.text);
      final generalNotes = _generalNotesController.text.trim();
      final heavyNotes = _heavyNotesController.text.trim();
      final generalCost = double.tryParse(_generalCostController.text.trim());
      final heavyCost = double.tryParse(_heavyCostController.text.trim());
      final generalServiceProvider = _generalServiceProviderController.text.trim();
      final heavyServiceProvider = _heavyServiceProviderController.text.trim();

      await repository.saveMaintenanceInfo(
        carId: widget.carId,
        lastGeneralServiceKm: generalServiceKm,
        lastHeavyServiceKm: heavyServiceKm,
        generalNotes: generalNotes.isEmpty ? null : generalNotes,
        heavyNotes: heavyNotes.isEmpty ? null : heavyNotes,
        generalCost: generalCost,
        heavyCost: heavyCost,
        generalServiceProvider: generalServiceProvider.isEmpty ? null : generalServiceProvider,
        heavyServiceProvider: heavyServiceProvider.isEmpty ? null : heavyServiceProvider,
      );

      // Local state'i güncelle
      setState(() {
        _lastGeneralServiceKm = generalServiceKm;
        _lastHeavyServiceKm = heavyServiceKm;
        _generalNotes = generalNotes;
        _heavyNotes = heavyNotes;
        _generalCost = generalCost;
        _heavyCost = heavyCost;
        _generalServiceProvider = generalServiceProvider;
        _heavyServiceProvider = heavyServiceProvider;
        _isLoading = false;
      });

      // Provider'ları yenile
      ref.refresh(maintenanceInfoProvider(widget.carId));

      // Ana ekran provider'larını da yenile
      ref.refresh(home_screen.carCountProvider);
      ref.refresh(home_screen.pendingMaintenanceProvider);
      ref.refresh(home_screen.carsProvider);
      ref.refresh(home_screen.mileageReminderProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Bakım bilgileri başarıyla kaydedildi'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _showEditDialog();
        break;
      case 'delete':
        _showDeleteDialog();
        break;
    }
  }

  void _showEditDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Düzenleme özelliği yakında gelecek')),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Araç Sil'),
        content: const Text('Bu aracı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final repository = CarRepository();
              await repository.deleteCar(widget.carId);
              if (context.mounted) {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Araç silindi'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _updateMileage(Car car) async {
    final newMileageText = _currentMileageController.text.trim();
    if (newMileageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Lütfen kilometre değeri girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newMileage = int.tryParse(newMileageText);
    if (newMileage == null || newMileage < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Geçerli bir kilometre değeri girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (car.mileage != null && newMileage < car.mileage!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Yeni kilometre mevcut kilometreden küçük olamaz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final repository = CarRepository();
      await repository.updateCarMileage(widget.carId, newMileage);

      // SharedPreferences'a son güncelleme tarihini kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_mileage_update_${widget.carId}', DateTime.now().toIso8601String());

      // Hatırlatıcıyı gizle
      setState(() {
        _showMileageReminder = false;
      });

      // Provider'ı yenile
      ref.refresh(carProvider(widget.carId));

      // Ana ekran provider'larını da yenile
      ref.refresh(home_screen.carCountProvider);
      ref.refresh(home_screen.pendingMaintenanceProvider);
      ref.refresh(home_screen.carsProvider);
      ref.refresh(home_screen.mileageReminderProvider);

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Kilometre ${newMileage.toStringAsFixed(0)} km olarak güncellendi'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Controller'ı temizle
      _currentMileageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Hata: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
} 
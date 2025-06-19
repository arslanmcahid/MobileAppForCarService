import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_navigation.dart';
import '../../providers/auth_provider.dart';
import '../../data/repositories/car_repository.dart';
import '../../data/models/car.dart';
import '../../data/repositories/maintenance_repository.dart';

// Data providers
final carCountProvider = FutureProvider<int>((ref) async {
  final repository = CarRepository();
  return await repository.getCarCount();
});

// Cars provider to check mileage update reminders
final carsProvider = FutureProvider<List<Car>>((ref) async {
  final repository = CarRepository();
  return await repository.getAllCars();
});

// Pending maintenance provider
final pendingMaintenanceProvider = FutureProvider<int>((ref) async {
  final repository = CarRepository();
  final maintenanceRepository = MaintenanceRepository();
  final cars = await repository.getAllCars();
  
  int pendingCount = 0;
  
  for (final car in cars) {
    if (car.mileage == null) continue;
    
    // Her araç için bakım bilgilerini al
    final maintenanceInfo = await maintenanceRepository.getMaintenanceInfo(car.id);
    
    // Genel bakım kontrolü
    final generalStatus = _calculateMaintenanceStatus(
      car: car,
      lastServiceKm: maintenanceInfo['lastGeneralServiceKm'],
      maintenanceType: 'general',
    );
    
    // Ağır bakım kontrolü
    final heavyStatus = _calculateMaintenanceStatus(
      car: car,
      lastServiceKm: maintenanceInfo['lastHeavyServiceKm'],
      maintenanceType: 'heavy',
    );
    
    // Eğer herhangi biri kritik durumda ise sayac artır
    if (generalStatus['isUrgent'] == true || heavyStatus['isUrgent'] == true) {
      pendingCount++;
    }
  }
  
  return pendingCount;
});

// Bakım durumu hesaplama fonksiyonu
Map<String, dynamic> _calculateMaintenanceStatus({
  required Car car,
  required int? lastServiceKm,
  required String maintenanceType,
}) {
  if (car.mileage == null || lastServiceKm == null) {
    return {'isUrgent': false, 'remainingKm': 0};
  }
  
  final currentKm = car.mileage!;
  
  // Bakım aralığını hesapla
  int interval;
  if (maintenanceType == 'general') {
    if (currentKm >= 100000) {
      interval = 10000; // 100.000+ km için 10.000 km
    } else {
      // 100.000 km altı için marka bazlı
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
    interval = 80000; // Ağır bakım 80.000 km
  }
  
  final nextServiceKm = lastServiceKm + interval;
  final remainingKm = nextServiceKm - currentKm;
  
  // Kritik durum: Geçmiş veya 2000 km kaldı
  final isUrgent = remainingKm <= 2000;
  
  return {
    'isUrgent': isUrgent,
    'remainingKm': remainingKm,
  };
}

// Mileage reminder provider
final mileageReminderProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final repository = CarRepository();
  final cars = await repository.getAllCars();
  
  int reminderCount = 0;
  final now = DateTime.now();
  
  print('🔍 Checking mileage reminders for ${cars.length} cars');
  
  for (final car in cars) {
    final carId = car.id;
    print('🚗 Checking car: ${car.brand} ${car.model} (ID: $carId)');
    
    // Kullanıcı bu araç için erteleme yapmış mı?
    final reminderPostponed = prefs.getString('mileage_reminder_postponed_$carId');
    final postponeDays = prefs.getInt('mileage_reminder_postpone_days_$carId') ?? 7;
    
    print('📅 Postponed: $reminderPostponed, Days: $postponeDays');
    
    if (reminderPostponed != null) {
      final postponedDate = DateTime.parse(reminderPostponed);
      final daysSincePostponed = now.difference(postponedDate).inDays;
      
      print('⏰ Days since postponed: $daysSincePostponed/$postponeDays');
      
      if (daysSincePostponed < postponeDays) {
        // Henüz belirlenen gün sayısı geçmemiş, bu aracı sayma
        print('🔕 Skipping car - postponed for ${postponeDays - daysSincePostponed} more days');
        continue;
      } else {
        print('✅ Postpone period ended for this car');
      }
    }
    
    // Son hatırlatıcıdan bu yana geçen süreyi kontrol et
    final lastReminder = prefs.getString('last_mileage_reminder_$carId');
    print('🔔 Last reminder: $lastReminder');
    
    if (lastReminder != null) {
      final lastReminderDate = DateTime.parse(lastReminder);
      final daysSinceReminder = now.difference(lastReminderDate).inDays;
      
      print('📆 Days since last reminder: $daysSinceReminder');
      
      // Son hatırlatıcıdan 1 gün geçmemişse sayma
      if (daysSinceReminder < 1) {
        print('🔕 Skipping car - reminder shown less than 1 day ago');
        continue;
      }
    }
    
    // Ana mantık
    final lastUpdate = prefs.getString('last_mileage_update_$carId');
    print('🛣️ Last mileage update: $lastUpdate');
    
    if (lastUpdate != null) {
      final lastUpdateDate = DateTime.parse(lastUpdate);
      final daysSinceUpdate = now.difference(lastUpdateDate).inDays;
      
      print('📊 Days since last update: $daysSinceUpdate');
      
      if (daysSinceUpdate >= 7) {
        print('✅ Adding car to reminder count - needs update');
        reminderCount++;
      } else {
        print('🔕 Skipping car - updated recently');
      }
    } else {
      // İlk kez eklenen araçlar, ama sadece hatırlatıcı gösterilmemişse
      if (lastReminder == null) {
        print('✅ Adding car to reminder count - first time');
        reminderCount++;
      } else {
        print('🔕 Skipping car - no update record but reminder already shown');
      }
    }
  }
  
  print('🎯 Total reminder count: $reminderCount');
  return reminderCount;
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final authNotifier = ref.read(authProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Araba Bakım Takibi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Arama işlevi
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Bildirimler
            },
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                currentUser?.initials ?? 'U',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'profile',
                child: const ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profil'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: const ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Ayarlar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: const ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (String value) async {
              switch (value) {
                case 'profile':
                case 'settings':
                  context.push('/settings');
                  break;
                case 'logout':
                  await _showLogoutDialog(authNotifier);
                  break;
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(currentUser?.displayName ?? 'Kullanıcı'),
            const SizedBox(height: 24),
            
            // Kilometre güncelleme hatırlatıcısı
            Consumer(
              builder: (context, ref, child) {
                final reminderAsync = ref.watch(mileageReminderProvider);
                return reminderAsync.when(
                  data: (count) {
                    if (count > 0) {
                      return Column(
                        children: [
                          _buildMileageReminderCard(count),
                          const SizedBox(height: 24),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (error, stack) => const SizedBox.shrink(),
                );
              },
            ),
            
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildUpcomingMaintenance(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavigation(currentIndex: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/maintenance/add');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showLogoutDialog(AuthNotifier authNotifier) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (result == true) {
      await authNotifier.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Başarıyla çıkış yapıldı'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildWelcomeCard(String userName) {
    final carCountAsync = ref.watch(carCountProvider);
    final pendingMaintenanceAsync = ref.watch(pendingMaintenanceProvider);
    
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hoş Geldiniz, $userName!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arabanızın bakım durumunu kontrol edin',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                carCountAsync.when(
                  data: (count) => _buildStatCard('Toplam Araba', count.toString(), Icons.directions_car),
                  loading: () => _buildStatCard('Toplam Araba', '...', Icons.directions_car),
                  error: (error, stack) => _buildStatCard('Toplam Araba', '0', Icons.directions_car),
                ),
                const SizedBox(width: 16),
                pendingMaintenanceAsync.when(
                  data: (count) => _buildStatCard(
                    'Bekleyen Bakım', 
                    count.toString(), 
                    Icons.pending,
                    statusColor: count > 0 ? Colors.red.shade300 : null,
                  ),
                  loading: () => _buildStatCard('Bekleyen Bakım', '...', Icons.pending),
                  error: (error, stack) => _buildStatCard('Bekleyen Bakım', '0', Icons.pending),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {Color? statusColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: statusColor?.withOpacity(0.3) ?? Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: statusColor != null 
              ? Border.all(color: statusColor, width: 2)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon, 
              color: statusColor ?? Colors.white, 
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: statusColor ?? Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: (statusColor ?? Colors.white).withOpacity(0.9),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hızlı İşlemler',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildActionCard(
              'Araba Ekle',
              Icons.add_circle,
              Colors.blue,
              () => context.push('/cars'),
            ),
            const SizedBox(width: 12),
            _buildActionCard(
              'Bakım Ekle',
              Icons.build,
              Colors.orange,
              () => context.push('/maintenance/add'),
            ),
            const SizedBox(width: 12),
            _buildActionCard(
              'Raporlar',
              Icons.analytics,
              Colors.green,
              () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingMaintenance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Yaklaşan Bakımlar',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/maintenance'),
              child: const Text('Tümünü Gör'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'Henüz yaklaşan bakım yok',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Arabanızı ekledikten sonra bakım planınızı oluşturabilirsiniz',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Son Aktiviteler',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/maintenance'),
              child: const Text('Tümünü Gör'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'Henüz aktivite yok',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Bakım kayıtlarınız burada görünecek',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMileageReminderCard(int count) {
    return Card(
      color: Colors.orange.shade50,
      elevation: 3,
      child: InkWell(
        onTap: () => context.push('/cars'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.speed,
                  color: Colors.orange.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 Kilometre Güncelleme Gerekli',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 1 
                          ? '1 araç kilometre güncellemesi bekliyor'
                          : '$count araç kilometre güncellemesi bekliyor',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Doğru bakım önerileri için araç kilometrelerinizi güncelleyin',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Güncelle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      // Provider'ı yenile
                      ref.refresh(mileageReminderProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔄 Hatırlatıcılar yenilendi'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.refresh,
                        color: Colors.blue.shade700,
                        size: 16,
                      ),
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
} 
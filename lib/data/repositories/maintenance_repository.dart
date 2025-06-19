import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/maintenance.dart';

class MaintenanceRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _currentUserId;

  MaintenanceRepository() {
    _currentUserId = _supabase.auth.currentUser?.id;
  }

  // Araç için bakım bilgilerini kaydet/güncelle
  Future<void> saveMaintenanceInfo({
    required String carId,
    int? lastGeneralServiceKm,
    int? lastHeavyServiceKm,
    String? generalNotes,
    String? heavyNotes,
    double? generalCost,
    double? heavyCost,
    String? generalServiceProvider,
    String? heavyServiceProvider,
  }) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();

      // Genel bakım kaydı
      if (lastGeneralServiceKm != null) {
        await _upsertMaintenanceRecord(
          carId: carId,
          maintenanceType: 'general',
          title: 'Genel Bakım',
          mileageAtService: lastGeneralServiceKm,
          notes: generalNotes,
          cost: generalCost,
          serviceProvider: generalServiceProvider,
          datePerformed: now,
        );
      }

      // Ağır bakım kaydı
      if (lastHeavyServiceKm != null) {
        await _upsertMaintenanceRecord(
          carId: carId,
          maintenanceType: 'heavy',
          title: 'Ağır Bakım',
          mileageAtService: lastHeavyServiceKm,
          notes: heavyNotes,
          cost: heavyCost,
          serviceProvider: heavyServiceProvider,
          datePerformed: now,
        );
      }

      print('✅ Maintenance info saved successfully');
    } catch (e) {
      print('❌ Error saving maintenance info: $e');
      throw Exception('Failed to save maintenance info: $e');
    }
  }

  // Bakım kaydını ekle veya güncelle
  Future<void> _upsertMaintenanceRecord({
    required String carId,
    required String maintenanceType,
    required String title,
    required int mileageAtService,
    String? notes,
    double? cost,
    String? serviceProvider,
    required DateTime datePerformed,
  }) async {
    // Sonraki bakım tarih ve kilometresini hesapla
    final nextServiceInfo = _calculateNextService(
      maintenanceType: maintenanceType,
      currentMileage: mileageAtService,
      lastServiceDate: datePerformed,
      carId: carId,
    );

    // Aynı tip bakım kaydı var mı kontrol et
    final existingRecord = await _getLatestMaintenanceRecord(carId, maintenanceType);

    if (existingRecord != null) {
      // Güncelle
      await _supabase
          .from('maintenance_records')
          .update({
            'mileage_at_service': mileageAtService,
            'date_performed': datePerformed.toIso8601String().split('T')[0],
            'notes': notes,
            'cost': cost,
            'service_provider': serviceProvider,
            'next_service_date': nextServiceInfo['nextDate'],
            'next_service_mileage': nextServiceInfo['nextMileage'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existingRecord['id']);
    } else {
      // Yeni kayıt oluştur
      await _supabase
          .from('maintenance_records')
          .insert({
            'car_id': carId,
            'user_id': _currentUserId!,
            'maintenance_type': maintenanceType,
            'title': title,
            'description': '$title - $mileageAtService km\'de yapıldı',
            'date_performed': datePerformed.toIso8601String().split('T')[0],
            'mileage_at_service': mileageAtService,
            'notes': notes,
            'cost': cost,
            'service_provider': serviceProvider,
            'status': 'completed',
            'next_service_date': nextServiceInfo['nextDate'],
            'next_service_mileage': nextServiceInfo['nextMileage'],
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
    }
  }

  // Sonraki bakım tarih ve kilometresini hesapla
  Map<String, dynamic> _calculateNextService({
    required String maintenanceType,
    required int currentMileage,
    required DateTime lastServiceDate,
    required String carId,
  }) {
    int intervalKm;
    int intervalMonths;

    if (maintenanceType == 'general') {
      // Genel bakım aralığı
      if (currentMileage >= 100000) {
        intervalKm = 10000; // 100.000+ km için 10.000 km
        intervalMonths = 6; // 6 ayda bir
      } else {
        intervalKm = 15000; // 100.000 km altı için 15.000 km
        intervalMonths = 12; // Yılda bir
      }
    } else {
      // Ağır bakım aralığı
      intervalKm = 80000; // 80.000 km arayla
      intervalMonths = 60; // 5 yılda bir
    }

    final nextServiceDate = DateTime(
      lastServiceDate.year,
      lastServiceDate.month + intervalMonths,
      lastServiceDate.day,
    );

    final nextServiceMileage = currentMileage + intervalKm;

    return {
      'nextDate': nextServiceDate.toIso8601String().split('T')[0],
      'nextMileage': nextServiceMileage,
    };
  }

  // Belirli bakım türünün son kaydını getir
  Future<Map<String, dynamic>?> _getLatestMaintenanceRecord(String carId, String maintenanceType) async {
    try {
      final response = await _supabase
          .from('maintenance_records')
          .select()
          .eq('car_id', carId)
          .eq('user_id', _currentUserId!)
          .eq('maintenance_type', maintenanceType)
          .order('date_performed', ascending: false)
          .limit(1);

      return response.isEmpty ? null : response.first;
    } catch (e) {
      print('❌ Error getting latest maintenance record: $e');
      return null;
    }
  }

  // Araç için tüm bakım bilgilerini getir
  Future<Map<String, dynamic>> getMaintenanceInfo(String carId) async {
    try {
      if (_currentUserId == null) {
        return {
          'lastGeneralServiceKm': null, 
          'lastHeavyServiceKm': null,
          'generalNotes': null,
          'heavyNotes': null,
          'generalCost': null,
          'heavyCost': null,
          'generalServiceProvider': null,
          'heavyServiceProvider': null,
          'nextGeneralServiceDate': null,
          'nextGeneralServiceMileage': null,
          'nextHeavyServiceDate': null,
          'nextHeavyServiceMileage': null,
        };
      }

      final response = await _supabase
          .from('maintenance_records')
          .select('maintenance_type, mileage_at_service, notes, cost, service_provider, next_service_date, next_service_mileage')
          .eq('car_id', carId)
          .eq('user_id', _currentUserId!)
          .order('date_performed', ascending: false);

      int? lastGeneralServiceKm;
      int? lastHeavyServiceKm;
      String? generalNotes;
      String? heavyNotes;
      double? generalCost;
      double? heavyCost;
      String? generalServiceProvider;
      String? heavyServiceProvider;
      String? nextGeneralServiceDate;
      int? nextGeneralServiceMileage;
      String? nextHeavyServiceDate;
      int? nextHeavyServiceMileage;

      for (final record in response) {
        final type = record['maintenance_type'] as String;
        final mileage = record['mileage_at_service'] as int?;
        final notes = record['notes'] as String?;
        final cost = record['cost'] as double?;
        final serviceProvider = record['service_provider'] as String?;
        final nextServiceDate = record['next_service_date'] as String?;
        final nextServiceMileage = record['next_service_mileage'] as int?;

        if (type == 'general' && lastGeneralServiceKm == null) {
          lastGeneralServiceKm = mileage;
          generalNotes = notes;
          generalCost = cost;
          generalServiceProvider = serviceProvider;
          nextGeneralServiceDate = nextServiceDate;
          nextGeneralServiceMileage = nextServiceMileage;
        } else if (type == 'heavy' && lastHeavyServiceKm == null) {
          lastHeavyServiceKm = mileage;
          heavyNotes = notes;
          heavyCost = cost;
          heavyServiceProvider = serviceProvider;
          nextHeavyServiceDate = nextServiceDate;
          nextHeavyServiceMileage = nextServiceMileage;
        }

        // Her iki değeri de bulduk
        if (lastGeneralServiceKm != null && lastHeavyServiceKm != null) {
          break;
        }
      }

      return {
        'lastGeneralServiceKm': lastGeneralServiceKm,
        'lastHeavyServiceKm': lastHeavyServiceKm,
        'generalNotes': generalNotes,
        'heavyNotes': heavyNotes,
        'generalCost': generalCost,
        'heavyCost': heavyCost,
        'generalServiceProvider': generalServiceProvider,
        'heavyServiceProvider': heavyServiceProvider,
        'nextGeneralServiceDate': nextGeneralServiceDate,
        'nextGeneralServiceMileage': nextGeneralServiceMileage,
        'nextHeavyServiceDate': nextHeavyServiceDate,
        'nextHeavyServiceMileage': nextHeavyServiceMileage,
      };
    } catch (e) {
      print('❌ Error getting maintenance info: $e');
      return {
        'lastGeneralServiceKm': null, 
        'lastHeavyServiceKm': null,
        'generalNotes': null,
        'heavyNotes': null,
        'generalCost': null,
        'heavyCost': null,
        'generalServiceProvider': null,
        'heavyServiceProvider': null,
        'nextGeneralServiceDate': null,
        'nextGeneralServiceMileage': null,
        'nextHeavyServiceDate': null,
        'nextHeavyServiceMileage': null,
      };
    }
  }

  Future<List<Maintenance>> getAllMaintenance() async {
    // Legacy method - not implemented for Supabase yet
    return [];
  }

  Future<List<Maintenance>> getMaintenanceByCarId(String carId) async {
    // Legacy method - not implemented for Supabase yet
    return [];
  }

  Future<Maintenance?> getMaintenanceById(String id) async {
    // Legacy method - not implemented for Supabase yet
    return null;
  }

  Future<String> createMaintenance(Maintenance maintenance) async {
    // Legacy method - not implemented for Supabase yet
    return '';
  }

  Future<void> updateMaintenance(Maintenance maintenance) async {
    // Legacy method - not implemented for Supabase yet
  }

  Future<void> deleteMaintenance(String id) async {
    // Legacy method - not implemented for Supabase yet
  }

  Future<List<Maintenance>> getUpcomingMaintenance() async {
    // Legacy method - not implemented for Supabase yet
    return [];
  }

  Future<List<Maintenance>> getOverdueMaintenance() async {
    // Legacy method - not implemented for Supabase yet
    return [];
  }

  Future<List<Maintenance>> getMaintenanceByType(MaintenanceType type) async {
    // Legacy method - not implemented for Supabase yet
    return [];
  }

  Future<List<Maintenance>> getMaintenanceByStatus(MaintenanceStatus status) async {
    // Legacy method - not implemented for Supabase yet
    return [];
  }

  Future<List<Maintenance>> getMaintenanceByDateRange(DateTime startDate, DateTime endDate) async {
    // Legacy method - not implemented for Supabase yet
    return [];
  }

  Future<double> getTotalMaintenanceCost([String? carId]) async {
    // Legacy method - not implemented for Supabase yet
    return 0.0;
  }

  Future<int> getMaintenanceCount([String? carId]) async {
    // Legacy method - not implemented for Supabase yet
    return 0;
  }

  Future<List<Maintenance>> searchMaintenance(String query) async {
    // Legacy method - not implemented for Supabase yet
    return [];
  }

  Future<Maintenance?> getLastMaintenanceByType(String carId, MaintenanceType type) async {
    // Legacy method - not implemented for Supabase yet
    return null;
  }
} 
import 'dart:convert';
import 'package:flutter/services.dart';

class CarDatabaseService {
  static CarDatabaseService? _instance;
  static CarDatabaseService get instance {
    _instance ??= CarDatabaseService._internal();
    return _instance!;
  }
  CarDatabaseService._internal();

  Map<String, dynamic>? _carDatabase;
  bool _isLoaded = false;

  // Veritabanını yükle
  Future<void> loadDatabase() async {
    if (_isLoaded) return;
    
    try {
      final String jsonString = await rootBundle.loadString('assets/data/car_database.json');
      _carDatabase = json.decode(jsonString);
      _isLoaded = true;
    } catch (e) {
      print('Car database loading error: $e');
      // Fallback olarak boş veritabanı
      _carDatabase = {'brands': {}};
      _isLoaded = true;
    }
  }

  // Tüm markaları getir
  Future<List<String>> getBrands() async {
    await loadDatabase();
    final brands = _carDatabase?['brands'] as Map<String, dynamic>? ?? {};
    return brands.keys.toList()..sort();
  }

  // Markaya göre modelleri getir
  Future<List<String>> getModels(String brand) async {
    await loadDatabase();
    final brands = _carDatabase?['brands'] as Map<String, dynamic>? ?? {};
    final brandData = brands[brand] as Map<String, dynamic>? ?? {};
    final models = brandData['models'] as Map<String, dynamic>? ?? {};
    return models.keys.toList()..sort();
  }

  // Model ve markaya göre varyantları getir
  Future<List<String>> getVariants(String brand, String model) async {
    await loadDatabase();
    final brands = _carDatabase?['brands'] as Map<String, dynamic>? ?? {};
    final brandData = brands[brand] as Map<String, dynamic>? ?? {};
    final models = brandData['models'] as Map<String, dynamic>? ?? {};
    final modelData = models[model] as Map<String, dynamic>? ?? {};
    final variants = modelData['variants'] as Map<String, dynamic>? ?? {};
    return variants.keys.toList()..sort();
  }

  // Araç bilgilerini getir
  Future<CarData?> getCarData(String brand, String model, String variant) async {
    await loadDatabase();
    try {
      final brands = _carDatabase?['brands'] as Map<String, dynamic>? ?? {};
      final brandData = brands[brand] as Map<String, dynamic>? ?? {};
      final models = brandData['models'] as Map<String, dynamic>? ?? {};
      final modelData = models[model] as Map<String, dynamic>? ?? {};
      final variants = modelData['variants'] as Map<String, dynamic>? ?? {};
      final variantData = variants[variant] as Map<String, dynamic>? ?? {};

      if (variantData.isEmpty) return null;

      return CarData.fromMap(variantData);
    } catch (e) {
      print('Error getting car data: $e');
      return null;
    }
  }

  // Bakım ipuçlarını getir
  Future<List<String>> getMaintenanceTips(String fuelType) async {
    await loadDatabase();
    final tips = _carDatabase?['general_maintenance_tips'] as Map<String, dynamic>? ?? {};
    final fuelTips = tips[fuelType.toLowerCase()] as List<dynamic>? ?? [];
    return fuelTips.map((tip) => tip.toString()).toList();
  }

  // Bir sonraki bakımları hesapla
  Future<List<MaintenanceItem>> calculateUpcomingMaintenance(
    CarData carData, 
    int currentMileage,
  ) async {
    final List<MaintenanceItem> upcomingMaintenance = [];
    
    if (carData.maintenanceSchedule == null) return upcomingMaintenance;

    carData.maintenanceSchedule!.forEach((key, schedule) {
      final nextMileage = ((currentMileage / schedule.intervalKm).ceil() * schedule.intervalKm).toInt();
      final remainingKm = nextMileage - currentMileage;
      
      upcomingMaintenance.add(MaintenanceItem(
        type: key,
        description: schedule.description,
        nextMileage: nextMileage,
        remainingKm: remainingKm,
        intervalKm: schedule.intervalKm,
        intervalMonths: schedule.intervalMonths,
      ));
    });

    // Kalan kilometreye göre sırala
    upcomingMaintenance.sort((a, b) => a.remainingKm.compareTo(b.remainingKm));
    
    return upcomingMaintenance;
  }
}

// Araç verileri modeli
class CarData {
  final String engine;
  final String fuelType;
  final String yearRange;
  final Map<String, MaintenanceSchedule>? maintenanceSchedule;
  final List<String>? commonParts;

  CarData({
    required this.engine,
    required this.fuelType,
    required this.yearRange,
    this.maintenanceSchedule,
    this.commonParts,
  });

  factory CarData.fromMap(Map<String, dynamic> map) {
    Map<String, MaintenanceSchedule>? schedule;
    
    if (map['maintenance_schedule'] != null) {
      final scheduleMap = map['maintenance_schedule'] as Map<String, dynamic>;
      schedule = {};
      scheduleMap.forEach((key, value) {
        schedule![key] = MaintenanceSchedule.fromMap(value);
      });
    }

    return CarData(
      engine: map['engine'] ?? '',
      fuelType: map['fuel_type'] ?? '',
      yearRange: map['year_range'] ?? '',
      maintenanceSchedule: schedule,
      commonParts: map['common_parts'] != null 
          ? List<String>.from(map['common_parts'])
          : null,
    );
  }
}

// Bakım programı modeli
class MaintenanceSchedule {
  final int intervalKm;
  final int intervalMonths;
  final String description;

  MaintenanceSchedule({
    required this.intervalKm,
    required this.intervalMonths,
    required this.description,
  });

  factory MaintenanceSchedule.fromMap(Map<String, dynamic> map) {
    return MaintenanceSchedule(
      intervalKm: map['interval_km'] ?? 0,
      intervalMonths: map['interval_months'] ?? 0,
      description: map['description'] ?? '',
    );
  }
}

// Bakım öğesi modeli
class MaintenanceItem {
  final String type;
  final String description;
  final int nextMileage;
  final int remainingKm;
  final int intervalKm;
  final int intervalMonths;

  MaintenanceItem({
    required this.type,
    required this.description,
    required this.nextMileage,
    required this.remainingKm,
    required this.intervalKm,
    required this.intervalMonths,
  });

  bool get isUrgent => remainingKm <= 5000;
  bool get isWarning => remainingKm <= 10000;
} 
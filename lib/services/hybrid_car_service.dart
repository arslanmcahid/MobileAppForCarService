import 'package:flutter/foundation.dart';
import 'car_database_service.dart';
import 'car_api_service.dart';

class HybridCarService {
  static HybridCarService? _instance;
  static HybridCarService get instance {
    _instance ??= HybridCarService._internal();
    return _instance!;
  }
  HybridCarService._internal();

  final CarDatabaseService _localService = CarDatabaseService.instance;
  final CarApiService _apiService = CarApiService.instance;

  /// Önce local, sonra API'den marka listesini getir
  Future<List<String>> getBrands() async {
    try {
      // Önce local veritabanından markaları al
      final localBrands = await _localService.getBrands();
      
      // API'den popüler markaları al
      final apiBrands = _apiService.getPopularBrands();
      
      // İkisini birleştir ve unique yap
      final allBrands = <String>{...localBrands, ...apiBrands}.toList();
      allBrands.sort();
      
      return allBrands;
    } catch (e) {
      if (kDebugMode) print('Error getting brands: $e');
      return _apiService.getPopularBrands(); // Fallback
    }
  }

  /// Model listesini al - önce local, bulunamazsa API'yi kullan
  Future<List<String>> getModels(String brand) async {
    try {
      // Önce local veritabanından kontrol et
      final localModels = await _localService.getModels(brand);
      
      if (localModels.isNotEmpty) {
        if (kDebugMode) print('Found ${localModels.length} models locally for $brand');
        return localModels;
      }
      
      // Local'de bulunamazsa, kullanıcı girişi bekle
      // Bu kısımda gerçek API'den model çekimi yapılabilir
      if (kDebugMode) print('No local models found for $brand, returning popular models');
      return _getPopularModelsForBrand(brand);
      
    } catch (e) {
      if (kDebugMode) print('Error getting models: $e');
      return [];
    }
  }

  /// Varyant listesini al
  Future<List<String>> getVariants(String brand, String model) async {
    try {
      // Önce local veritabanından kontrol et
      final localVariants = await _localService.getVariants(brand, model);
      
      if (localVariants.isNotEmpty) {
        if (kDebugMode) print('Found ${localVariants.length} variants locally');
        return localVariants;
      }
      
      // Local'de bulunamazsa, popüler varyantları döndür
      return _getPopularVariantsForModel(brand, model);
      
    } catch (e) {
      if (kDebugMode) print('Error getting variants: $e');
      return ['Standart', 'Comfort', 'Elegance', 'Sport'];
    }
  }

  /// Araç verilerini al - hibrit yaklaşım
  Future<HybridCarData?> getCarData(String brand, String model, String? variant) async {
    try {
      // Önce local veritabanından kontrol et
      if (variant != null) {
        final localData = await _localService.getCarData(brand, model, variant);
        if (localData != null) {
          if (kDebugMode) print('Found car data locally');
          return HybridCarData.fromLocal(localData);
        }
      }
      
      // Local'de bulunamazsa API'den çek
      if (kDebugMode) print('Fetching car data from API for $brand $model');
      final apiData = await _apiService.fetchCarData(brand, model, null);
      
      if (apiData != null) {
        return HybridCarData.fromApi(apiData);
      }
      
      // Her ikisi de başarısızsa, varsayılan veri oluştur
      return _createDefaultCarData(brand, model, variant);
      
    } catch (e) {
      if (kDebugMode) print('Error getting car data: $e');
      return _createDefaultCarData(brand, model, variant);
    }
  }

  /// Bakım hesaplaması yap
  Future<List<MaintenanceItem>> calculateUpcomingMaintenance(
    HybridCarData carData, 
    int currentMileage,
  ) async {
    // Kilometre bazlı bakım programını oluştur
    final mileageBasedSchedule = _getMileageBasedMaintenanceSchedule(
      carData.brand, 
      currentMileage
    );
    
    // CarData'yı güncel bakım programı ile oluştur
    final updatedCarData = CarData(
      engine: carData.engine,
      fuelType: carData.fuelType,
      yearRange: carData.yearRange,
      maintenanceSchedule: mileageBasedSchedule,
    );
    
    return await _localService.calculateUpcomingMaintenance(
      updatedCarData, 
      currentMileage,
    );
  }

  /// Marka için popüler modelleri döndür
  List<String> _getPopularModelsForBrand(String brand) {
    final popularModels = {
      'Toyota': ['Corolla', 'Camry', 'Yaris', 'Auris', 'RAV4', 'C-HR'],
      'BMW': ['3 Series', '5 Series', 'X3', 'X5', '1 Series', 'Z4'],
      'Mercedes-Benz': ['C-Class', 'E-Class', 'A-Class', 'GLC', 'GLE'],
      'Audi': ['A3', 'A4', 'A6', 'Q3', 'Q5', 'Q7'],
      'Volkswagen': ['Golf', 'Passat', 'Polo', 'Tiguan', 'Touran'],
      'Ford': ['Focus', 'Fiesta', 'Mondeo', 'Kuga', 'EcoSport'],
      'Peugeot': ['208', '308', '3008', '5008', '2008', '301'],
      'Renault': ['Clio', 'Megane', 'Kadjar', 'Captur', 'Talisman'],
      'Hyundai': ['i20', 'i30', 'Elantra', 'Tucson', 'Santa Fe'],
      'Kia': ['Rio', 'Cerato', 'Sportage', 'Sorento', 'Picanto'],
    };
    
    return popularModels[brand] ?? ['Standart Model'];
  }

  /// Model için popüler varyantları döndür
  List<String> _getPopularVariantsForModel(String brand, String model) {
    // Marka bazlı tipik varyantlar
    if (brand.toLowerCase() == 'bmw') {
      return ['sDrive18i', 'sDrive20i', 'xDrive20d', 'M Sport'];
    } else if (brand.toLowerCase() == 'mercedes-benz') {
      return ['180', '200', '220d', 'AMG Line'];
    } else if (brand.toLowerCase() == 'audi') {
      return ['1.4 TFSI', '2.0 TDI', 'S line', 'Quattro'];
    } else if (brand.toLowerCase() == 'toyota') {
      return ['1.6 Valvematic', '1.4 D-4D', 'Hybrid', 'Sport'];
    } else {
      return ['1.2', '1.4', '1.6', '2.0', 'Diesel', 'Sport'];
    }
  }

  /// Varsayılan araç verisi oluştur
  HybridCarData _createDefaultCarData(String brand, String model, String? variant) {
    return HybridCarData(
      brand: brand,
      model: model,
      variant: variant,
      engine: 'Bilinmiyor',
      fuelType: 'Benzin',
      yearRange: '2015-2024',
      transmission: 'Manuel',
      drivetrain: 'FWD',
      maintenanceSchedule: _getMileageBasedMaintenanceSchedule(brand, 0),
      source: 'default',
    );
  }

  /// Marka bazlı yağ değişim aralığı (100.000 km'den sonra düşürülür)
  int _getOilIntervalForBrand(String brand, [int? currentMileage]) {
    int baseInterval;
    
    switch (brand.toLowerCase()) {
      case 'toyota':
      case 'honda':
      case 'nissan':
        baseInterval = 10000;
        break;
      case 'bmw':
      case 'mercedes-benz':
      case 'audi':
      case 'volkswagen':
      case 'peugeot':
        baseInterval = 15000;
        break;
      case 'ford':
      case 'hyundai':
      case 'kia':
        baseInterval = 12000;
        break;
      default:
        baseInterval = 12000;
        break;
    }

    // 100.000 km'den sonra bakım aralığını azalt
    if (currentMileage != null && currentMileage >= 100000) {
      if (baseInterval == 15000) {
        baseInterval = 10000; // 15.000'den 10.000'e düşür
      } else if (baseInterval == 12000) {
        baseInterval = 10000; // 12.000'den 10.000'e düşür
      }
      // Toyota zaten 10.000, değişmez
    }

    return baseInterval;
  }

  /// Kilometre bazlı bakım programı oluştur
  Map<String, MaintenanceSchedule> _getMileageBasedMaintenanceSchedule(
    String brand, 
    int currentMileage
  ) {
    final oilInterval = _getOilIntervalForBrand(brand, currentMileage);
    
    return {
      'oil_change': MaintenanceSchedule(
        intervalKm: oilInterval,
        intervalMonths: 12,
        description: currentMileage >= 100000 
            ? 'Motor yağı ve filtre değişimi (Yüksek kilometre bakımı)'
            : 'Motor yağı ve filtre değişimi',
      ),
      'general_service': MaintenanceSchedule(
        intervalKm: currentMileage >= 100000 ? 10000 : 15000,
        intervalMonths: 12,
        description: currentMileage >= 100000
            ? 'Genel bakım ve kontrol (Yüksek kilometre - 10.000 km arayla)'
            : 'Genel bakım ve kontrol (15.000 km arayla)',
      ),
      'air_filter': MaintenanceSchedule(
        intervalKm: 30000,
        intervalMonths: 24,
        description: 'Hava filtresi değişimi',
      ),
      'brake_pads': MaintenanceSchedule(
        intervalKm: 60000,
        intervalMonths: 60,
        description: 'Fren balata değişimi',
      ),
      'spark_plugs': MaintenanceSchedule(
        intervalKm: brand.toLowerCase() == 'toyota' ? 100000 : 60000,
        intervalMonths: 60,
        description: 'Buji değişimi',
      ),
    };
  }
}

/// Hibrit araç verisi modeli
class HybridCarData {
  final String brand;
  final String model;
  final String? variant;
  final String engine;
  final String fuelType;
  final String yearRange;
  final String transmission;
  final String drivetrain;
  final Map<String, MaintenanceSchedule> maintenanceSchedule;
  final String source; // 'local', 'api', 'default'

  HybridCarData({
    required this.brand,
    required this.model,
    this.variant,
    required this.engine,
    required this.fuelType,
    required this.yearRange,
    required this.transmission,
    required this.drivetrain,
    required this.maintenanceSchedule,
    required this.source,
  });

  factory HybridCarData.fromLocal(CarData localData) {
    return HybridCarData(
      brand: '',
      model: '',
      variant: null,
      engine: localData.engine,
      fuelType: localData.fuelType,
      yearRange: localData.yearRange,
      transmission: 'Manuel',
      drivetrain: 'FWD',
      maintenanceSchedule: localData.maintenanceSchedule ?? {},
      source: 'local',
    );
  }

  factory HybridCarData.fromApi(CarApiData apiData) {
    Map<String, MaintenanceSchedule> schedule = {};
    apiData.maintenanceSchedule.forEach((key, value) {
      schedule[key] = MaintenanceSchedule(
        intervalKm: value['interval_km'] ?? 12000,
        intervalMonths: value['interval_months'] ?? 12,
        description: value['description'] ?? '',
      );
    });

    return HybridCarData(
      brand: apiData.make,
      model: apiData.model,
      variant: null,
      engine: apiData.engine,
      fuelType: apiData.fuelType,
      yearRange: apiData.year?.toString() ?? '2020',
      transmission: apiData.transmission,
      drivetrain: apiData.drivetrain,
      maintenanceSchedule: schedule,
      source: 'api',
    );
  }

  /// Local CarData format'ına dönüştür
  CarData toCarData() {
    return CarData(
      engine: engine,
      fuelType: fuelType,
      yearRange: yearRange,
      maintenanceSchedule: maintenanceSchedule,
      commonParts: null,
    );
  }
} 
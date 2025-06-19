import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CarApiService {
  static CarApiService? _instance;
  static CarApiService get instance {
    _instance ??= CarApiService._internal();
    return _instance!;
  }
  CarApiService._internal();

  // Cache sistemi
  final Map<String, CarApiData> _cache = {};
  final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheExpiry = Duration(hours: 24);

  // API endpoints (gerçek servislere bağlanabilir)
  static const String _baseUrl = 'https://api.api-ninjas.com/v1/cars';
  static const String _maintenanceUrl = 'https://car-data.p.rapidapi.com/cars';
  
  // API Keys (gerçek kullanımda environment'dan gelecek)
  static const String _apiNinjaKey = 'YOUR_API_NINJA_KEY';
  static const String _rapidApiKey = 'YOUR_RAPID_API_KEY';

  /// Araç bilgilerini API'den çek
  Future<CarApiData?> fetchCarData(String make, String model, int? year) async {
    final cacheKey = '${make}_${model}_$year';
    
    // Cache kontrolü
    if (_cache.containsKey(cacheKey) && _cacheTime.containsKey(cacheKey)) {
      final cacheAge = DateTime.now().difference(_cacheTime[cacheKey]!);
      if (cacheAge < _cacheExpiry) {
        if (kDebugMode) print('Returning cached data for $cacheKey');
        return _cache[cacheKey];
      }
    }

    try {
      // API Ninjas'tan temel araç bilgilerini çek
      final carInfo = await _fetchBasicCarInfo(make, model, year);
      
      // Bakım bilgilerini farklı kaynaklardan çek
      final maintenanceInfo = await _fetchMaintenanceInfo(make, model, year);
      
      if (carInfo != null) {
        final apiData = CarApiData.fromApiNinjas(carInfo, maintenanceInfo);
        
        // Cache'e kaydet
        _cache[cacheKey] = apiData;
        _cacheTime[cacheKey] = DateTime.now();
        
        return apiData;
      }
    } catch (e) {
      if (kDebugMode) print('API error: $e');
    }

    // API başarısız olursa local fallback
    return _getFallbackData(make, model, year);
  }

  /// API Ninjas'tan temel araç bilgilerini çek
  Future<Map<String, dynamic>?> _fetchBasicCarInfo(String make, String model, int? year) async {
    try {
      final queryParams = {
        'make': make,
        'model': model,
        if (year != null) 'year': year.toString(),
        'limit': '1',
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'X-Api-Key': _apiNinjaKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.isNotEmpty ? data.first : null;
      }
    } catch (e) {
      if (kDebugMode) print('Basic car info API error: $e');
    }
    return null;
  }

  /// Bakım bilgilerini çek (simüle edilmiş)
  Future<Map<String, dynamic>?> _fetchMaintenanceInfo(String make, String model, int? year) async {
    // Bu kısımda gerçek bakım API'si kullanılabilir
    // Şimdilik akıllı tahmini veriler döndürüyoruz
    
    return _generateMaintenanceSchedule(make, model);
  }

  /// Marka ve modele göre akıllı bakım programı oluştur
  Map<String, dynamic> _generateMaintenanceSchedule(String make, String model) {
    // Marka bazlı genel kurallar
    final brandRules = {
      'toyota': {'oil_interval': 10000, 'reliability': 'high'},
      'bmw': {'oil_interval': 15000, 'reliability': 'medium'},
      'ford': {'oil_interval': 12000, 'reliability': 'medium'},
      'peugeot': {'oil_interval': 15000, 'reliability': 'medium'},
      'volkswagen': {'oil_interval': 15000, 'reliability': 'medium'},
      'mercedes': {'oil_interval': 15000, 'reliability': 'high'},
      'audi': {'oil_interval': 15000, 'reliability': 'medium'},
    };

    final makeLower = make.toLowerCase();
    final rules = brandRules[makeLower] ?? {'oil_interval': 12000, 'reliability': 'medium'};
    
    return {
      'oil_change': {
        'interval_km': rules['oil_interval'],
        'interval_months': 12,
        'description': 'Motor yağı ve filtre değişimi',
      },
      'air_filter': {
        'interval_km': 30000,
        'interval_months': 24,
        'description': 'Hava filtresi değişimi',
      },
      'brake_pads': {
        'interval_km': 60000,
        'interval_months': 48,
        'description': 'Fren balata değişimi',
      },
      'spark_plugs': {
        'interval_km': makeLower == 'toyota' ? 100000 : 60000,
        'interval_months': makeLower == 'toyota' ? 120 : 60,
        'description': 'Buji değişimi',
      },
    };
  }

  /// Fallback verileri (API çalışmazsa)
  CarApiData? _getFallbackData(String make, String model, int? year) {
    return CarApiData(
      make: make,
      model: model,
      year: year,
      engine: 'Bilinmiyor',
      fuelType: 'Benzin', // Varsayılan
      transmission: 'Manuel',
      drivetrain: 'FWD',
      maintenanceSchedule: _generateMaintenanceSchedule(make, model),
      source: 'fallback',
    );
  }

  /// Popüler araç markalarını getir
  List<String> getPopularBrands() {
    return [
      'Toyota',
      'BMW',
      'Mercedes-Benz',
      'Audi',
      'Volkswagen',
      'Ford',
      'Peugeot',
      'Renault',
      'Hyundai',
      'Kia',
      'Nissan',
      'Honda',
      'Chevrolet',
      'Fiat',
      'Opel',
      'Skoda',
      'Seat',
      'Volvo',
      'Mazda',
      'Mitsubishi',
    ]..sort();
  }

  /// Cache'i temizle
  void clearCache() {
    _cache.clear();
    _cacheTime.clear();
  }
}

/// API'den gelen araç verileri modeli
class CarApiData {
  final String make;
  final String model;
  final int? year;
  final String engine;
  final String fuelType;
  final String transmission;
  final String drivetrain;
  final Map<String, dynamic> maintenanceSchedule;
  final String source; // 'api', 'cache', 'fallback'

  CarApiData({
    required this.make,
    required this.model,
    this.year,
    required this.engine,
    required this.fuelType,
    required this.transmission,
    required this.drivetrain,
    required this.maintenanceSchedule,
    required this.source,
  });

  factory CarApiData.fromApiNinjas(Map<String, dynamic> apiData, Map<String, dynamic>? maintenanceData) {
    return CarApiData(
      make: apiData['make'] ?? '',
      model: apiData['model'] ?? '',
      year: apiData['year'],
      engine: '${apiData['displacement']}L ${apiData['cylinders']}cyl',
      fuelType: apiData['fuel_type'] ?? 'Benzin',
      transmission: apiData['transmission'] ?? 'Manuel',
      drivetrain: apiData['drive'] ?? 'FWD',
      maintenanceSchedule: maintenanceData ?? {},
      source: 'api',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'make': make,
      'model': model,
      'year': year,
      'engine': engine,
      'fuel_type': fuelType,
      'transmission': transmission,
      'drivetrain': drivetrain,
      'maintenance_schedule': maintenanceSchedule,
      'source': source,
    };
  }
}

/// API status ve cache bilgileri
class ApiStatus {
  final bool isOnline;
  final int cacheCount;
  final DateTime? lastUpdate;

  ApiStatus({
    required this.isOnline,
    required this.cacheCount,
    this.lastUpdate,
  });
} 
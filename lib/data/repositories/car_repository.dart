import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car.dart';
import '../../services/supabase_auth_service.dart';

class CarRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseAuthService _authService = SupabaseAuthService.instance;

  // Get current user ID
  String? get _currentUserId => _authService.currentUser?.id;

  Future<List<Car>> getAllCars() async {
    try {
      // Check if user is authenticated
      if (_currentUserId == null) {
        print('🚫 User not authenticated');
        return [];
      }

      print('📱 Fetching cars for user: $_currentUserId');
      
      final response = await _supabase
          .from('cars')
          .select()
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false);

      print('📦 Cars response: $response');

      return response.map<Car>((json) => Car.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error fetching cars: $e');
      return [];
    }
  }

  Future<Car?> getCarById(String id) async {
    try {
      if (_currentUserId == null) return null;

      final response = await _supabase
          .from('cars')
          .select()
          .eq('id', id)
          .eq('user_id', _currentUserId!)
          .single();

      return Car.fromMap(response);
    } catch (e) {
      print('❌ Error fetching car by ID: $e');
      return null;
    }
  }

  Future<String> insertCar(Car car) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      print('💾 Inserting car for user: $_currentUserId');
      print('🚗 Car data: ${car.toMap()}');

      // Only send fields that exist in database schema
      final carData = {
        'user_id': _currentUserId!,
        'brand': car.brand,
        'model': car.model,
        'year': car.year,
        'license_plate': car.licensePlate,
        'color': car.color,
        'mileage': car.mileage,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('cars')
          .insert(carData)
          .select()
          .single();

      print('✅ Car inserted successfully: ${response['id']}');
      return response['id'].toString();
    } catch (e) {
      print('❌ Error inserting car: $e');
      throw Exception('Failed to save car: $e');
    }
  }

  Future<int> updateCar(Car car) async {
    try {
      if (_currentUserId == null) return 0;

      // Only update fields that exist in database schema
      final carData = {
        'brand': car.brand,
        'model': car.model,
        'year': car.year,
        'license_plate': car.licensePlate,
        'color': car.color,
        'mileage': car.mileage,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('cars')
          .update(carData)
          .eq('id', car.id)
          .eq('user_id', _currentUserId!);

      print('✅ Car updated successfully');
      return 1;
    } catch (e) {
      print('❌ Error updating car: $e');
      return 0;
    }
  }

  Future<int> deleteCar(String id) async {
    try {
      if (_currentUserId == null) return 0;

      await _supabase
          .from('cars')
          .delete()
          .eq('id', id)
          .eq('user_id', _currentUserId!);

      print('✅ Car deleted successfully');
      return 1;
    } catch (e) {
      print('❌ Error deleting car: $e');
      return 0;
    }
  }

  Future<List<Car>> searchCars(String query) async {
    try {
      if (_currentUserId == null) return [];

      final searchQuery = query.toLowerCase();
      
      final response = await _supabase
          .from('cars')
          .select()
          .eq('user_id', _currentUserId!)
          .or('brand.ilike.%$searchQuery%,model.ilike.%$searchQuery%,license_plate.ilike.%$searchQuery%')
          .order('created_at', ascending: false);

      return response.map<Car>((json) => Car.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error searching cars: $e');
      return [];
    }
  }

  Future<int> getCarCount() async {
    try {
      if (_currentUserId == null) return 0;

      final response = await _supabase
          .from('cars')
          .select('id')
          .eq('user_id', _currentUserId!);

      return response.length;
    } catch (e) {
      print('❌ Error getting car count: $e');
      return 0;
    }
  }

  Future<Car?> getCarByLicensePlate(String licensePlate) async {
    try {
      if (_currentUserId == null) return null;

      final response = await _supabase
          .from('cars')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('license_plate', licensePlate)
          .single();

      return Car.fromMap(response);
    } catch (e) {
      print('❌ Error fetching car by license plate: $e');
      return null;
    }
  }

  Future<void> updateCarMileage(String carId, int mileage) async {
    try {
      if (_currentUserId == null) return;

      await _supabase
          .from('cars')
          .update({
            'mileage': mileage,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', carId)
          .eq('user_id', _currentUserId!);

      print('✅ Car mileage updated successfully');
    } catch (e) {
      print('❌ Error updating car mileage: $e');
    }
  }
} 
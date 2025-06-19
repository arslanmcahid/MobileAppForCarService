class Car {
  final String id;
  final String brand;
  final String model;
  final String year;
  final String licensePlate;
  final String? color;
  final String? vin;
  final int? mileage;
  final String? fuelType;
  final String? engineSize;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Car({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.licensePlate,
    this.color,
    this.vin,
    this.mileage,
    this.fuelType,
    this.engineSize,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Car.fromMap(Map<String, dynamic> map) {
    return Car(
      id: map['id'],
      brand: map['brand'],
      model: map['model'],
      year: map['year'],
      licensePlate: map['license_plate'],
      color: map['color'],
      vin: map['vin'],
      mileage: map['mileage'],
      fuelType: map['fuel_type'],
      engineSize: map['engine_size'],
      imagePath: map['image_path'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'licensePlate': licensePlate,
      'year': year,
      'color': color,
      'mileage': mileage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Car copyWith({
    String? id,
    String? brand,
    String? model,
    String? licensePlate,
    String? year,
    String? color,
    int? mileage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Car(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      licensePlate: licensePlate ?? this.licensePlate,
      year: year ?? this.year,
      color: color ?? this.color,
      mileage: mileage ?? this.mileage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Car(id: $id, brand: $brand, model: $model, year: $year, licensePlate: $licensePlate)';
  }
} 
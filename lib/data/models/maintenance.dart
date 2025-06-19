enum MaintenanceType {
  oilChange('Yağ Değişimi'),
  filterChange('Filtre Değişimi'),
  brakeService('Fren Bakımı'),
  tireMaintenance('Lastik Bakımı'),
  batteryService('Akü Bakımı'),
  engineService('Motor Bakımı'),
  transmission('Şanzıman Bakımı'),
  coolantChange('Antifriz Değişimi'),
  sparkPlugs('Buji Değişimi'),
  airFilter('Hava Filtresi'),
  fuelFilter('Yakıt Filtresi'),
  timingBelt('Triger Kayışı'),
  serpentineBelt('V Kayış'),
  inspection('Muayene'),
  other('Diğer');

  const MaintenanceType(this.displayName);
  final String displayName;
}

enum MaintenanceStatus {
  scheduled('Planlandı'),
  inProgress('Devam Ediyor'),
  completed('Tamamlandı'),
  overdue('Gecikti');

  const MaintenanceStatus(this.displayName);
  final String displayName;
}

class Maintenance {
  final String id;
  final String carId;
  final MaintenanceType type;
  final String title;
  final String? description;
  final DateTime datePerformed;
  final int? mileageAtService;
  final double? cost;
  final String? serviceProvider;
  final String? notes;
  final MaintenanceStatus status;
  final DateTime? nextServiceDate;
  final int? nextServiceMileage;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  Maintenance({
    required this.id,
    required this.carId,
    required this.type,
    required this.title,
    this.description,
    required this.datePerformed,
    this.mileageAtService,
    this.cost,
    this.serviceProvider,
    this.notes,
    required this.status,
    this.nextServiceDate,
    this.nextServiceMileage,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Maintenance.fromMap(Map<String, dynamic> map) {
    return Maintenance(
      id: map['id'],
      carId: map['car_id'],
      type: MaintenanceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MaintenanceType.other,
      ),
      title: map['title'],
      description: map['description'],
      datePerformed: DateTime.parse(map['date_performed']),
      mileageAtService: map['mileage_at_service'],
      cost: map['cost']?.toDouble(),
      serviceProvider: map['service_provider'],
      notes: map['notes'],
      status: MaintenanceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MaintenanceStatus.scheduled,
      ),
      nextServiceDate: map['next_service_date'] != null 
          ? DateTime.parse(map['next_service_date']) 
          : null,
      nextServiceMileage: map['next_service_mileage'],
      attachments: map['attachments'] != null 
          ? List<String>.from(map['attachments'].split(','))
          : [],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'car_id': carId,
      'type': type.name,
      'title': title,
      'description': description,
      'date_performed': datePerformed.toIso8601String(),
      'mileage_at_service': mileageAtService,
      'cost': cost,
      'service_provider': serviceProvider,
      'notes': notes,
      'status': status.name,
      'next_service_date': nextServiceDate?.toIso8601String(),
      'next_service_mileage': nextServiceMileage,
      'attachments': attachments.join(','),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Maintenance copyWith({
    String? id,
    String? carId,
    MaintenanceType? type,
    String? title,
    String? description,
    DateTime? datePerformed,
    int? mileageAtService,
    double? cost,
    String? serviceProvider,
    String? notes,
    MaintenanceStatus? status,
    DateTime? nextServiceDate,
    int? nextServiceMileage,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Maintenance(
      id: id ?? this.id,
      carId: carId ?? this.carId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      datePerformed: datePerformed ?? this.datePerformed,
      mileageAtService: mileageAtService ?? this.mileageAtService,
      cost: cost ?? this.cost,
      serviceProvider: serviceProvider ?? this.serviceProvider,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      nextServiceDate: nextServiceDate ?? this.nextServiceDate,
      nextServiceMileage: nextServiceMileage ?? this.nextServiceMileage,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Maintenance(id: $id, carId: $carId, type: $type, title: $title, status: $status)';
  }
} 
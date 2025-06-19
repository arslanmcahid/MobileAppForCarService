import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/car.dart';
import '../../data/models/maintenance.dart';
import '../../data/repositories/car_repository.dart';
import '../../services/hybrid_car_service.dart';
import '../../services/car_database_service.dart';

class SmartAddCarForm extends ConsumerStatefulWidget {
  final VoidCallback? onCarAdded;

  const SmartAddCarForm({super.key, this.onCarAdded});

  @override
  ConsumerState<SmartAddCarForm> createState() => _SmartAddCarFormState();
}

class _SmartAddCarFormState extends ConsumerState<SmartAddCarForm> {
  final _formKey = GlobalKey<FormState>();
  final _licensePlateController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _mileageController = TextEditingController();
  
  final HybridCarService _carService = HybridCarService.instance;
  
  bool _isLoading = false;
  bool _isLoadingData = false;
  List<String> _brands = [];
  List<String> _models = [];
  List<String> _variants = [];
  
  String? _selectedBrand;
  String? _selectedModel;
  String? _selectedVariant;
  HybridCarData? _carData;
  List<MaintenanceItem> _upcomingMaintenance = [];

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  @override
  void dispose() {
    _licensePlateController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    setState(() {
      _isLoading = true;
    });
    
    final brands = await _carService.getBrands();
    setState(() {
      _brands = brands;
      _isLoading = false;
    });
  }

  Future<void> _loadModels(String brand) async {
    setState(() {
      _isLoadingData = true;
    });
    
    final models = await _carService.getModels(brand);
    setState(() {
      _models = models;
      _selectedModel = null;
      _selectedVariant = null;
      _variants.clear();
      _carData = null;
      _upcomingMaintenance.clear();
      _isLoadingData = false;
    });
  }

  Future<void> _loadVariants(String brand, String model) async {
    setState(() {
      _isLoadingData = true;
    });
    
    final variants = await _carService.getVariants(brand, model);
    setState(() {
      _variants = variants;
      _selectedVariant = null;
      _carData = null;
      _upcomingMaintenance.clear();
      _isLoadingData = false;
    });
  }

  Future<void> _loadCarData(String brand, String model, String variant) async {
    setState(() {
      _isLoadingData = true;
    });
    
    final carData = await _carService.getCarData(brand, model, variant);
    setState(() {
      _carData = carData;
      _isLoadingData = false;
    });
    
    if (carData != null && _mileageController.text.isNotEmpty) {
      _calculateMaintenance();
    }
  }

  Future<void> _calculateMaintenance() async {
    if (_carData == null || _mileageController.text.isEmpty) return;
    
    final currentMileage = int.tryParse(_mileageController.text) ?? 0;
    final upcomingMaintenance = await _carService.calculateUpcomingMaintenance(
      _carData!,
      currentMileage,
    );
    
    setState(() {
      _upcomingMaintenance = upcomingMaintenance;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBrandSelector(),
                      const SizedBox(height: 16),
                      _buildModelSelector(),
                      const SizedBox(height: 16),
                      _buildVariantSelector(),
                      const SizedBox(height: 16),
                      if (_carData != null) _buildCarInfo(),
                      const SizedBox(height: 16),
                      _buildBasicFields(),
                      const SizedBox(height: 16),
                      if (_upcomingMaintenance.isNotEmpty) _buildMaintenancePreview(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.auto_fix_high,
          color: Theme.of(context).primaryColor,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Akıllı Araba Ekle',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'İnternetten araç bilgilerini çeker',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildBrandSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedBrand,
      decoration: InputDecoration(
        labelText: 'Marka *',
        prefixIcon: _isLoading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.business),
        border: const OutlineInputBorder(),
      ),
      items: _brands.map((brand) {
        return DropdownMenuItem(
          value: brand,
          child: Text(brand),
        );
      }).toList(),
      onChanged: _isLoading ? null : (value) {
        setState(() {
          _selectedBrand = value;
        });
        if (value != null) {
          _loadModels(value);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Marka seçimi zorunludur';
        }
        return null;
      },
    );
  }

  Widget _buildModelSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedModel,
      decoration: InputDecoration(
        labelText: 'Model *',
        prefixIcon: _isLoadingData 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.car_rental),
        border: const OutlineInputBorder(),
      ),
      items: _models.map((model) {
        return DropdownMenuItem(
          value: model,
          child: Text(model),
        );
      }).toList(),
      onChanged: _selectedBrand == null || _isLoadingData ? null : (value) {
        setState(() {
          _selectedModel = value;
        });
        if (value != null && _selectedBrand != null) {
          _loadVariants(_selectedBrand!, value);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Model seçimi zorunludur';
        }
        return null;
      },
    );
  }

  Widget _buildVariantSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedVariant,
      decoration: InputDecoration(
        labelText: 'Varyant',
        prefixIcon: _isLoadingData 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.tune),
        border: const OutlineInputBorder(),
        helperText: 'Motor ve donanım seviyesi',
      ),
      items: _variants.map((variant) {
        return DropdownMenuItem(
          value: variant,
          child: Text(variant),
        );
      }).toList(),
      onChanged: _selectedModel == null || _isLoadingData ? null : (value) {
        setState(() {
          _selectedVariant = value;
        });
        if (value != null && _selectedBrand != null && _selectedModel != null) {
          _loadCarData(_selectedBrand!, _selectedModel!, value);
        }
      },
    );
  }

  Widget _buildCarInfo() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Araç Bilgileri',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                _buildDataSourceChip(),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Motor', _carData!.engine),
            _buildInfoRow('Yakıt Türü', _carData!.fuelType),
            _buildInfoRow('Üretim Yılı', _carData!.yearRange),
            if (_carData!.transmission != 'Manuel') 
              _buildInfoRow('Şanzıman', _carData!.transmission),
            if (_carData!.drivetrain != 'FWD') 
              _buildInfoRow('Çekiş', _carData!.drivetrain),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSourceChip() {
    if (_carData == null) return const SizedBox.shrink();
    
    Color chipColor;
    IconData chipIcon;
    String chipLabel;
    
    switch (_carData!.source) {
      case 'local':
        chipColor = Colors.green;
        chipIcon = Icons.storage;
        chipLabel = 'Yerel';
        break;
      case 'api':
        chipColor = Colors.orange;
        chipIcon = Icons.cloud;
        chipLabel = 'API';
        break;
      default:
        chipColor = Colors.grey;
        chipIcon = Icons.help_outline;
        chipLabel = 'Varsayılan';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipIcon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            chipLabel,
            style: TextStyle(
              fontSize: 10,
              color: chipColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildBasicFields() {
    return Column(
      children: [
        // Plaka
        TextFormField(
          controller: _licensePlateController,
          decoration: const InputDecoration(
            labelText: 'Plaka',
            hintText: 'ör: 34 ABC 123 (isteğe bağlı)',
            prefixIcon: Icon(Icons.credit_card),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),
        
        // Yıl ve Renk yan yana
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: 'Model Yılı *',
                  hintText: 'ör: 2020',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Model yılı zorunludur';
                  }
                  final year = int.tryParse(value);
                  if (year == null) {
                    return 'Geçerli bir yıl giriniz';
                  }
                  final currentYear = DateTime.now().year;
                  if (year < 1900 || year > currentYear + 1) {
                    return 'Yıl 1900-${currentYear + 1} arasında olmalıdır';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: 'Renk',
                  hintText: 'ör: Beyaz',
                  prefixIcon: Icon(Icons.palette),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Kilometre
        TextFormField(
          controller: _mileageController,
          decoration: const InputDecoration(
            labelText: 'Kilometre',
            hintText: 'ör: 50000',
            prefixIcon: Icon(Icons.speed),
            border: OutlineInputBorder(),
            suffixText: 'km',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              final mileage = int.tryParse(value);
              if (mileage == null || mileage < 0) {
                return 'Geçerli bir kilometre değeri giriniz';
              }
            }
            return null;
          },
          onChanged: (value) {
            if (_carData != null && value.isNotEmpty) {
              _calculateMaintenance();
            }
          },
        ),
      ],
    );
  }

  Widget _buildMaintenancePreview() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Yaklaşan Bakımlar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _upcomingMaintenance.take(3).length,
              itemBuilder: (context, index) {
                final maintenance = _upcomingMaintenance[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: maintenance.isUrgent 
                              ? Colors.red 
                              : maintenance.isWarning 
                                  ? Colors.orange 
                                  : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${maintenance.description} - ${maintenance.remainingKm} km kaldı',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveCar,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
        ),
      ],
    );
  }

  Future<void> _saveCar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final car = Car(
        id: '',
        brand: _selectedBrand ?? '',
        model: _selectedModel ?? '',
        licensePlate: _licensePlateController.text.trim(),
        year: _yearController.text.trim(),
        color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
        mileage: _mileageController.text.trim().isEmpty 
            ? null 
            : int.parse(_mileageController.text.trim()),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repository = CarRepository();
      await repository.insertCar(car);

      if (mounted) {
        Navigator.pop(context);
        widget.onCarAdded?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${car.brand} ${car.model} eklendi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
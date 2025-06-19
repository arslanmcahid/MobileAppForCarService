import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/car.dart';
import '../../data/repositories/car_repository.dart';

class AddCarForm extends ConsumerStatefulWidget {
  final VoidCallback? onCarAdded;

  const AddCarForm({super.key, this.onCarAdded});

  @override
  ConsumerState<AddCarForm> createState() => _AddCarFormState();
}

class _AddCarFormState extends ConsumerState<AddCarForm> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _mileageController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _licensePlateController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Yeni Araba Ekle',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Marka
                      TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: 'Marka *',
                          hintText: 'ör: Toyota, BMW, Ford...',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Marka zorunludur';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      
                      // Model
                      TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model *',
                          hintText: 'ör: Corolla, 3 Series, Focus...',
                          prefixIcon: Icon(Icons.car_rental),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Model zorunludur';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      
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
                      
                      // Yıl
                      TextFormField(
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
                      const SizedBox(height: 16),
                      
                      // Renk (Opsiyonel)
                      TextFormField(
                        controller: _colorController,
                        decoration: const InputDecoration(
                          labelText: 'Renk',
                          hintText: 'ör: Beyaz, Siyah, Kırmızı...',
                          prefixIcon: Icon(Icons.palette),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      
                      // Kilometre (Opsiyonel)
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Butonlar
            Row(
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final car = Car(
        id: '', // ID'yi repository belirleyecek
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/add_car_form.dart';
import '../../widgets/smart_add_car_form.dart';
import '../../../data/models/car.dart';
import '../../../data/repositories/car_repository.dart';

// Provider'lar
final carRepositoryProvider = Provider((ref) => CarRepository());
final carsProvider = FutureProvider<List<Car>>((ref) async {
  final repository = ref.read(carRepositoryProvider);
  return await repository.getAllCars();
});

class CarsScreen extends ConsumerStatefulWidget {
  const CarsScreen({super.key});

  @override
  ConsumerState<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends ConsumerState<CarsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arabalarım'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCarDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchQuery.isNotEmpty) _buildSearchHeader(),
          Expanded(child: _buildCarsList()),
        ],
      ),
      bottomNavigationBar: const BottomNavigation(currentIndex: 1),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCarDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Row(
        children: [
          Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Arama: "$_searchQuery"',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCarsList() {
    final carsAsync = ref.watch(carsProvider);

    return carsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Hata oluştu',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(carsProvider),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
      data: (cars) {
        // Arama filtresi
        final filteredCars = _searchQuery.isEmpty
            ? cars
            : cars.where((car) =>
                car.brand.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                car.model.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                car.licensePlate.toLowerCase().contains(_searchQuery.toLowerCase()),
              ).toList();

        if (filteredCars.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.refresh(carsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredCars.length,
            itemBuilder: (context, index) {
              return _buildCarCard(filteredCars[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.directions_car_outlined : Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty 
                ? 'Henüz araba eklenmemiş'
                : 'Arama sonucu bulunamadı',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'İlk arabanızı eklemek için + butonuna tıklayın'
                : '"$_searchQuery" için sonuç bulunamadı',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () => _showAddCarDialog(),
              icon: const Icon(Icons.add),
              label: const Text('İlk Araba Ekle'),
            ),
        ],
      ),
    );
  }

  Widget _buildCarCard(Car car) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/cars/detail/${car.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${car.brand} ${car.model}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          car.licensePlate,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleCarAction(value, car),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'detail',
                        child: ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('Detaylar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Düzenle'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Sil', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(Icons.calendar_today, car.year),
                  const SizedBox(width: 8),
                  if (car.color != null)
                    _buildInfoChip(Icons.palette, car.color!),
                  const SizedBox(width: 8),
                  if (car.mileage != null)
                    _buildInfoChip(Icons.speed, '${car.mileage} km'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Araba Ara'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Marka, model veya plaka...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = _searchController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Ara'),
          ),
        ],
      ),
    );
  }

  void _showAddCarDialog() {
    showDialog(
      context: context,
      builder: (context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Önce form seçim dialogu göster
          AlertDialog(
            title: const Text('Araba Ekleme Türü'),
            content: const Text('Nasıl araba eklemek istersiniz?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Normal form
                  showDialog(
                    context: context,
                    builder: (context) => AddCarForm(
                      onCarAdded: () => ref.refresh(carsProvider),
                    ),
                  );
                },
                child: const Text('Manuel Giriş'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Akıllı form
                  showDialog(
                    context: context,
                    builder: (context) => SmartAddCarForm(
                      onCarAdded: () => ref.refresh(carsProvider),
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_fix_high, size: 16),
                    SizedBox(width: 4),
                    Text('Akıllı Ekleme'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleCarAction(String action, Car car) {
    switch (action) {
      case 'detail':
        context.push('/cars/detail/${car.id}');
        break;
      case 'edit':
        _showEditCarDialog(car);
        break;
      case 'delete':
        _showDeleteCarDialog(car);
        break;
    }
  }

  void _showEditCarDialog(Car car) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arabayı Düzenle'),
        content: Text('${car.brand} ${car.model} düzenleme formu yakında...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCarDialog(Car car) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arabayı Sil'),
        content: Text('${car.brand} ${car.model} arabasını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final repository = ref.read(carRepositoryProvider);
              await repository.deleteCar(car.id);
              ref.refresh(carsProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${car.brand} ${car.model} silindi'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
} 
# Araba Bakım Takibi

Arabanızın bakım işlemlerini takip etmenizi sağlayan modern bir mobil uygulama.

## Özellikler

- 🚗 **Araba Yönetimi**: Birden fazla arabanızı kaydedin ve yönetin
- 🔧 **Bakım Takibi**: Yapılan bakımları kaydedin ve takip edin
- ⏰ **Hatırlatmalar**: Yaklaşan bakım zamanları için bildirimler alın
- 📊 **Raporlar**: Bakım masraflarınızı analiz edin
- 📱 **Modern UI**: Kullanıcı dostu ve modern arayüz

## Teknolojiler

- **Flutter**: Cross-platform mobil uygulama geliştirme
- **Dart**: Programlama dili
- **SQLite**: Yerel veritabanı
- **Riverpod**: State management
- **Go Router**: Navigasyon
- **Material Design 3**: Modern UI tasarımı

## Proje Yapısı

```
lib/
├── config/                 # Uygulama konfigürasyonu
│   ├── app_config.dart
│   ├── router.dart
│   └── theme.dart
├── data/                   # Veri katmanı
│   ├── database/
│   │   └── database_helper.dart
│   ├── models/
│   │   ├── car.dart
│   │   └── maintenance.dart
│   └── repositories/
│       ├── car_repository.dart
│       └── maintenance_repository.dart
├── presentation/           # UI katmanı
│   ├── screens/
│   │   ├── cars/
│   │   ├── maintenance/
│   │   ├── settings/
│   │   ├── onboarding/
│   │   └── home_screen.dart
│   └── widgets/
│       └── bottom_navigation.dart
└── main.dart              # Ana uygulama dosyası
```

## Kurulum

1. Flutter SDK'yı yükleyin: [Flutter Kurulum](https://flutter.dev/docs/get-started/install)

2. Projeyi klonlayın:

```bash
git clone <repository-url>
cd car_maintenance_tracker
```

3. Bağımlılıkları yükleyin:

```bash
flutter pub get
```

4. Uygulamayı çalıştırın:

```bash
flutter run
```

## Geliştirme

### Yeni Özellik Ekleme

1. Model oluşturun (`lib/data/models/`)
2. Repository ekleyin (`lib/data/repositories/`)
3. UI ekranını oluşturun (`lib/presentation/screens/`)
4. Router'a ekleyin (`lib/config/router.dart`)

### Veritabanı Güncellemeleri

Veritabanı şemasını güncellemek için `database_helper.dart` dosyasındaki `_onUpgrade` metodunu kullanın.

## Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Commit yapın (`git commit -m 'Add some amazing feature'`)
4. Push yapın (`git push origin feature/amazing-feature`)
5. Pull Request oluşturun

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

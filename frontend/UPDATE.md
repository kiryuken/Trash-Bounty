# UPDATE.md — Frontend Flutter Implementation

## Overview

Implementasi aplikasi mobile **TrashBounty AI** menggunakan Flutter, dikonversi dari prototipe React/Vite yang sudah ada. Aplikasi ini terintegrasi dengan backend Go melalui REST API dengan autentikasi JWT.

## Tech Stack

| Komponen | Teknologi |
|---|---|
| Framework | Flutter 3.11.5 / Dart 3.3 |
| State Management | Riverpod 2.6.1 (`flutter_riverpod`) |
| Routing | GoRouter 14.8.1 (declarative) |
| HTTP Client | Dio 5.9.2 (JWT interceptor + auto-refresh) |
| Secure Storage | flutter_secure_storage 9.2.4 |
| Icons | lucide_icons 0.257.0 |
| Charts | fl_chart 0.70.2 |
| Typography | google_fonts 6.3.3 (Inter) |
| Image Picker | image_picker 1.2.1 |
| Geolocation | geolocator 13.0.4 |
| Platform | Android only |

## Struktur Folder

```
frontend/lib/
├── main.dart                          # Entry point (ProviderScope + MaterialApp.router)
├── core/
│   ├── network/
│   │   ├── api_endpoints.dart         # Semua endpoint API (auth, reports, bounties, dll)
│   │   ├── dio_client.dart            # Dio provider + JWT interceptor + auto token refresh
│   │   └── secure_storage_service.dart # FlutterSecureStorage wrapper untuk JWT tokens
│   ├── providers/
│   │   └── auth_provider.dart         # StateNotifierProvider (login, register, logout, autoLogin)
│   ├── router/
│   │   └── app_router.dart            # GoRouter config (splash → login/signup → ShellRoute)
│   ├── theme/
│   │   ├── app_colors.dart            # Sistem warna (green, emerald, amber, red, blue, dll)
│   │   ├── app_text_styles.dart       # Typography dengan Google Fonts Inter
│   │   └── app_theme.dart             # Material 3 ThemeData lengkap
│   └── widgets/
│       ├── app_badge.dart             # Badge severity & status (factory constructors)
│       ├── gradient_header.dart       # Reusable green gradient header
│       └── main_scaffold.dart         # BottomNavigationBar shell (5 tabs, role-dependent)
├── data/
│   └── models/
│       └── models.dart                # Semua DTO (User, Report, Bounty, Leaderboard, dll)
└── features/
    ├── auth/
    │   ├── splash_screen.dart         # Animated splash + auto-login check
    │   ├── login_page.dart            # 2-step: role selection → email/password
    │   └── signup_page.dart           # 2-step: role selection → name/email/password
    ├── home/
    │   └── home_page.dart             # Dashboard (stats grid, wallet, recent reports/bounties)
    ├── report/
    │   └── report_page.dart           # 3-stage flow: upload → AI analysis → result
    ├── bounty/
    │   └── bounty_page.dart           # List bounty + detail bottom sheet + ambil bounty
    ├── leaderboard/
    │   └── leaderboard_page.dart      # Weekly/monthly/alltime tabs, podium top 3
    ├── history/
    │   └── history_page.dart          # Riwayat aktivitas + stats summary
    └── profile/
        ├── profile_page.dart          # Profil user + achievements + menu navigasi
        ├── privacy_page.dart          # Toggle pengaturan privasi
        └── help_support_page.dart     # FAQ expandable + contact support
```

## Fitur Utama

### 1. Autentikasi
- Login & register 2-step (pilih role → isi form)
- JWT token disimpan di FlutterSecureStorage
- Auto-refresh token saat 401
- Auto-login dari splash screen

### 2. Dashboard (Home)
- Green gradient header dengan avatar & notifikasi
- Grid statistik (total laporan, poin, ranking)
- Wallet card dengan saldo
- Laporan terbaru (reporter) / bounty tersedia (executor)
- Pull-to-refresh

### 3. Pelaporan Sampah
- Ambil foto via kamera atau galeri (image_picker)
- Ambil lokasi GPS otomatis (geolocator)
- Upload multipart ke API
- Tampilan hasil analisis AI (severity, jenis, estimasi reward)
- 3 tahap UI: upload → analyzing → result

### 4. Bounty System
- Daftar bounty dengan search & filter
- Detail bounty dalam bottom sheet
- Aksi "Ambil Bounty" untuk eksekutor

### 5. Leaderboard
- Tab mingguan / bulanan / semua waktu
- Podium visual untuk top 3
- Highlight user saat ini dalam daftar

### 6. Profil & Pengaturan
- Profil dengan avatar, stats, achievements
- Riwayat aktivitas
- Pengaturan privasi (toggle switches)
- Halaman bantuan (FAQ expandable)

## Koneksi API

Base URL: `http://10.0.2.2:8080/v1` (Android emulator → localhost)

Semua request otomatis menyertakan header `Authorization: Bearer <token>` melalui Dio interceptor. Token refresh dilakukan otomatis saat mendapat response 401.

## Cara Menjalankan

```bash
cd frontend
flutter pub get
flutter run
```

Untuk build APK:
```bash
flutter build apk --debug
```

## File yang Dibuat/Dimodifikasi

| File | Aksi |
|---|---|
| `pubspec.yaml` | Dimodifikasi — ditambahkan 15+ dependencies |
| `lib/main.dart` | Dimodifikasi — ProviderScope + MaterialApp.router |
| `lib/core/theme/app_colors.dart` | Baru — sistem warna |
| `lib/core/theme/app_text_styles.dart` | Baru — typography |
| `lib/core/theme/app_theme.dart` | Baru — Material 3 theme |
| `lib/core/network/api_endpoints.dart` | Baru — endpoint constants |
| `lib/core/network/secure_storage_service.dart` | Baru — token storage |
| `lib/core/network/dio_client.dart` | Baru — HTTP client + interceptor |
| `lib/data/models/models.dart` | Baru — semua data models |
| `lib/core/providers/auth_provider.dart` | Baru — auth state management |
| `lib/core/router/app_router.dart` | Baru — routing configuration |
| `lib/core/widgets/main_scaffold.dart` | Baru — bottom nav shell |
| `lib/core/widgets/gradient_header.dart` | Baru — reusable header |
| `lib/core/widgets/app_badge.dart` | Baru — severity/status badges |
| `lib/features/auth/splash_screen.dart` | Baru — splash screen |
| `lib/features/auth/login_page.dart` | Baru — login page |
| `lib/features/auth/signup_page.dart` | Baru — signup page |
| `lib/features/home/home_page.dart` | Baru — home dashboard |
| `lib/features/report/report_page.dart` | Baru — report submission |
| `lib/features/bounty/bounty_page.dart` | Baru — bounty list |
| `lib/features/leaderboard/leaderboard_page.dart` | Baru — leaderboard |
| `lib/features/profile/profile_page.dart` | Baru — profile page |
| `lib/features/history/history_page.dart` | Baru — history page |
| `lib/features/profile/privacy_page.dart` | Baru — privacy settings |
| `lib/features/profile/help_support_page.dart` | Baru — help & FAQ |
| `test/widget_test.dart` | Dimodifikasi — smoke test |

**Total: 24 file Dart baru, 2 file dimodifikasi**

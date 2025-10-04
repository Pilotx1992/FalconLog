# FalconLog - دليل العمل في الوضع Offline

## نظرة عامة

FalconLog مصمم ليعمل **Offline First**، مما يعني أن التطبيق يعمل بشكل كامل حتى بدون اتصال بالإنترنت. هذا الدليل يشرح بالتفصيل كيفية عمل التطبيق في الوضع Offline.

## جدول المحتويات

1. [الهيكل العام للتطبيق](#الهيكل-العام-للتطبيق)
2. [Firebase Authentication - التخزين المحلي](#firebase-authentication---التخزين-المحلي)
3. [Hive Database - قاعدة البيانات المحلية](#hive-database---قاعدة-البيانات-المحلية)
4. [تدفق العمل الكامل](#تدفق-العمل-الكامل)
5. [Google Drive Backup - منفصل تماماً](#google-drive-backup---منفصل-تماماً)
6. [مثال عملي - سيناريو كامل](#مثال-عملي---سيناريو-كامل)
7. [البيانات المخزنة محلياً](#البيانات-المخزنة-محلياً)
8. [مقارنة بين الوضعين](#مقارنة-بين-الوضعين)
9. [الأمان والحماية](#الأمان-والحماية)
10. [الخلاصة](#الخلاصة)

---

## الهيكل العام للتطبيق

```
FalconLog App
├── Firebase Authentication (تسجيل الدخول)
├── Hive Database (البيانات المحلية)
├── Google Drive Backup (النسخ الاحتياطي)
└── UI Components (واجهة المستخدم)
```

### المكونات الرئيسية:

- **Firebase Auth**: يدير تسجيل الدخول ويحفظ الحالة محلياً
- **Hive Database**: قاعدة بيانات محلية سريعة للرحلات
- **Google Drive Service**: خدمة النسخ الاحتياطي (اختيارية)
- **Encryption Service**: تشفير البيانات الحساسة

---

## Firebase Authentication - التخزين المحلي

### كيف يعمل:

```dart
// في main.dart
FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user == null) {
    debugPrint('User is currently signed out.');
  } else {
    debugPrint('User is signed in.');
  }
});
```

### الميزات الرئيسية:

- **Persistence تلقائي**: Firebase يحفظ حالة تسجيل الدخول محلياً
- **Offline Detection**: يتحقق من الحالة المحلية بدون إنترنت
- **Token Management**: يدير الـ tokens تلقائياً
- **Auto Sign-in**: يعيد تسجيل الدخول تلقائياً عند فتح التطبيق

### التخزين المحلي:

| النظام | المسار |
|--------|--------|
| **Android** | `/data/data/com.falcon_log.falconlog/shared_prefs/` |
| **iOS** | `Keychain Services` |

### AuthWrapper Logic:

```dart
class AuthWrapper extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return authState.when(
      data: (user) {
        if (user != null) {
          // المستخدم مسجل دخول → Dashboard مباشرة
          return const DashboardScreen();
        } else {
          // المستخدم غير مسجل دخول → Login Screen
          return const LoginScreen();
        }
      },
      loading: () => _buildLoadingScreen(),
      error: (error, stack) => _buildErrorScreen(error, ref),
    );
  }
}
```

---

## Hive Database - قاعدة البيانات المحلية

### كيف تعمل:

```dart
// في flight_logs_provider.dart
class FlightLogsNotifier extends StateNotifier<AsyncValue<List<FlightLog>>> {
  static const String boxName = 'flightLogsBox';
  Box<FlightLog>? _box;

  Future<void> _init() async {
    _box = await HiveInitializationService.openBox<FlightLog>(boxName);
    _updateState();
  }

  void _updateState() {
    final logs = _box?.values.toList() ?? [];
    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncValue.data(logs);
  }
}
```

### الميزات الرئيسية:

- **NoSQL Database**: قاعدة بيانات محلية سريعة
- **Type Safety**: دعم كامل للـ Dart types
- **Encryption**: تشفير البيانات (اختياري)
- **Offline First**: تعمل بدون إنترنت
- **ACID Compliance**: ضمان سلامة البيانات

### التخزين:

| النظام | المسار |
|--------|--------|
| **Android** | `/data/data/com.falcon_log.falconlog/app_flutter/` |
| **iOS** | `Documents Directory` |

### FlightLog Model:

```dart
@HiveType(typeId: 2)
class FlightLog extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String aircraftType;
  
  @HiveField(2)
  DateTime departureTime;
  
  @HiveField(3)
  DateTime arrivalTime;
  
  @HiveField(4)
  String departureAirport;
  
  @HiveField(5)
  String arrivalAirport;
  
  @HiveField(6)
  double flightHours;
  
  @HiveField(7)
  String pilotRole;
  
  @HiveField(8)
  String? notes;
  
  @HiveField(9)
  DateTime createdAt;
  
  @HiveField(10)
  DateTime updatedAt;
}
```

---

## تدفق العمل الكامل

### عند فتح التطبيق:

```
1. Splash Screen (4 ثواني)
   ↓
2. Firebase Auth Check
   ├── إذا كان مسجل دخول → Dashboard مباشرة ✅
   └── إذا لم يكن مسجل دخول → Login Screen ❌
   ↓
3. Hive Database Load
   ├── تحميل البيانات المحلية
   └── عرض الرحلات في Dashboard
```

### في حالة عدم وجود إنترنت:

```
بدون إنترنت:
├── Firebase Auth: يتحقق من الحالة المحلية ✅
├── Hive Database: يعمل بشكل طبيعي ✅
├── Google Drive: غير متاح ❌
└── التطبيق: يعمل بشكل كامل ✅
```

### في حالة وجود إنترنت:

```
مع إنترنت:
├── Firebase Auth: يتحقق من الحالة المحلية ✅
├── Hive Database: يعمل بشكل طبيعي ✅
├── Google Drive: متاح للنسخ الاحتياطي ✅
└── التطبيق: يعمل بشكل كامل + Backup ✅
```

---

## Google Drive Backup - منفصل تماماً

### كيف يعمل:

```dart
// في backup_service.dart
class BackupService {
  final GoogleDriveService _driveService;
  final EncryptionService _encryptionService;
  
  Future<void> createBackup() async {
    // 1. إنشاء نسخة من البيانات المحلية
    final backupData = await _createBackupData();
    
    // 2. تشفير البيانات
    final encryptedData = await _encryptionService.encrypt(backupData);
    
    // 3. رفع إلى Google Drive
    await _driveService.uploadBackup(encryptedData);
  }
}
```

### الميزات الرئيسية:

- **منفصل عن Firebase**: نظام مستقل تماماً
- **اختياري**: يمكن استخدام التطبيق بدونه
- **تشفير**: AES-256-GCM
- **تلقائي**: يمكن جدولة النسخ الاحتياطي
- **تشفير عسكري**: حماية البيانات الحساسة

### DriveAuthService:

```dart
class DriveAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  Future<Map<String, String>> getAuthHeaders({
    bool interactive = true,
    bool attemptSilent = true,
  }) async {
    // الحصول على headers للمصادقة
  }
}
```

---

## مثال عملي - سيناريو كامل

### المستخدم يفتح التطبيق بدون إنترنت:

```dart
// 1. التطبيق يبدأ
main() async {
  await Firebase.initializeApp();
  // Firebase يحفظ الحالة محلياً
}

// 2. AuthWrapper يتحقق من الحالة
class AuthWrapper extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return authState.when(
      data: (user) {
        if (user != null) {
          // المستخدم مسجل دخول → Dashboard مباشرة
          return const DashboardScreen();
        } else {
          // المستخدم غير مسجل دخول → Login Screen
          return const LoginScreen();
        }
      },
    );
  }
}

// 3. Dashboard يحمل البيانات المحلية
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightLogs = ref.watch(flightLogsProvider);
    
    return flightLogs.when(
      data: (logs) {
        // عرض الرحلات من Hive Database
        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) => FlightCard(logs[index]),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### إضافة رحلة جديدة (Offline):

```dart
// في log_flight_screen.dart
Future<void> _saveFlight() async {
  final flightLog = FlightLog(
    id: const Uuid().v4(),
    aircraftType: _aircraftController.text,
    departureTime: _departureTime,
    arrivalTime: _arrivalTime,
    departureAirport: _departureController.text,
    arrivalAirport: _arrivalController.text,
    flightHours: _calculateFlightHours(),
    pilotRole: _selectedRole,
    notes: _notesController.text,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  // حفظ في Hive Database (محلي)
  await ref.read(flightLogsProvider.notifier).addFlightLog(flightLog);
  
  // عرض رسالة نجاح
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Flight logged successfully!')),
  );
}
```

---

## البيانات المخزنة محلياً

### Firebase Auth Data:

```json
{
  "user_id": "abc123",
  "email": "user@example.com",
  "display_name": "User Name",
  "photo_url": "https://...",
  "access_token": "encrypted_token",
  "refresh_token": "encrypted_refresh_token",
  "expires_at": "2024-01-01T00:00:00Z",
  "is_anonymous": false,
  "email_verified": true,
  "creation_time": "2024-01-01T00:00:00Z",
  "last_sign_in_time": "2024-01-01T00:00:00Z"
}
```

### Hive Database Structure:

```
flightLogsBox/
├── flight_001.hive
├── flight_002.hive
├── flight_003.hive
└── ...

backupMetadata/
├── backup_001.metadata
├── backup_002.metadata
└── ...
```

### SharedPreferences:

```json
{
  "prefer_google_signin": true,
  "google_email": "user@example.com",
  "biometric_email": "encrypted_email",
  "biometric_password": "encrypted_password",
  "backup_frequency": "daily",
  "wifi_only_backup": true,
  "last_backup_time": "2024-01-01T00:00:00Z"
}
```

---

## مقارنة بين الوضعين

| الميزة | مع إنترنت | بدون إنترنت |
|--------|-----------|-------------|
| **تسجيل الدخول** | ✅ يعمل | ✅ يعمل (من الحالة المحلية) |
| **عرض الرحلات** | ✅ يعمل | ✅ يعمل (من Hive) |
| **إضافة رحلة** | ✅ يعمل | ✅ يعمل (حفظ محلي) |
| **تعديل رحلة** | ✅ يعمل | ✅ يعمل (تحديث محلي) |
| **حذف رحلة** | ✅ يعمل | ✅ يعمل (حذف محلي) |
| **البحث في الرحلات** | ✅ يعمل | ✅ يعمل (بحث محلي) |
| **الفلترة والترتيب** | ✅ يعمل | ✅ يعمل (محلي) |
| **الإحصائيات** | ✅ يعمل | ✅ يعمل (محسوبة محلياً) |
| **Backup** | ✅ يعمل | ❌ لا يعمل |
| **Restore** | ✅ يعمل | ❌ لا يعمل |
| **Google Drive** | ✅ يعمل | ❌ لا يعمل |
| **تحديث التطبيق** | ✅ يعمل | ❌ لا يعمل |

### الميزات المتاحة Offline:

- ✅ **إدارة الرحلات الكاملة**
- ✅ **البحث والفلترة**
- ✅ **الإحصائيات والتقارير**
- ✅ **تصدير البيانات**
- ✅ **الإعدادات المحلية**
- ✅ **الواجهة الكاملة**

### الميزات التي تحتاج إنترنت:

- ❌ **النسخ الاحتياطي**
- ❌ **استعادة البيانات**
- ❌ **مزامنة البيانات**
- ❌ **تحديث التطبيق**
- ❌ **تسجيل دخول جديد**

---

## الأمان والحماية

### تشفير البيانات:

```dart
// في encryption_service.dart
class EncryptionService {
  static const String _algorithm = 'AES-256-GCM';
  static const int _keyLength = 32;
  static const int _nonceLength = 12;
  static const int _iterations = 100000;
  
  Future<Uint8List> encrypt(Uint8List data) async {
    final key = await _getOrCreateMasterKey();
    final nonce = _generateNonce();
    
    final cipher = AesGcm.with256bits();
    final secretKey = SecretKey(key);
    
    final encrypted = await cipher.encrypt(
      data,
      secretKey: secretKey,
      nonce: nonce,
    );
    
    return _combineNonceAndData(nonce, encrypted);
  }
}
```

### حماية المفاتيح:

```dart
// في key_manager.dart
class KeyManagerNew {
  static const String _keyStorageKey = 'master_key';
  static const String _keyChecksumKey = 'master_key_checksum';
  
  Future<String> getMasterKey() async {
    // استرجاع المفتاح من FlutterSecureStorage
    final key = await _secureStorage.read(key: _keyStorageKey);
    if (key == null) {
      throw Exception('Master key not found');
    }
    
    // التحقق من سلامة المفتاح
    await _validateKeyIntegrity(key);
    
    return key;
  }
  
  Future<void> _validateKeyIntegrity(String key) async {
    final storedChecksum = await _secureStorage.read(key: _keyChecksumKey);
    final calculatedChecksum = _calculateChecksum(key);
    
    if (storedChecksum != calculatedChecksum) {
      throw Exception('Key integrity check failed');
    }
  }
}
```

### معايير الأمان:

| المعيار | التطبيق |
|---------|---------|
| **تشفير البيانات** | AES-256-GCM |
| **اشتقاق المفاتيح** | PBKDF2 (100,000 iterations) |
| **تخزين المفاتيح** | FlutterSecureStorage |
| **حماية البيانات** | Android Keystore / iOS Keychain |
| **التحقق من السلامة** | HMAC-SHA256 |
| **إدارة الجلسات** | Firebase Auth |
| **حماية الشبكة** | TLS 1.3 |

---

## الخلاصة

FalconLog مصمم ليعمل **Offline First** مع التركيز على:

### المزايا الرئيسية:

1. **البيانات المحلية**: مخزنة في Hive Database
2. **تسجيل الدخول**: محفوظ محلياً بواسطة Firebase
3. **النسخ الاحتياطي**: اختياري ويتطلب إنترنت
4. **الأمان**: تشفير عسكري للبيانات الحساسة
5. **الأداء**: سريع ومستجيب حتى بدون إنترنت

### التصميم الذكي:

- **Offline First**: يعمل بدون إنترنت
- **Progressive Enhancement**: ميزات إضافية مع الإنترنت
- **Data Persistence**: حفظ البيانات محلياً
- **Security First**: تشفير وحماية البيانات
- **User Experience**: تجربة سلسة ومتسقة

### الاستخدام العملي:

```
الطيار في الطائرة (بدون إنترنت):
├── يمكنه تسجيل الرحلات ✅
├── يمكنه مراجعة الإحصائيات ✅
├── يمكنه البحث في الرحلات ✅
└── يمكنه استخدام التطبيق بشكل كامل ✅

الطيار في المكتب (مع إنترنت):
├── جميع الميزات السابقة ✅
├── النسخ الاحتياطي التلقائي ✅
├── استعادة البيانات ✅
└── مزامنة البيانات ✅
```

هذا التصميم يضمن أن المستخدم يمكنه استخدام التطبيق بشكل كامل حتى في المناطق التي لا يوجد فيها إنترنت، مع إمكانية الاستفادة من الميزات الإضافية عند توفر الاتصال! 🚀

---

## المراجع

- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Hive Database Documentation](https://docs.hivedb.dev/)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [Google Drive API](https://developers.google.com/drive/api)
- [AES-256-GCM Encryption](https://en.wikipedia.org/wiki/Galois/Counter_Mode)

---

*تم إنشاء هذا الدليل لشرح كيفية عمل FalconLog في الوضع Offline. للتحديثات والمزيد من المعلومات، يرجى مراجعة الوثائق الرسمية.*



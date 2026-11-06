import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final notifications = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  try {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  } catch (_) {
    tz.setLocalLocation(tz.UTC);
  }
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(const InitializationSettings(android: android));
  runApp(const EyeBreakApp());
}

Future<void> scheduleReminders() async {
  final android = notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.requestNotificationsPermission();
  await notifications.cancelAll();
  final start = tz.TZDateTime.now(tz.local);
  const look = AndroidNotificationDetails('look_away', 'استراحة العين', channelDescription: 'تذكير كل 20 دقيقة', importance: Importance.high, priority: Priority.high);
  final done = AndroidNotificationDetails('look_done', 'نهاية استراحة العين', channelDescription: 'تنبيه اهتزاز بعد 20 ثانية', importance: Importance.high, priority: Priority.high, enableVibration: true, vibrationPattern: Int64List.fromList([0, 500, 250, 500]));
  const rest = AndroidNotificationDetails('phone_rest', 'استراحة من الهاتف', channelDescription: 'تذكير كل ساعة', importance: Importance.high, priority: Priority.high);
  for (var i = 1; i <= 72; i++) {
    final at = start.add(Duration(minutes: 20 * i));
    await notifications.zonedSchedule(1000 + i, 'ارح عيونك 👀', 'انظر إلى شيء بعيد لمدة 20 ثانية', at, const NotificationDetails(android: look), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
    await notifications.zonedSchedule(2000 + i, 'انتهت الـ20 ثانية 📳', 'يمكنك الرجوع للشاشة الآن', at.add(const Duration(seconds: 20)), NotificationDetails(android: done), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
  }
  for (var i = 1; i <= 24; i++) {
    await notifications.zonedSchedule(3000 + i, 'استراحة من الهاتف 📵', 'اترك الشاشة 5–10 دقائق', start.add(Duration(hours: i)), const NotificationDetails(android: rest), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
  }
}

class EyeBreakApp extends StatefulWidget {
  const EyeBreakApp({super.key});
  @override
  State<EyeBreakApp> createState() => _EyeBreakAppState();
}

class _EyeBreakAppState extends State<EyeBreakApp> {
  bool enabled = false;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => enabled = prefs.getBool('enabled') ?? false);
    if (enabled) await scheduleReminders();
  }
  Future<void> _toggle(bool value) async {
    setState(() => busy = true);
    try {
      if (value) {
        await scheduleReminders();
      } else {
        await notifications.cancelAll();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enabled', value);
      if (mounted) setState(() => enabled = value);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
    home: Scaffold(
      appBar: AppBar(title: const Text('راحة العين')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.visibility_outlined, size: 84, color: Colors.tealAccent),
          const SizedBox(height: 24),
          const Text('خلّي عيونك ترتاح', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 28),
          const Card(child: ListTile(leading: Icon(Icons.remove_red_eye_outlined), title: Text('كل 20 دقيقة'), subtitle: Text('انظر بعيدًا 20 ثانية، ثم اهتزاز للتنبيه'))),
          const Card(child: ListTile(leading: Icon(Icons.phone_android_outlined), title: Text('كل ساعة'), subtitle: Text('اترك الهاتف 5–10 دقائق'))),
          const SizedBox(height: 20),
          SwitchListTile(title: const Text('تشغيل التذكيرات'), subtitle: Text(enabled ? 'مفعّلة' : 'متوقفة'), value: enabled, onChanged: busy ? null : _toggle),
          const SizedBox(height: 12),
          const Text('افتح التطبيق مرة يوميًا لتجديد التذكيرات. قد يؤخر أندرويد الإشعارات قليلًا.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
        ]),
      ),
    ),
  );
}

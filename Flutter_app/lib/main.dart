import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    name: 'smart-irrigation',
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ThemeSwitcherApp());
}

class ThemeSwitcherApp extends StatefulWidget {
  const ThemeSwitcherApp({super.key});

  @override
  State<ThemeSwitcherApp> createState() => _ThemeSwitcherAppState();
}

class _ThemeSwitcherAppState extends State<ThemeSwitcherApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Irrigation Dashboard',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[100],
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.green),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black)),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.grey[900],
        appBarTheme: const AppBarTheme(backgroundColor: Colors.green),
      ),
      home: DashboardScreen(toggleTheme: _toggleTheme, themeMode: _themeMode),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;
  const DashboardScreen({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseReference db = FirebaseDatabase.instance.ref();

  double temperature = 0;
  double humidity = 0;
  int soilMoisture = 0;
  int waterLevel = 0;
  bool relayOn = false;
  bool autoMode = true;

  @override
  void initState() {
    super.initState();
    _setupFirebaseListeners();
  }

  void _setupFirebaseListeners() {
    db.child('sensors/temperature').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null)
        setState(() => temperature = double.tryParse(val.toString()) ?? 0);
    });

    db.child('sensors/humidity').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null)
        setState(() => humidity = double.tryParse(val.toString()) ?? 0);
    });

    db.child('sensors/soilMoisture').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null)
        setState(() => soilMoisture = int.tryParse(val.toString()) ?? 0);
    });

    db.child('sensors/waterLevel').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null)
        setState(() => waterLevel = int.tryParse(val.toString()) ?? 0);
    });

    db.child('pumpStatus').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null) setState(() => relayOn = val == true);
    });

    db.child('controls/autoMode').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null) setState(() => autoMode = val == true);
    });
  }

  void toggleRelay() async {
    try {
      await db.child('controls/autoMode').set(false);
      await db.child('controls/manualPump').set(!relayOn);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to toggle pump: $e')));
      }
    }
  }

  void toggleAutoMode() async {
    try {
      await db.child('controls/autoMode').set(!autoMode);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle auto mode: $e')),
        );
      }
    }
  }

  Widget buildAnimatedProgressCard(
    String title,
    double value,
    String unit,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: value),
              duration: const Duration(milliseconds: 800),
              builder:
                  (context, val, _) => CustomPaint(
                    foregroundPainter: CircleProgressPainter(val, color),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Center(
                        child: Text(
                          "${val.toInt()}$unit",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
            ),
            const SizedBox(width: 20),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 20))),
          ],
        ),
      ),
    );
  }

  Widget buildPumpButton() {
    return GestureDetector(
      onTap: toggleRelay,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                relayOn
                    ? [Colors.red, Colors.deepOrange]
                    : [Colors.green, Colors.lightGreen],
          ),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color:
                  relayOn
                      ? Colors.redAccent.withOpacity(0.4)
                      : Colors.greenAccent.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(relayOn ? Icons.power_off : Icons.power, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              relayOn ? "Turn OFF Pump" : "Turn ON Pump",
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Irrigation Dashboard'),
        actions: [
          IconButton(
            icon: Icon(autoMode ? Icons.autorenew : Icons.handyman),
            onPressed: toggleAutoMode,
            tooltip: autoMode ? 'Auto Mode' : 'Manual Mode',
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: ListView(
        children: [
          buildAnimatedProgressCard(
            "Temperature",
            temperature,
            "°C",
            Colors.orange,
          ),
          buildAnimatedProgressCard("Humidity", humidity, "%", Colors.blue),
          buildAnimatedProgressCard(
            "Soil Moisture",
            soilMoisture.toDouble(),
            "%",
            Colors.green,
          ),
          buildAnimatedProgressCard(
            "Water Level",
            waterLevel.toDouble(),
            "%",
            Colors.teal,
          ),
          const SizedBox(height: 30),
          Center(child: buildPumpButton()),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class CircleProgressPainter extends CustomPainter {
  final double value;
  final Color color;

  CircleProgressPainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    double percentage = value.clamp(0, 100) / 100;
    double strokeWidth = 6;
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = (size.width - strokeWidth) / 2;

    Paint base =
        Paint()
          ..strokeWidth = strokeWidth
          ..color = Colors.grey.shade800
          ..style = PaintingStyle.stroke;

    Paint complete =
        Paint()
          ..strokeWidth = strokeWidth
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, base);
    double sweepAngle = 2 * pi * percentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      complete,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

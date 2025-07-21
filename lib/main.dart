import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // เตรียมข้อมูลสำหรับภาษาและ Widget
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th', null);
  runApp(const FoodBudgetApp());
}

class FoodBudgetApp extends StatefulWidget {
  const FoodBudgetApp({super.key});

  @override
  State<FoodBudgetApp> createState() => _FoodBudgetAppState();
}

class _FoodBudgetAppState extends State<FoodBudgetApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  // โหลดธีมที่บันทึกไว้
  void _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('themeMode');
    if (theme == 'dark') {
      setState(() => _themeMode = ThemeMode.dark);
    } else if (theme == 'light') {
      setState(() => _themeMode = ThemeMode.light);
    }
  }

  // สลับและบันทึกธีม
  void _toggleTheme(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
    await prefs.setString('themeMode', isDarkMode ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF673AB7);

    return MaterialApp(
      title: 'Budgit',
      debugShowCheckedModeBanner: false,
      // --- ธีมโหมดสว่าง ---
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.promptTextTheme(
          ThemeData.light().textTheme,
        ).apply(bodyColor: Colors.grey[800]),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
      ),
      // --- ธีมโหมดมืด ---
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
        ),
        textTheme: GoogleFonts.promptTextTheme(ThemeData.dark().textTheme)
            .apply(
              bodyColor: Colors.white.withOpacity(0.87),
              displayColor: Colors.white.withOpacity(0.87),
            ),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121212)),
        listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      themeMode: _themeMode,
      home: MealCalculatorScreen(onThemeChanged: _toggleTheme),
    );
  }
}

class MealCalculatorScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const MealCalculatorScreen({super.key, required this.onThemeChanged});

  @override
  State<MealCalculatorScreen> createState() => _MealCalculatorScreenState();
}

class _MealCalculatorScreenState extends State<MealCalculatorScreen> {
  final TextEditingController _moneyController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  double _result1Meals = 0.0;
  double _result2Meals = 0.0;
  double _result3Meals = 0.0;
  int _remainingDays = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _moneyController.addListener(_calculate);
  }

  @override
  void dispose() {
    _moneyController.removeListener(_calculate);
    _moneyController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDateString = prefs.getString('saved_end_date');
    if (savedDateString != null) {
      _endDate = DateTime.parse(savedDateString);
    }
    final savedMoney = prefs.getDouble('saved_money');
    if (savedMoney != null) {
      _moneyController.text = savedMoney.toString();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_endDate != null) {
      await prefs.setString('saved_end_date', _endDate!.toIso8601String());
    }
    await prefs.setDouble(
      'saved_money',
      double.tryParse(_moneyController.text) ?? 0.0,
    );
  }

  void _calculate() {
    final remainingMoney = double.tryParse(_moneyController.text);
    if (remainingMoney != null && remainingMoney > 0 && _endDate != null) {
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      final remainingDays = end.difference(start).inDays + 1;
      if (remainingDays <= 0) {
        setState(() {
          _result1Meals = 0;
          _result2Meals = 0;
          _result3Meals = 0;
          _remainingDays = 0;
        });
        return;
      }
      setState(() {
        _remainingDays = remainingDays;
        _result1Meals = remainingMoney / remainingDays;
        _result2Meals = remainingMoney / (remainingDays * 2);
        _result3Meals = remainingMoney / (remainingDays * 3);
      });
      _saveData();
    } else {
      setState(() {
        _result1Meals = 0;
        _result2Meals = 0;
        _result3Meals = 0;
        _remainingDays = 0;
      });
    }
  }

  void _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate ?? _startDate,
      ),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)), // 5 years into future
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _calculate();
    }
  }

  void _resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _moneyController.clear();
    setState(() {
      _startDate = DateTime.now();
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat("#,##0.00");
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Budgit',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเซ็ต',
            onPressed: _resetAll,
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
            tooltip: 'สลับธีม',
            onPressed: () => widget.onThemeChanged(!isDarkMode),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'เงินคงเหลือ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _moneyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'กรอกจำนวนเงิน (บาท)',
                ),
              ),
              const SizedBox(height: 16),
              Text('ช่วงเวลา', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _endDate == null
                            ? 'เลือกวันที่เริ่มต้นและสิ้นสุด'
                            : '${DateFormat.yMMMd('th').format(_startDate)} - ${DateFormat.yMMMd('th').format(_endDate!)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Icon(
                        Icons.calendar_today_outlined,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // --- ส่วนแสดงผล ---
              if (_moneyController.text.isNotEmpty && _endDate != null)
                _buildResultSection(currencyFormatter),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection(NumberFormat formatter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('สรุปผลการคำนวณ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _infoCard('งบสำหรับวันนี้ ', '${formatter.format(_result1Meals)} บาท'),
        const SizedBox(height: 12),
        _infoCard('วันที่เหลือ ', '$_remainingDays วัน'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _resultCard('กิน 2 มื้อ', _result2Meals, formatter),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _resultCard('กิน 3 มื้อ', _result3Meals, formatter),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoCard(String title, String value) {
    IconData? iconData;
    if (title.contains('งบสำหรับวันนี้')) {
      iconData = Icons.account_balance_wallet_outlined;
    } else if (title.contains('วันที่เหลือ')) {
      iconData = Icons.hourglass_bottom_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconData != null) ...{
            Icon(
              iconData,
              size: 24,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
          },
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(String title, double value, NumberFormat formatter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatter.format(value),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "ราคาบาทต่อมื้อ",
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

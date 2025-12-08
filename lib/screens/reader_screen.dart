import 'package:flutter/material.dart';
import '../services/couple_service.dart';
import '../services/message_service.dart';
import 'pairing_screen.dart';
import '../data/default_messages.dart';
import '../widgets/error_boundary.dart';
import '../widgets/daily_widget_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/responsive_utils.dart';

// 🎨 GRAFITO + RAUDONO AKCENTO SPALVŲ PALETĖ
class AppColors {
  // Grafito spalvos
  static const Color graphiteBackground = Color(0xFF1E1E1E);
  static const Color graphiteCard = Color(0xFF2C2C2C);
  static const Color graphiteDark = Color(0xFF121212);
  static const Color graphiteLight = Color(0xFF3D3D3D);

  // Teksto spalvos
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF808080);

  // Akcentas - raudona
  static const Color accent = Color(0xFFE53935);
  static const Color accentLight = Color(0xFFFF6659);
  static const Color accentDark = Color(0xFFAB000D);
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final CoupleService _coupleService = CoupleService();
  String? _writerName;
  String? _todayMessage;
  int _todayDayNumber = 1;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isCustomMessage = false;
  Widget _buildWidgetSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.widgets,
                size: 48,
                color: AppColors.accent,
              ), // Raudona
              const SizedBox(height: 16),
              const Text(
                'Žinutė namų ekrane',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.graphiteCard,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pridėkite šią žinutę prie namų ekrano, kad matytumėte ją kiekvieną dieną be aplikacijos atidarymo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showWidgetInstructions,
                icon: const Icon(Icons.add_to_home_screen),
                label: const Text('Pridėti į namų ekraną'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.graphiteCard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToWidget(String message, String writerName) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 🎯 IŠSAUGOTI Į SHAREDPREFERENCES (default pref)
      await prefs.setString('daily_message', message);
      await prefs.setString('writer_name', writerName);
      await prefs.setString('last_update', DateTime.now().toIso8601String());

      debugPrint('✅ Saved to SharedPreferences: "$message"');

      // 🚫 NEREIKIA MethodChannel - widget'as pats persiskaitys
    } catch (e) {
      debugPrint('❌ Error saving to SharedPreferences: $e');
    }
  }

  void _showWidgetInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaip pridėti widget\'ą'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Android:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Laikykite pirštu namų ekrane\n'
                '2. Pasirinkite "Widgets"\n'
                '3. Ieškokite "Love Messages"\n'
                '4. Tempkite į namų ekraną',
              ),
              const SizedBox(height: 16),
              const Text('iOS:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                '1. Eikite į namų ekraną\n'
                '2. Laikykite pirštu tuščioje vietoje\n'
                '3. Pasirinkite "+" mygtuką viršuje\n'
                '4. Ieškokite "Love Messages"',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.purple.shade50,
                child: const Text(
                  'Widget\'as bus automatiškai atnaujinamas kiekvieną rytą su nauja žinute.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Uždaryti'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeWidget();
    _loadData();
  }

  Future<void> _initializeWidget() async {
    await DailyWidgetManager.initializeWidget();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // 🚀 PARALELIAI gauname vardą ir kodą (greičiau!)
      final results = await Future.wait([
        _coupleService.getWriterName(),
        _coupleService.getWriterCode(),
      ]);
      final name = results[0];
      final writerCode = results[1];

      if (writerCode == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage =
                'Nepavyko rasti poros kodo. Bandykite prisijungti iš naujo.';
            _isLoading = false;
          });
        }
        return;
      }

      // 🚀 NEKRAUNAME CACHE IŠ NAUJO - tegul MessageService pats nusprendžia
      // await MessageCache.clearCache();  // ← PAŠALINTA - lėtino!

      final messageService = MessageService();
      final message = await messageService.getMessage(
        MessageService.todayDayNumber,
        writerCode,
      );

      // Patikrinti ar žinutė yra custom (ne default)
      final defaultMessage = DefaultMessages.getMessage(
        MessageService.todayDayNumber,
      );
      final isCustom = message != defaultMessage;

      // 🚀 PIRMA RODOME DUOMENIS, PASKUI ATNAUJINAME WIDGET'Ą FONE
      if (mounted) {
        setState(() {
          _writerName = name;
          _todayMessage = message;
          _todayDayNumber = MessageService.todayDayNumber;
          _isCustomMessage = isCustom;
          _isLoading = false;
        });
      }

      // 🚀 Widget'ą atnaujiname FONE (neblokuoja UI)
      _updateWidgetInBackground(message, name ?? 'Tavo mylimas');
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Nepavyko užkrauti žinutės: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // 🆕 NAUJAS METODAS - widget atnaujinimas fone
  void _updateWidgetInBackground(String message, String writerName) async {
    try {
      await _saveToWidget(message, writerName);
      await DailyWidgetManager.updateWidget(
        message: message,
        writerName: writerName,
      );
    } catch (e) {
      debugPrint('Widget update error (background): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return ErrorBoundary(
      fallback: Scaffold(
        appBar: AppBar(
          title: const Text('Kasdieninė žinutė'),
          backgroundColor: AppColors.graphiteCard,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Įvyko netikėta klaida',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Žinutės skaitymo ekrane įvyko klaida',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.graphiteCard,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Bandyti iš naujo'),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kasdieninė žinutė'),
          backgroundColor: AppColors.graphiteDark,
          foregroundColor: AppColors.textPrimary,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'refresh') {
                  _loadData();
                } else if (value == 'logout') {
                  _showLogoutDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Atnaujinti'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 8),
                      Text('Atsijungti'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Kraunama žinutė...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Bandyti dar kartą'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ❤️ ČIA PRIDĖKITE ŠIRDY SU ŠVYTĖJIMU ▼
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(
                        255,
                        145,
                        52,
                        52,
                      ).withAlpha(77),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 100,
                  color: Color.fromARGB(255, 87, 15, 15),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                elevation: 8,
                color: AppColors.graphiteCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.accent.withAlpha(77), // Raudonas kraštas
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Pakeistas tekstas priklausomai nuo žinutės tipo
                      Text(
                        _isCustomMessage && _writerName != null
                            ? '$_writerName parašė žinutę'
                            : 'Jūsų šios dienos žinutė',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(
                            255,
                            80,
                            58,
                            58,
                          ).withAlpha(127),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accent.withAlpha(51),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _todayMessage ?? 'Tu esi geriausias! ❤️',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Diena: $_todayDayNumber/365',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isCustomMessage)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha(
                                  51,
                                ), // Pusiau permatoma raudona
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.accent.withAlpha(127),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Asmeninė',
                                style: TextStyle(color: AppColors.accent),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              const Text(
                'Kiekvieną dieną gausite naują žinutę.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _writerName != null
                    ? '$_writerName myli jus!'
                    : 'Jūsų antroji pusė myli jus!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: const Color.fromARGB(255, 58, 9, 17),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Data: ${_getCurrentDate()}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),

              // 🆕 PRIDĖTI WIDGET SEKCIJĄ ČIA
              const SizedBox(height: 40),
              _buildWidgetSection(), // ← PRIDĖTA ŠITA LINIJA
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atsijungti?'),
        content: const Text(
          'Ar tikrai norite atsijungti? Galėsite prisijungti vėl su tuo pačiu kodu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Atsijungti'),
          ),
        ],
      ),
    );
  }

  void _performLogout() async {
    try {
      await _coupleService.logout();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PairingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Klaida atsijungiant: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final monthName = MessageService.getMonthName(now.month);
    return '${now.day} $monthName ${now.year}';
  }
}

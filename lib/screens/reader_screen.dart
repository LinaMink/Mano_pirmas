import 'package:flutter/material.dart';
import '../services/couple_service.dart';
import '../services/message_service.dart';
import 'pairing_screen.dart';
import '../services/message_cache.dart';
import '../data/default_messages.dart';
import '../widgets/error_boundary.dart';
import '../widgets/daily_widget_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  final CoupleService _coupleService = CoupleService();
  String? _writerName;
  String? _todayMessage;
  int _todayDayNumber = 1;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isCustomMessage = false;
  int _lastLoadedDay = 0;

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
    WidgetsBinding.instance.addObserver(this); // Stebėti app lifecycle
    _initializeWidget();
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Pašalinti observer
    super.dispose();
  }

  /// Kai aplikacija grįžta į pirmą planą - tikrinti ar nauja diena
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRefreshIfNewDay();
    }
  }

  /// Patikrinti ar pasikeitė diena ir atnaujinti jei reikia
  void _checkAndRefreshIfNewDay() {
    final currentDay = MessageService.todayDayNumber;
    if (_lastLoadedDay != currentDay && _lastLoadedDay != 0) {
      debugPrint(
        '🌅 Nauja diena! Atnaujinama žinutė: $_lastLoadedDay -> $currentDay',
      );
      _loadData();
    }
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
      final name = await _coupleService.getWriterName();
      final writerCode = await _coupleService.getWriterCode();

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

      await MessageCache.clearCache();

      final messageService = MessageService();
      final message = await messageService.getMessage(
        MessageService.todayDayNumber,
        writerCode,
      );
      // 🆕 ATNAUJINTI WIDGET'Ą
      await _saveToWidget(message, name ?? 'Tavo mylimas');
      await DailyWidgetManager.updateWidget(
        message: message,
        writerName: name ?? 'Tavo mylimas',
      );

      // Patikrinti ar žinutė yra custom (ne default)
      final defaultMessage = DefaultMessages.getMessage(
        MessageService.todayDayNumber,
      );
      final isCustom = message != defaultMessage;

      if (mounted) {
        setState(() {
          _writerName = name;
          _todayMessage = message;
          _todayDayNumber = MessageService.todayDayNumber;
          _isCustomMessage = isCustom;
          _isLoading = false;
          _lastLoadedDay =
              MessageService.todayDayNumber; // Įsiminti užkrautą dieną
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      fallback: Scaffold(
        appBar: AppBar(
          title: const Text('Kasdieninė žinutė'),
          backgroundColor: Colors.purple,
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
                    backgroundColor: Colors.purple,
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
          backgroundColor: Colors.purple.shade800,
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
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20, color: Colors.purple),
                      const SizedBox(width: 8),
                      const Text('Atnaujinti'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      const Text('Atsijungti'),
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
              // 📱 KOMPAKTIŠKAS WIDGET BANNER
              GestureDetector(
                onTap: _showWidgetInstructions,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.widgets,
                        size: 16,
                        color: Colors.purple.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pridėti į namų ekraną',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.purple.shade400,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.favorite, size: 100, color: Colors.purple),

              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
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
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Asmeninė žinutė',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
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
                  color: Colors.purple.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Data: ${_getCurrentDate()}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),

              // 🆕 PRIDĖTI WIDGET SEKCIJĄ ČIA
              const SizedBox(height: 20),
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

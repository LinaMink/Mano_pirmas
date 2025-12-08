import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart'; // ✅ PRIDĖTA: kDebugMode
import 'package:flutter/material.dart';
import 'package:lock_screen_love/services/analytics_service.dart';
import '../services/couple_service.dart';
import '../services/error_handler.dart'; // ✅ PRIDĖTI
import 'writer_screen.dart';
import 'reader_screen.dart';
import '../utils/responsive_utils.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  // Būsena
  String? _selectedRole;
  final TextEditingController _writerNameController = TextEditingController();
  final TextEditingController _readerCodeController = TextEditingController();
  final TextEditingController _writerCodeController =
      TextEditingController(); // <-- PRIDĖTA
  bool _isLoading = false;
  String _statusMessage = '';

  // Patikrinti ar jau poruota
  bool _checkingPairing = true;

  // CoupleService instance
  final CoupleService _coupleService = CoupleService();

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyPaired();
  }

  // Patikrinti ar vartotojas jau poruotas
  Future<void> _checkIfAlreadyPaired() async {
    await _coupleService.initialize();
    final isPaired = await _coupleService.isPaired();

    if (!isPaired || !mounted) {
      if (mounted) {
        setState(() => _checkingPairing = false);
      }
      return;
    }

    final isWriter = await _coupleService.isWriter();

    if (!mounted) return;

    final writerName = await _coupleService.getWriterName();

    if (!mounted) return;

    // Automatiškai pereiti į atitinkamą ekraną
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _navigateToAppropriateScreen(isWriter, writerName);
      }
    });

    if (mounted) {
      setState(() => _checkingPairing = false);
    }
  }

  void _clearAllData() async {
    await _coupleService.logout();

    setState(() {
      _statusMessage = '✅ Visi duomenys ištrinti!\nGalite testuoti iš naujo.';
    });
  }

  // Navigacija į atitinkamą ekraną
  void _navigateToAppropriateScreen(bool isWriter, String? writerName) {
    if (!mounted) return;

    if (isWriter) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WriterScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ReaderScreen()),
      );
    }
  }

  @override
  void dispose() {
    _writerNameController.dispose();
    _readerCodeController.dispose();
    _writerCodeController.dispose(); // <-- PRIDĖTA
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    // Rodyti kraunamą ekraną kol tikrinama
    if (_checkingPairing) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Tikrinama...'),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.purple.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          // <-- PRIDĖTI ŠITĄ!
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                _buildLogoSection(),
                const SizedBox(height: 40),

                // Role pasirinkimas arba forma
                if (_selectedRole == null) _buildRoleSelection(),
                if (_selectedRole == 'writer') _buildWriterForm(),
                if (_selectedRole == 'writer_login') _buildWriterLoginForm(),
                if (_selectedRole == 'reader') _buildReaderForm(),

                // Grįžti mygtukas (tik jei pasirinkta role)
                if (_selectedRole != null) _buildBackButton(),

                // Statuso pranešimas
                if (_statusMessage.isNotEmpty) _buildStatusMessage(),

                // DEBUG mygtukas (tik development režime ir kai nėra pasirinkta role)
                if (kDebugMode && _selectedRole == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: TextButton(
                      onPressed: _clearAllData,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bug_report, size: 16),
                          SizedBox(width: 8),
                          Text('DEBUG: Išvalyti visus duomenis'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================== LOGO SEKCIJA ==================
  Widget _buildLogoSection() {
    return Column(
      children: [
        Icon(
          Icons.favorite,
          size: ResponsiveUtils.iconXXL,
          color: Colors.purple,
        ),
        SizedBox(height: ResponsiveUtils.spaceL),
        Text(
          'LOVE MESSAGES',
          style: TextStyle(
            fontSize: ResponsiveUtils.fontXXL,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
        ),
        SizedBox(height: ResponsiveUtils.spaceS),
        Text(
          _selectedRole == null
              ? 'Pasirinkite savo'
              : _selectedRole == 'writer'
              ? 'Sukurkite porą'
              : _selectedRole == 'writer_login'
              ? 'Prisijunkite kaip rašytojas'
              : 'Prisijunkite prie poros',
          style: TextStyle(
            fontSize: ResponsiveUtils.fontL,
            color: Colors.purple.shade600,
          ),
        ),
      ],
    );
  }

  // ================== ROLIŲ PASIRINKIMAS ==================
  Widget _buildRoleSelection() {
    return Column(
      children: [
        // PAVADINIMAS
        const Text(
          'Pasirinkite savo vaidmenį',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Kiekvienai porai reikia tik VIENO rašytojo',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 30),

        // PRISIJUNGTI KAIP SKAITYTOJAS
        Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
          ), // <-- Pridėti margin
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.menu_book,
              color: Colors.purple,
              size: 32,
            ),
            title: const Text(
              'Skaitytojas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Gavote kodą iš partnerio? Prisijunkite čia'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              setState(() {
                _selectedRole = 'reader';
                _statusMessage = 'Įveskite gautą skaitytojo kodą';
              });
            },
            contentPadding: const EdgeInsets.all(16),
          ),
        ),

        const SizedBox(height: 16),

        // PRISIJUNGTI KAIP RAŠYTOJAS
        Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
          ), // <-- Pridėti margin
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const Icon(Icons.edit, color: Colors.purple, size: 32),
            title: const Text(
              'Rašytojas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Jau turite porą? Prisijunkite su savo kodu'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              setState(() {
                _selectedRole = 'writer_login';
                _statusMessage = 'Įveskite savo rašytojo kodą';
              });
            },
            contentPadding: const EdgeInsets.all(16),
          ),
        ),

        const SizedBox(height: 20),

        // SKIRTUVIU LINIJA
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'ARBA',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // SUKURTI NAUJĄ PORĄ
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sukurti naują porą?'),
                  content: const Text(
                    'Tai sukurs naują porą su Jumis kaip rašytoju. '
                    'Gausite kodą, kurį galėsite duoti partneriui.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Atšaukti'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedRole = 'writer';
                          _statusMessage = 'Sukurkite naują porą';
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                      child: const Text('Tęsti'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.favorite_border),
            label: const Text('Sukurti naują porą'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.purple,
              side: const BorderSide(color: Colors.purple),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // INFORMACIJA
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text(
                    'Svarbu:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Jei gavote R-XXXXXX kodą - spauskite "Skaitytojas"\n'
                    '• Jei turite W-XXXXXX kodą - spauskite "Rašytojas"\n'
                    '• Sukurkite naują porą TIK jei dar neturite poros',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================== RAŠYTOJO FORMA ==================
  Widget _buildWriterForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pavadinimas su ikona
            Row(
              children: [
                const Icon(Icons.edit, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Sukurti naują porą',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const Text(
              'Jūs rašysite žinutes savo antrajai pusei',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // Vardo laukas
            TextField(
              controller: _writerNameController,
              decoration: const InputDecoration(
                labelText: 'Jūsų vardas',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                hintText: 'Įveskite savo vardą',
              ),
            ),

            const SizedBox(height: 24),

            // Sukurti porą mygtukas
            ElevatedButton(
              onPressed: _isLoading ? null : _createCouple,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite),
                        SizedBox(width: 8),
                        Text('Sukurti porą', style: TextStyle(fontSize: 16)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== RAŠYTOJO PRISIJUNGIMO FORMA ==================
  Widget _buildWriterLoginForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.login, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Prisijungti kaip rašytojas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Įveskite savo rašytojo kodą (W-XXXXXX)',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _writerCodeController,
              decoration: const InputDecoration(
                labelText: 'Rašytojo kodas',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
                hintText: 'W-123456',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Kodą gavote kurdami porą',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _loginAsWriter,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login),
                        SizedBox(width: 8),
                        Text('Prisijungti', style: TextStyle(fontSize: 16)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== SKAITYTOJO FORMA ==================
  Widget _buildReaderForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pavadinimas su ikona
            Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Prisijungti prie poros',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const Text(
              'Jūs skaitysite žinutes nuo savo antrosios pusės',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // Kodo laukas
            TextField(
              controller: _readerCodeController,
              decoration: const InputDecoration(
                labelText: 'Gautas kodas',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
                hintText: 'PVZ: R-123456',
              ),
              textCapitalization: TextCapitalization.characters,
            ),

            const SizedBox(height: 8),

            // Pastaba apie kodą
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Kodą gausite iš savo antrosios pusės',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),

            const SizedBox(height: 24),

            // Prisijungti mygtukas
            ElevatedButton(
              onPressed: _isLoading ? null : _joinCouple,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login),
                        SizedBox(width: 8),
                        Text('Prisijungti', style: TextStyle(fontSize: 16)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== GRĖŽTI MYGTUKAS ==================
  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: TextButton.icon(
        onPressed: () {
          setState(() {
            _selectedRole = null;
            _writerNameController.clear();
            _readerCodeController.clear();
            _writerCodeController.clear();
            _statusMessage = '';
          });
        },
        icon: const Icon(Icons.arrow_back),
        label: const Text('Grįžti atgal'),
        style: TextButton.styleFrom(foregroundColor: Colors.purple),
      ),
    );
  }

  // ================== STATUSO PRANEŠIMAS ==================
  Widget _buildStatusMessage() {
    final isError = _statusMessage.contains('❌');

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError ? Colors.red.shade200 : Colors.green.shade200,
          ),
        ),
        child: Text(
          _statusMessage,
          style: TextStyle(
            color: isError ? Colors.red.shade800 : Colors.green.shade800,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ================== FUNKCIJOS ==================

  // Sukurti porą (Rašytojas)
  // Sukurti porą (Rašytojas)
  void _createCouple() async {
    final name = _writerNameController.text.trim();

    if (name.isEmpty) {
      setState(() => _statusMessage = '❌ Įveskite savo vardą');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Kuriama pora...';
    });

    try {
      // NAUDOJAME COUPLE_SERVICE
      final result = await _coupleService.createCouple(name);

      if (!mounted) return;

      if (result['success'] == true) {
        final writerCode = result['writerCode'] as String;
        final readerCode = result['readerCode'] as String;

        setState(() {
          _isLoading = false;
          _statusMessage =
              '''✅ Poros kodai sukurti!

Rašytojo kodas: $writerCode
Skaitytojo kodas: $readerCode

Duokite skaitytojo kodą partneriui!''';
        });

        // 🎯 LOG SUCCESS TO ANALYTICS
        try {
          await AnalyticsService.logCoupleCreated();
        } catch (analyticsError) {
          debugPrint('Analytics error: $analyticsError');
        }

        // Po 4 sekundžių pereiti į WriterScreen
        // Po 1.5 sekundės pereiti į WriterScreen (užtenka perskaityti kodus)
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WriterScreen()),
            );
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = '❌ Klaida: ${result['error']}';
        });

        // 🎯 LOG ERROR TO ANALYTICS
        try {
          await AnalyticsService.logError(
            errorType: 'couple_creation_failed',
            screen: 'PairingScreen',
            errorMessage: result['error'].toString(),
          );
        } catch (analyticsError) {
          debugPrint('Analytics error: $analyticsError');
        }
      }
    } catch (e, stackTrace) {
      // ✅ NAUDOTI ErrorHandler
      await ErrorHandler.logError(
        e,
        stackTrace,
        context: 'PairingScreen.createCouple',
        additionalData: {'writerName': name},
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _statusMessage = '❌ ${ErrorHandler.getUserFriendlyMessage(e)}';
      });
    }
  }

  // Prisijungti prie poros (Skaitytojas)
  void _joinCouple() async {
    final code = _readerCodeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _statusMessage = '❌ Įveskite gautą kodą');
      return;
    }

    if (!code.startsWith('R-') || code.length < 8) {
      setState(
        () => _statusMessage = '❌ Neteisingas formatas. Turi būti "R-XXXXXX"',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Prisijungiama...';
    });

    try {
      // NAUDOJAME COUPLE_SERVICE
      final result = await _coupleService.joinCouple(code);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _isLoading = false;
          _statusMessage = '✅ Sėkmingai prisijungta!';
        });

        // 🎯 LOG SUCCESS TO ANALYTICS
        try {
          await AnalyticsService.logReaderJoined(); // ← NAUDOJAME NAUJĄ METODĄ
        } catch (analyticsError) {
          debugPrint('Analytics error: $analyticsError');
        }

        // Po 2 sekundžių pereiti į ReaderScreen
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ReaderScreen()),
            );
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = '❌ Klaida: ${result['error']}';
        });

        // 🎯 LOG ERROR TO ANALYTICS
        try {
          await AnalyticsService.logError(
            errorType: 'join_couple_failed',
            screen: 'PairingScreen',
            errorMessage: result['error'].toString(),
          );
        } catch (analyticsError) {
          debugPrint('Analytics error: $analyticsError');
        }
      }
    } catch (e, stackTrace) {
      // ✅ NAUDOTI ErrorHandler
      await ErrorHandler.logError(
        e,
        stackTrace,
        context: 'PairingScreen.joinCouple',
        additionalData: {'readerCode': code},
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _statusMessage = '❌ ${ErrorHandler.getUserFriendlyMessage(e)}';
      });
    }
  }

  // Prisijungti kaip rašytojas
  void _loginAsWriter() async {
    final code = _writerCodeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _statusMessage = '❌ Įveskite savo rašytojo kodą');
      return;
    }

    if (!code.startsWith('W-') || code.length < 8) {
      setState(
        () => _statusMessage = '❌ Neteisingas formatas. Turi būti "W-XXXXXX"',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Prisijungiama...';
    });

    try {
      // Patikrinti ar pora egzistuoja
      final result = await _coupleService.checkCoupleExists(code);

      if (!mounted) return;

      if (result['success'] == true && result['exists'] == true) {
        // Išsaugoti lokaliai kaip rašytoją
        final writerName = result['writerName'] as String? ?? 'Rašytojas';
        final readerCode = result['readerCode'] as String? ?? '';

        await _coupleService.saveToLocalStorage(
          writerCode: code,
          readerCode: readerCode,
          isWriter: true,
          writerName: writerName,
        );

        setState(() {
          _isLoading = false;
          _statusMessage = '✅ Sėkmingai prisijungta!';
        });

        // 🎯 LOG SUCCESS TO ANALYTICS
        try {
          await AnalyticsService.logWriterLoggedIn(); // ← NAUDOJAME NAUJĄ METODĄ
        } catch (analyticsError) {
          debugPrint('Analytics error: $analyticsError');
        }

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WriterScreen()),
            );
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = '❌ Klaida: ${result['error']}';
        });

        // 🎯 LOG ERROR TO ANALYTICS
        try {
          await AnalyticsService.logError(
            errorType: 'writer_login_failed',
            screen: 'PairingScreen',
            errorMessage: result['error'].toString(),
          );
        } catch (analyticsError) {
          debugPrint('Analytics error: $analyticsError');
        }
      }
    } catch (e, stackTrace) {
      // 🔥 UNEXPECTED ERROR
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _statusMessage = '❌ ${ErrorHandler.getUserFriendlyMessage(e)}';
      });

      // 🎯 LOG UNEXPECTED ERROR TO ANALYTICS
      try {
        await AnalyticsService.logError(
          errorType: 'writer_login_unexpected',
          screen: 'PairingScreen',
          errorMessage: e.toString(),
        );
      } catch (analyticsError) {
        debugPrint('Analytics error: $analyticsError');
      }

      // 🎯 ALSO LOG TO CRASHLYTICS
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace);
      } catch (crashlyticsError) {
        debugPrint('Crashlytics error: $crashlyticsError');
      }
    }
  }
}

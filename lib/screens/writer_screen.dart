import 'package:flutter/material.dart';
import '../services/couple_service.dart';
import '../services/message_service.dart';
import '../services/message_cache.dart';
import 'calendar_screen.dart';
import 'pairing_screen.dart';
import '../widgets/loading_overlay.dart';
import '../services/analytics_service.dart';

class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  final CoupleService _coupleService = CoupleService();
  String? _writerName;
  String? _todayMessage = 'Tu esi geriausias! ❤️';

  // 🚀 OPTIMIZACIJA: Cache poros informaciją
  Map<String, dynamic>? _cachedPairingInfo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 🚀 OPTIMIZUOTAS: Vienas kvietimas vietoj dviejų
  Future<void> _loadData() async {
    try {
      // Gauname poros info TIK VIENĄ KARTĄ
      final info = await _coupleService.getPairingInfo();
      _cachedPairingInfo = info;

      final writerCode = info['writerCode'];

      if (writerCode != null) {
        final messageService = MessageService();
        final todayMessage = await messageService.getMessage(
          MessageService.todayDayNumber,
          writerCode.toString(),
        );

        if (mounted) {
          setState(() {
            _writerName = info['writerName'];
            _todayMessage = todayMessage;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _writerName != null ? 'Sveiki, $_writerName!' : 'Rašytojas',
        ),
        backgroundColor: Colors.purple,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              } else if (value == 'couple_info') {
                _showCoupleInfoDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'couple_info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Poros informacija'),
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🚀 PAŠALINTA: FutureBuilder kortelė (perkelta į popup meniu)
                const Text(
                  'Šiandienos žinutė:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Card(
                  color: Colors.purple.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          _todayMessage ?? 'Tu esi geriausias! ❤️',
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Diena: ${MessageService.todayDayNumber}/365',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _editTodaysMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Keisti šiandienos žinutę'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CalendarScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade800,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month),
                      SizedBox(width: 8),
                      Text('Žinučių kalendorius'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Card(
                  color: Colors.grey.shade100,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Jūsų antroji pusė matys šią žinutę kiekvieną rytą.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
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

  // 🆕 NAUJAS: Poros informacijos dialogas (vietoj "Sukurti naują porą")
  void _showCoupleInfoDialog() async {
    // 🚀 Naudojame cached info jei yra
    final info = _cachedPairingInfo ?? await _coupleService.getPairingInfo();
    final writerCode = info['writerCode'] ?? 'Nėra';
    final readerCode = info['readerCode'] ?? 'Nėra';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.purple),
            SizedBox(width: 8),
            Text('Poros informacija'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rašytojo kodas
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jūsų kodas (rašytojo):',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    writerCode.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Skaitytojo kodas
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.pink.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Partnerio kodas (skaitytojo):',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    readerCode.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Skaitytojo kodą duokite savo antrajai pusei, kad ji galėtų prisijungti.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Atsijungti?'),
          content: const Text('Ar tikrai norite atsijungti?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Atšaukti'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _performLogout();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Atsijungti'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      await _coupleService.logout();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PairingScreen()),
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

  void _editTodaysMessage() {
    AnalyticsService.logCalendarOpened();
    LoadingOverlay.show(context, message: 'Kraunama žinutė...');

    Future.delayed(Duration.zero, () async {
      try {
        // 🚀 Naudojame cached info jei yra
        final writerCode =
            _cachedPairingInfo?['writerCode'] ??
            await _coupleService.getWriterCode();

        if (writerCode == null) {
          if (mounted) {
            LoadingOverlay.hide();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Nepavyko gauti rašytojo kodo'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final messageService = MessageService();
        final currentMessage = await messageService.getMessage(
          MessageService.todayDayNumber,
          writerCode.toString(),
        );

        if (!mounted) return;

        LoadingOverlay.hide();

        await showDialog(
          context: context,
          builder: (context) => _EditMessageDialog(
            initialMessage: currentMessage,
            coupleService: _coupleService,
            onMessageSaved: () {
              _loadData();
            },
          ),
        );
      } catch (e) {
        if (mounted) {
          LoadingOverlay.hide();
          // PATIKRINKITE AR OFFLINE
          if (e.toString().contains('SocketException') ||
              e.toString().contains('Connection failed') ||
              e.toString().contains('Network is unreachable')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Nėra interneto ryšio. Žinutės negalima išsaugoti.'),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Klaida: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    });
  }
}

class _EditMessageDialog extends StatefulWidget {
  final String initialMessage;
  final CoupleService coupleService;
  final VoidCallback onMessageSaved;

  const _EditMessageDialog({
    required this.initialMessage,
    required this.coupleService,
    required this.onMessageSaved,
  });

  @override
  State<_EditMessageDialog> createState() => __EditMessageDialogState();
}

class __EditMessageDialogState extends State<_EditMessageDialog> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveMessage() async {
    final message = _controller.text.trim();

    if (message.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Žinutė negali būti tuščia'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 🆕 PATIKRINTI DIENOS LIMITĄ PRIEŠ VISKĄ
    final writerCode = await widget.coupleService.getWriterCode();
    if (writerCode != null) {
      final canWrite = await MessageCache.canWriteMessage(writerCode);
      if (!canWrite) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.block, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Dienos limitas'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Jūs jau parašėte 3 žinutes šiandien.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Galėsite rašyti naujas žinutes rytoj po vidurnakčio.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Gerai'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    // 🔒 VALIDATE MESSAGE BEFORE SAVING
    final messageService = MessageService();
    final validation = messageService.validateMessage(message);

    if (!validation['isValid']) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Neleistinas tekstas'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    validation['message'] ?? 'Neleistinas tekstas',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔒 Saugumui draudžiama:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('• Nuorodos (URL)'),
                        Text('• Telefono numeriai'),
                        Text('• El. pašto adresai'),
                        Text('• Įtartini žodžiai (bankas, kurjeris, etc.)'),
                        Text('• Per daug specialių simbolių'),
                        SizedBox(height: 8),
                        Text(
                          'Tai apsaugo nuo sukčių! 🛡️',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Gerai'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    // writerCode jau gautas anksčiau (limito patikrinimui)
    if (writerCode != null) {
      final success = await messageService.saveCustomMessage(
        writerCode: writerCode,
        dayNumber: MessageService.todayDayNumber,
        message: message,
      );

      // 🆕 ANALYTICS
      try {
        await AnalyticsService.logMessageEdited(
          dayNumber: MessageService.todayDayNumber,
          isCustom: true,
          messageLength: message.length,
        );
      } catch (e) {
        debugPrint('Analytics error: $e');
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Žinutė sėkmingai išsaugota!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        widget.onMessageSaved();
        Navigator.pop(context, true);
      } else if (mounted) {
        // 🆕 OFFLINE KLAIDOS PRANEŠIMAS
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nėra interneto ryšio. Žinutės negalima išsaugoti.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
              textColor: Colors.white,
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gauname klaviatūros aukštį
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? 20 : 0),
      child: AlertDialog(
        // Mažesni kraštai - daugiau vietos turiniui
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('Redaguoti šiandienos žinutę'),
        content: SizedBox(
          // Fiksuotas plotis, kad dialogas būtų platesnis
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            // Svarbu: reverse leidžia matyti tekstą kai rašome
            reverse: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Diena: ${MessageService.todayDayNumber}/365',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                // Simbolių skaitiklis
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_controller.text.length}/500',
                    style: TextStyle(
                      color: _controller.text.length > 450
                          ? Colors.orange
                          : Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null, // Leidžia neribotai eilučių
                  minLines: 4, // Minimalus aukštis
                  maxLength: 500, // Maksimalus ilgis
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  // Svarbu: scrollPadding palieka vietos klaviatūrai
                  scrollPadding: EdgeInsets.only(bottom: bottomInset + 100),
                  onChanged: (text) {
                    // Atnaujina simbolių skaitiklį
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Įrašykite savo žinutę...',
                    border: const OutlineInputBorder(),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple, width: 2),
                    ),
                    // Pašalina standartinį counter'į (nes turime savo)
                    counterText: '',
                    // Prideda padding viduje
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                // Papildoma vieta po TextField kai klaviatūra atidaryta
                SizedBox(height: bottomInset > 0 ? 20 : 0),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveMessage,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Išsaugoti'),
          ),
        ],
      ),
    );
  }
}

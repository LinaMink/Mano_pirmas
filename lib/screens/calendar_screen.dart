import 'package:flutter/material.dart';
import 'package:lock_screen_love/services/analytics_service.dart';
import '../services/message_service.dart';
import '../services/couple_service.dart';
import '../widgets/error_boundary.dart';
import 'dart:async'; // 🆕 PRIDĖTI TIMER

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CoupleService _coupleService = CoupleService();
  final ScrollController _monthScrollController = ScrollController();
  List<Month> _months = [];
  final Map<int, Day> _daysMap = {};
  int _selectedMonth = DateTime.now().month;
  int? _selectedDay;
  bool _isLoading = true;
  final Map<int, String> _customMessages = {};
  bool _hasError = false;
  String? _currentWriterCode;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  @override
  void dispose() {
    // Atšaukti visus timer'ius
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    // Atšaukti scroll controller
    _monthScrollController.dispose();

    super.dispose();
  }

  void _initializeDaysMap() {
    _daysMap.clear();
    for (final month in _months) {
      for (final day in month.days) {
        _daysMap[day.dayOfYear] = day;
      }
    }
  }

  Future<void> _loadCalendar() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final months = MessageService.getMonths();
      final writerCode = await _coupleService.getWriterCode();

      if (writerCode == null) {
        throw Exception('Nerastas rašytojo kodas');
      }

      _currentWriterCode = writerCode;
      final messageService = MessageService();
      final allCustomMessages = await messageService.getAllCustomMessages(
        writerCode,
      );

      if (!mounted) return;

      setState(() {
        _months = months;
        _customMessages.clear();
        _customMessages.addAll(allCustomMessages);
        _updateDaysWithCustomMessages();
        _isLoading = false;
        _selectedMonth = DateTime.now().month;
      });

      final timer = Timer(const Duration(milliseconds: 50), () {
        if (mounted) {
          _scrollToCurrentMonth();
        }
      });
      _timers.add(timer);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _updateDaysWithCustomMessages() {
    _initializeDaysMap();

    for (final entry in _customMessages.entries) {
      final dayNumber = entry.key;
      final message = entry.value;

      final day = _daysMap[dayNumber];
      if (day != null) {
        day.customMessage = message;
      }
    }
  }

  void _scrollToCurrentMonth() {
    if (_monthScrollController.hasClients) {
      final currentMonthIndex = DateTime.now().month - 1;
      final scrollPosition = currentMonthIndex * 100.0;
      final timer = Timer(const Duration(milliseconds: 300), () {
        // Po 300ms patikrinti ar dar mounted
        if (mounted && _monthScrollController.hasClients) {
          _monthScrollController.animateTo(
            scrollPosition,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });

      _timers.add(timer);
    }
  }

  void _changeMonth(int month) {
    setState(() => _selectedMonth = month);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Kraunamas kalendorius...'),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Žinučių kalendorius'),
          backgroundColor: Colors.purple,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
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
                  'Nepavyko užkrauti kalendoriaus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Patikrinkite interneto ryšį',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _loadCalendar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  child: const Text('Bandyti dar kartą'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedMonth = _months.firstWhere(
      (m) => m.monthNumber == _selectedMonth,
      orElse: () => _months.first,
    );

    return ErrorBoundary(
      fallback: Scaffold(
        appBar: AppBar(
          title: const Text('Žinučių kalendorius'),
          backgroundColor: Colors.purple,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
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
                  'Įvyko klaida kalendoriuje',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Pabandykite perkrauti kalendorių',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _loadCalendar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  child: const Text('Perkrauti'),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Žinučių kalendorius'),
          backgroundColor: Colors.purple,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: () {
                final currentMonth = DateTime.now().month;
                if (_selectedMonth != currentMonth) {
                  _changeMonth(currentMonth);
                  _scrollToCurrentMonth();
                }
              },
              tooltip: 'Rodyti šį mėnesį',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _loadCalendar,
              tooltip: 'Atnaujinti kalendorių',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildMonthSelector(),
            Expanded(child: _buildDaysGrid(selectedMonth)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        controller: _monthScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _months.length,
        itemBuilder: (context, index) {
          final month = _months[index];
          final isSelected = month.monthNumber == _selectedMonth;

          return GestureDetector(
            onTap: () {
              _changeMonth(month.monthNumber);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.purple : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Center(
                child: Text(
                  month.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDaysGrid(Month month) {
    return RefreshIndicator(
      onRefresh: _loadCalendar,
      color: Colors.purple,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1,
        ),
        itemCount: month.days.length,
        itemBuilder: (context, index) {
          final day = month.days[index];
          final isToday = day.dayOfYear == MessageService.todayDayNumber;
          final hasCustomMessage = _customMessages.containsKey(day.dayOfYear);
          final isSelected = _selectedDay == day.dayOfYear;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDay = day.dayOfYear;
              });
              _editMessage(day);
            },
            child: Container(
              decoration: BoxDecoration(
                color: isToday
                    ? Colors.purple.shade700
                    : isSelected
                    ? Colors.purple.shade200
                    : hasCustomMessage
                    ? Colors.purple.shade100
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday
                      ? Colors.purple.shade900
                      : isSelected
                      ? Colors.purple.shade600
                      : hasCustomMessage
                      ? Colors.purple.shade300
                      : Colors.grey.shade300,
                  width: isToday || isSelected ? 2 : 1,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      '${day.dayOfMonth}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isToday || isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isToday
                            ? Colors.white
                            : isSelected
                            ? Colors.purple.shade900
                            : hasCustomMessage
                            ? Colors.purple.shade900
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (hasCustomMessage)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Icon(
                        Icons.edit,
                        size: 12,
                        color: isToday
                            ? Colors.white70
                            : Colors.purple.shade400,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _editMessage(Day day) async {
    try {
      await AnalyticsService.logCalendarOpened();
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
    if (_currentWriterCode == null) {
      final writerCode = await _coupleService.getWriterCode();
      _currentWriterCode = writerCode;
    }

    if (_currentWriterCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nepavyko gauti rašytojo kodo'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final messageService = MessageService();
    final currentMessage = await messageService.getMessage(
      day.dayOfYear,
      _currentWriterCode!,
    );

    final hasCustomMessage = _customMessages.containsKey(day.dayOfYear);

    if (!mounted) return;

    final TextEditingController controller = TextEditingController(
      text: currentMessage,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _MessageEditDialog(
          day: day,
          controller: controller,
          hasCustomMessage: hasCustomMessage,
          currentWriterCode: _currentWriterCode!,
          messageService: messageService,
          onMessageDeleted: () {
            _customMessages.remove(day.dayOfYear);
            if (mounted) {
              setState(() {});
            }
          },
          onMessageSaved: () {
            _customMessages[day.dayOfYear] = controller.text.trim();
            final updatedDay = _daysMap[day.dayOfYear];
            if (updatedDay != null) {
              updatedDay.customMessage = controller.text.trim();
            }
            if (mounted) {
              setState(() {});
            }
          },
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Žinutė išsaugota!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class _MessageEditDialog extends StatefulWidget {
  final Day day;
  final TextEditingController controller;
  final bool hasCustomMessage;
  final String currentWriterCode;
  final MessageService messageService;
  final VoidCallback onMessageDeleted;
  final VoidCallback onMessageSaved;

  const _MessageEditDialog({
    required this.day,
    required this.controller,
    required this.hasCustomMessage,
    required this.currentWriterCode,
    required this.messageService,
    required this.onMessageDeleted,
    required this.onMessageSaved,
  });

  @override
  State<_MessageEditDialog> createState() => __MessageEditDialogState();
}

class __MessageEditDialogState extends State<_MessageEditDialog> {
  bool _isSaving = false;

  Future<void> _deleteMessage() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ištrinti žinutę?'),
        content: const Text(
          'Ar tikrai norite ištrinti šią žinutę? '
          'Bus grąžinta numatytoji žinutė.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ištrinti'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final success = await widget.messageService.deleteCustomMessage(
        writerCode: widget.currentWriterCode,
        dayNumber: widget.day.dayOfYear,
      );

      if (success) {
        widget.onMessageDeleted();
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Žinutė ištrinta!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Nepavyko ištrinti žinutės'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Klaida: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveMessage() async {
    if (widget.controller.text.trim().isEmpty) {
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

    final validation = widget.messageService.validateMessage(
      widget.controller.text.trim(),
    );

    if (!validation['isValid']) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('Neleistinas tekstas')),
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
                        Text(
                          '• Nuorodos (URL)',
                          style: TextStyle(fontSize: 13),
                        ),
                        Text(
                          '• Telefono numeriai',
                          style: TextStyle(fontSize: 13),
                        ),
                        Text(
                          '• El. pašto adresai',
                          style: TextStyle(fontSize: 13),
                        ),
                        Text(
                          '• Įtartini žodžiai',
                          style: TextStyle(fontSize: 13),
                        ),
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

    try {
      final success = await widget.messageService.saveCustomMessage(
        writerCode: widget.currentWriterCode,
        dayNumber: widget.day.dayOfYear,
        message: widget.controller.text.trim(),
      );
      try {
        await AnalyticsService.logMessageEdited(
          dayNumber: widget.day.dayOfYear,
          isCustom: true,
          messageLength: widget.controller.text.trim().length,
        );
      } catch (e) {
        debugPrint('Analytics error: $e');
      }
      setState(() => _isSaving = false);

      if (success) {
        widget.onMessageSaved();
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Nepavyko išsaugoti žinutės'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);

      final errorMessage = e.toString();
      if (errorMessage.contains('SocketException') ||
          errorMessage.contains('Connection failed')) {
        if (mounted) {
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
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Klaida: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.day.dayOfMonth} ${MessageService.getMonthName(widget.day.date.month)}',
        style: const TextStyle(color: Colors.purple),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Metų diena: ${widget.day.dayOfYear}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.controller,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Įrašykite žinutę...',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purple),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.hasCustomMessage && !_isSaving)
          TextButton(
            onPressed: _deleteMessage,
            child: const Text('Ištrinti', style: TextStyle(color: Colors.red)),
          ),
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
    );
  }
}

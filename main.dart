import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(DioliApp(store: store));
}

class DioliApp extends StatelessWidget {
  final AppStore store;
  const DioliApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DIOLI – Studio de Beleza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.giulia,
          brightness: Brightness.light,
        ),
        fontFamily: 'sans',
      ),
      home: AgendaShell(store: store),
    );
  }
}

class AppColors {
  static const background = Color(0xFFF7F2EC);
  static const card = Color(0xFFFFFCF9);
  static const text = Color(0xFF171717);
  static const muted = Color(0xFF77716B);
  static const line = Color(0xFFE5DDD4);
  static const giulia = Color(0xFF5C8FE8);
  static const tuani = Color(0xFFE88EAE);
  static const green = Color(0xFF78B99B);
  static const yellow = Color(0xFFE8BE62);
  static const purple = Color(0xFF9D82D8);
  static const red = Color(0xFFD97676);
}

enum Professional { giulia, tuani, all }
enum CalendarView { day, threeDays, week, month }

String professionalLabel(Professional p) {
  switch (p) {
    case Professional.giulia:
      return 'GIULIA';
    case Professional.tuani:
      return 'TUANI';
    case Professional.all:
      return 'TODAS';
  }
}

Color professionalColor(Professional p) {
  switch (p) {
    case Professional.giulia:
      return AppColors.giulia;
    case Professional.tuani:
      return AppColors.tuani;
    case Professional.all:
      return AppColors.giulia;
  }
}

class ServiceItem {
  String id;
  String name;
  int duration;
  double price;
  Professional professional;

  ServiceItem({
    required this.id,
    required this.name,
    required this.duration,
    required this.price,
    required this.professional,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'duration': duration,
        'price': price,
        'professional': professional.name,
      };

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
        id: j['id'],
        name: j['name'],
        duration: j['duration'] ?? 30,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        professional: Professional.values.firstWhere(
          (x) => x.name == j['professional'],
          orElse: () => Professional.giulia,
        ),
      );
}

class Appointment {
  String id;
  String client;
  String service;
  Professional professional;
  DateTime start;
  int duration;
  double price;
  double signal;
  String paymentMethod;
  Color color;
  String observation;
  String status;

  Appointment({
    required this.id,
    required this.client,
    required this.service,
    required this.professional,
    required this.start,
    required this.duration,
    required this.price,
    required this.signal,
    required this.paymentMethod,
    required this.color,
    required this.observation,
    this.status = 'Agendado',
  });

  DateTime get end => start.add(Duration(minutes: duration));
  double get pending => (price - signal).clamp(0, double.infinity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'client': client,
        'service': service,
        'professional': professional.name,
        'start': start.toIso8601String(),
        'duration': duration,
        'price': price,
        'signal': signal,
        'paymentMethod': paymentMethod,
        'color': color.toARGB32(),
        'observation': observation,
        'status': status,
      };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'],
        client: j['client'] ?? '',
        service: j['service'] ?? '',
        professional: Professional.values.firstWhere(
          (x) => x.name == j['professional'],
          orElse: () => Professional.giulia,
        ),
        start: DateTime.parse(j['start']),
        duration: j['duration'] ?? 30,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        signal: (j['signal'] as num?)?.toDouble() ?? 0,
        paymentMethod: j['paymentMethod'] ?? '',
        color: Color(j['color'] ?? AppColors.giulia.toARGB32()),
        observation: j['observation'] ?? '',
        status: j['status'] ?? 'Agendado',
      );
}

class AppStore extends ChangeNotifier {
  final List<Appointment> appointments = [];
  final List<ServiceItem> services = [
    ServiceItem(
      id: 's1',
      name: 'Micropigmentação de sobrancelhas',
      duration: 120,
      price: 580,
      professional: Professional.giulia,
    ),
    ServiceItem(
      id: 's2',
      name: 'Micropigmentação labial',
      duration: 120,
      price: 580,
      professional: Professional.giulia,
    ),
    ServiceItem(
      id: 's3',
      name: 'Designer de sobrancelhas',
      duration: 45,
      price: 80,
      professional: Professional.tuani,
    ),
    ServiceItem(
      id: 's4',
      name: 'Remoção a laser',
      duration: 45,
      price: 0,
      professional: Professional.giulia,
    ),
  ];

  bool loaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final a = prefs.getString('appointments');
    final s = prefs.getString('services');
    if (a != null) {
      appointments
        ..clear()
        ..addAll((jsonDecode(a) as List)
            .map((e) => Appointment.fromJson(Map<String, dynamic>.from(e))));
    }
    if (s != null) {
      services
        ..clear()
        ..addAll((jsonDecode(s) as List)
            .map((e) => ServiceItem.fromJson(Map<String, dynamic>.from(e))));
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'appointments',
      jsonEncode(appointments.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'services',
      jsonEncode(services.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addAppointment(Appointment a) async {
    appointments.add(a);
    await save();
    notifyListeners();
  }

  Future<void> updateAppointment(Appointment a) async {
    final i = appointments.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      appointments[i] = a;
      await save();
      notifyListeners();
    }
  }

  Future<void> deleteAppointment(String id) async {
    appointments.removeWhere((x) => x.id == id);
    await save();
    notifyListeners();
  }

  Future<void> addService(ServiceItem s) async {
    services.add(s);
    await save();
    notifyListeners();
  }

  Future<void> updateService(ServiceItem s) async {
    final i = services.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      services[i] = s;
      await save();
      notifyListeners();
    }
  }

  Future<void> deleteService(String id) async {
    services.removeWhere((x) => x.id == id);
    await save();
    notifyListeners();
  }
}

class AgendaShell extends StatefulWidget {
  final AppStore store;
  const AgendaShell({super.key, required this.store});

  @override
  State<AgendaShell> createState() => _AgendaShellState();
}

class _AgendaShellState extends State<AgendaShell> {
  int tab = 0;
  Professional professional = Professional.giulia;
  CalendarView view = CalendarView.day;
  DateTime selectedDate = DateTime.now();
  String search = '';

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            AgendaPage(
              store: widget.store,
              professional: professional,
              view: view,
              selectedDate: selectedDate,
              onProfessional: (p) => setState(() => professional = p),
              onDate: (d) => setState(() => selectedDate = d),
              onView: (v) => setState(() => view = v),
            ),
            SearchPage(
              store: widget.store,
              initialQuery: search,
            ),
            ServicesPage(store: widget.store),
            FinancePage(store: widget.store),
            MorePage(
              onView: (v) => setState(() => view = v),
              currentView: view,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.background,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Pesquisar',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa),
            label: 'Serviços',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Financeiro',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'Mais',
          ),
        ],
      ),
    );
  }
}

class AgendaPage extends StatefulWidget {
  final AppStore store;
  final Professional professional;
  final CalendarView view;
  final DateTime selectedDate;
  final ValueChanged<Professional> onProfessional;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<CalendarView> onView;

  const AgendaPage({
    super.key,
    required this.store,
    required this.professional,
    required this.view,
    required this.selectedDate,
    required this.onProfessional,
    required this.onDate,
    required this.onView,
  });

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final ScrollController vertical = ScrollController();
  final double hourHeight = 96;
  DateTime? dragOriginal;
  double dragDelta = 0;
  Appointment? resizing;
  double resizeDelta = 0;

  List<Appointment> get visibleAppointments {
    return widget.store.appointments.where((a) {
      final sameProfessional = widget.professional == Professional.all ||
          a.professional == widget.professional;
      return sameProfessional && _sameDay(a.start, widget.selectedDate);
    }).toList();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateTitle() =>
      DateFormat("dd 'de' MMMM", 'pt_BR').format(widget.selectedDate);

  void _moveDate(int days) {
    widget.onDate(widget.selectedDate.add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _topBar(),
        _professionalTabs(),
        _dateBar(),
        Expanded(child: _calendar()),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Visualização',
            onPressed: () => _viewMenu(context),
            icon: const Icon(Icons.menu_rounded),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'DIOLI',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Pesquisar',
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Hoje',
            onPressed: () => widget.onDate(DateTime.now()),
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
    );
  }

  Widget _professionalTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: [
          _proTab(Professional.giulia),
          const SizedBox(width: 8),
          _proTab(Professional.tuani),
        ],
      ),
    );
  }

  Widget _proTab(Professional p) {
    final selected = widget.professional == p;
    final color = professionalColor(p);
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onProfessional(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            professionalLabel(p),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? color : AppColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _moveDate(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _dateTitle(),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('EEEE', 'pt_BR')
                      .format(widget.selectedDate)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _moveDate(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _calendar() {
    if (widget.view == CalendarView.month) {
      return _monthView();
    }
    final days = widget.view == CalendarView.day
        ? [widget.selectedDate]
        : widget.view == CalendarView.threeDays
            ? List.generate(
                3,
                (i) => widget.selectedDate.add(Duration(days: i)),
              )
            : List.generate(
                7,
                (i) => widget.selectedDate
                    .subtract(Duration(days: widget.selectedDate.weekday - 1))
                    .add(Duration(days: i)),
              );

    if (days.length == 1) return _dayView(days.first);

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: days
                .map((d) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          DateFormat('EEE\n dd/MM', 'pt_BR').format(d),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          SizedBox(
            height: 24 * hourHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: days.map((d) => Expanded(child: _timeline(d))).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayView(DateTime day) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: vertical,
          child: SizedBox(
            height: 24 * hourHeight,
            child: _timeline(day, showLabels: true),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton(
            backgroundColor: AppColors.text,
            foregroundColor: Colors.white,
            onPressed: () => _showAppointmentDialog(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _timeline(DateTime day, {bool showLabels = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (int h = 0; h < 24; h++)
              Positioned(
                top: h * hourHeight,
                left: showLabels ? 60 : 0,
                right: 0,
                child: SizedBox(
                  height: hourHeight,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (showLabels)
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${h.toString().padLeft(2, '0')}:00',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppColors.line,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ...widget.store.appointments
                .where((a) =>
                    a.professional == widget.professional &&
                    _sameDay(a.start, day))
                .map((a) => _appointmentCard(a, showLabels)),
          ],
        );
      },
    );
  }

  Widget _appointmentCard(Appointment a, bool showLabels) {
    final minutes = a.start.hour * 60 + a.start.minute;
    final top = minutes / 60 * hourHeight;
    final height = (a.duration / 60 * hourHeight).clamp(44.0, 24 * hourHeight);
    final left = showLabels ? 64.0 : 4.0;
    final right = 4.0;

    return Positioned(
      top: top,
      left: left,
      right: right,
      height: height.toDouble(),
      child: GestureDetector(
        onTap: () => _showAppointmentDialog(context, existing: a),
        onVerticalDragStart: (_) {
          dragOriginal = a.start;
          dragDelta = 0;
        },
        onVerticalDragUpdate: (details) {
          dragDelta += details.delta.dy;
          final minutesDelta = (dragDelta / hourHeight * 60).round();
          final newStart = _snapTime(
            dragOriginal!.add(Duration(minutes: minutesDelta)),
          );
          final updated = _copyAppointment(a, start: newStart);
          widget.store.updateAppointment(updated);
        },
        onVerticalDragEnd: (_) {
          dragOriginal = null;
          dragDelta = 0;
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: a.color.withOpacity(.17),
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: a.color, width: 4),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.client,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${DateFormat('HH:mm').format(a.start)} • ${a.service}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 12,
                child: GestureDetector(
                  onVerticalDragStart: (_) {
                    resizing = a;
                    resizeDelta = 0;
                  },
                  onVerticalDragUpdate: (details) {
                    if (resizing == null) return;
                    resizeDelta += details.delta.dy;
                    final minutesDelta =
                        (resizeDelta / hourHeight * 60).round();
                    final newDuration =
                        ((a.duration + minutesDelta) / 15).round() * 15;
                    final safe = newDuration.clamp(15, 8 * 60);
                    widget.store.updateAppointment(
                      _copyAppointment(a, duration: safe),
                    );
                  },
                  onVerticalDragEnd: (_) {
                    resizing = null;
                    resizeDelta = 0;
                  },
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: a.color.withOpacity(.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _snapTime(DateTime d) {
    final rounded = ((d.minute / 15).round() * 15);
    var result = DateTime(d.year, d.month, d.day, d.hour, rounded);
    if (rounded == 60) {
      result = DateTime(d.year, d.month, d.day, d.hour + 1);
    }
    return result;
  }

  Appointment _copyAppointment(
    Appointment a, {
    DateTime? start,
    int? duration,
    Color? color,
  }) {
    return Appointment(
      id: a.id,
      client: a.client,
      service: a.service,
      professional: a.professional,
      start: start ?? a.start,
      duration: duration ?? a.duration,
      price: a.price,
      signal: a.signal,
      paymentMethod: a.paymentMethod,
      color: color ?? a.color,
      observation: a.observation,
      status: a.status,
    );
  }

  Widget _monthView() {
    final first = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    final daysInMonth =
        DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0).day;
    final startOffset = first.weekday - 1;
    final cells = startOffset + daysInMonth;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            DateFormat('MMMM yyyy', 'pt_BR').format(widget.selectedDate).toUpperCase(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: .82,
            ),
            itemCount: cells,
            itemBuilder: (context, i) {
              if (i < startOffset) return const SizedBox();
              final day = i - startOffset + 1;
              final date = DateTime(
                widget.selectedDate.year,
                widget.selectedDate.month,
                day,
              );
              final count = widget.store.appointments.where((a) {
                return _sameDay(a.start, date) &&
                    (widget.professional == Professional.all ||
                        a.professional == widget.professional);
              }).length;
              final selected = _sameDay(date, widget.selectedDate);
              return GestureDetector(
                onTap: () {
                  widget.onDate(date);
                  widget.onView(CalendarView.day);
                },
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.text.withOpacity(.08) : AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.text : AppColors.line,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (count > 0) ...[
                        const SizedBox(height: 5),
                        Text(
                          '$count ag.',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _viewMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: CalendarView.values.map((v) {
            final label = switch (v) {
              CalendarView.day => 'Dia',
              CalendarView.threeDays => 'Três dias',
              CalendarView.week => 'Semana',
              CalendarView.month => 'Mês',
            };
            return ListTile(
              leading: Icon(
                v == widget.view ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
              title: Text(label),
              onTap: () {
                Navigator.pop(context);
                widget.onView(v);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showAppointmentDialog(
    BuildContext context, {
    Appointment? existing,
  }) async {
    final client = TextEditingController(text: existing?.client ?? '');
    final obs = TextEditingController(text: existing?.observation ?? '');
    final price = TextEditingController(
      text: existing == null ? '' : existing.price.toStringAsFixed(2),
    );
    final signal = TextEditingController(
      text: existing == null ? '' : existing.signal.toStringAsFixed(2),
    );

    Professional pro = existing?.professional ?? widget.professional;
    ServiceItem? service = widget.store.services.cast<ServiceItem?>().firstWhere(
          (s) => s?.name == existing?.service,
          orElse: () => null,
        );
    DateTime start = existing?.start ??
        DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          9,
          0,
        );
    int duration = existing?.duration ?? service?.duration ?? 30;
    Color color = existing?.color ?? professionalColor(pro);
    String payment = existing?.paymentMethod ?? 'Pix';
    bool signalPaid = (existing?.signal ?? 0) > 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              title: Text(existing == null ? 'Novo agendamento' : 'Editar agendamento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: client,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nome da cliente',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ServiceItem>(
                      value: service,
                      decoration: const InputDecoration(
                        labelText: 'Serviço',
                        prefixIcon: Icon(Icons.spa_outlined),
                      ),
                      items: widget.store.services
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  '${s.name} • R\$ ${s.price.toStringAsFixed(2)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (s) {
                        setLocal(() {
                          service = s;
                          if (s != null) {
                            duration = s.duration;
                            price.text = s.price.toStringAsFixed(2);
                            pro = s.professional;
                            if (existing == null) color = professionalColor(pro);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<Professional>(
                      value: pro,
                      decoration: const InputDecoration(
                        labelText: 'Profissional',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: Professional.giulia,
                          child: Text('GIULIA'),
                        ),
                        DropdownMenuItem(
                          value: Professional.tuani,
                          child: Text('TUANI'),
                        ),
                      ],
                      onChanged: (p) {
                        if (p == null) return;
                        setLocal(() {
                          pro = p;
                          if (existing == null) color = professionalColor(pro);
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data e horário'),
                      subtitle: Text(DateFormat("dd/MM/yyyy • HH:mm").format(start)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: start,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(start),
                        );
                        if (t == null) return;
                        setLocal(() {
                          start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                        });
                      },
                    ),
                    DropdownButtonFormField<int>(
                      value: duration,
                      decoration: const InputDecoration(
                        labelText: 'Duração',
                        prefixIcon: Icon(Icons.schedule_outlined),
                      ),
                      items: [15, 30, 45, 60, 75, 90, 120, 150, 180]
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text('$m minutos'),
                              ))
                          .toList(),
                      onChanged: (m) => setLocal(() => duration = m ?? 30),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor total',
                        prefixText: 'R\$ ',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sinal pago'),
                      value: signalPaid,
                      onChanged: (v) => setLocal(() => signalPaid = v),
                    ),
                    if (signalPaid) ...[
                      TextField(
                        controller: signal,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Valor do sinal',
                          prefixText: 'R\$ ',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: payment,
                        decoration: const InputDecoration(labelText: 'Forma de pagamento'),
                        items: const ['Pix', 'Dinheiro', 'Crédito', 'Débito']
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (p) => setLocal(() => payment = p ?? 'Pix'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Cor do agendamento',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        AppColors.giulia,
                        AppColors.tuani,
                        AppColors.green,
                        AppColors.yellow,
                        AppColors.purple,
                        AppColors.red,
                      ].map((c) {
                        return GestureDetector(
                          onTap: () => setLocal(() => color = c),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color.toARGB32() == c.toARGB32()
                                    ? AppColors.text
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: color.toARGB32() == c.toARGB32()
                                ? const Icon(Icons.check, size: 17, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: obs,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observação',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (existing != null)
                  TextButton(
                    onPressed: () async {
                      await widget.store.deleteAppointment(existing.id);
                      if (context.mounted) Navigator.pop(context, true);
                    },
                    child: const Text(
                      'Excluir',
                      style: TextStyle(color: AppColors.red),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.text,
                  ),
                  onPressed: () async {
                    final total = double.tryParse(price.text.replaceAll(',', '.')) ?? 0;
                    final sig = signalPaid
                        ? (double.tryParse(signal.text.replaceAll(',', '.')) ?? 0)
                        : 0;
                    final a = Appointment(
                      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                      client: client.text.trim(),
                      service: service?.name ?? 'Serviço',
                      professional: pro,
                      start: start,
                      duration: duration,
                      price: total,
                      signal: sig,
                      paymentMethod: signalPaid ? payment : '',
                      color: color,
                      observation: obs.text.trim(),
                      status: existing?.status ?? 'Agendado',
                    );
                    if (existing == null) {
                      await widget.store.addAppointment(a);
                    } else {
                      await widget.store.updateAppointment(a);
                    }
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }
}

class SearchPage extends StatefulWidget {
  final AppStore store;
  final String initialQuery;
  const SearchPage({super.key, required this.store, required this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late TextEditingController controller;
  String query = '';

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialQuery);
    query = widget.initialQuery;
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.store.appointments.where((a) {
      return a.client.toLowerCase().contains(query.toLowerCase()) ||
          a.service.toLowerCase().contains(query.toLowerCase());
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: 'Pesquisar cliente ou serviço',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        setState(() => query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum agendamento encontrado.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final a = results[i];
                    return Card(
                      color: AppColors.card,
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: a.color.withOpacity(.18),
                          child: Icon(Icons.person, color: a.color),
                        ),
                        title: Text(
                          a.client,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${a.service}\n${professionalLabel(a.professional)} • ${DateFormat("dd/MM/yyyy • HH:mm").format(a.start)}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ServicesPage extends StatelessWidget {
  final AppStore store;
  const ServicesPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Serviços'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...store.services.map(
            (s) => Card(
              color: AppColors.card,
              elevation: 0,
              child: ListTile(
                title: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${s.duration} min • ${professionalLabel(s.professional)}',
                ),
                trailing: Text(
                  'R\$ ${s.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => _editService(context, store, s),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.text,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _editService(context, store, null),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar serviço'),
          ),
        ],
      ),
    );
  }

  Future<void> _editService(
    BuildContext context,
    AppStore store,
    ServiceItem? existing,
  ) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final duration = TextEditingController(text: '${existing?.duration ?? 30}');
    final price = TextEditingController(
      text: existing == null ? '' : existing.price.toStringAsFixed(2),
    );
    Professional pro = existing?.professional ?? Professional.giulia;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(existing == null ? 'Novo serviço' : 'Editar serviço'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duração (minutos)'),
                ),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Preço', prefixText: 'R\$ '),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Professional>(
                  value: pro,
                  decoration: const InputDecoration(labelText: 'Profissional'),
                  items: const [
                    DropdownMenuItem(
                      value: Professional.giulia,
                      child: Text('GIULIA'),
                    ),
                    DropdownMenuItem(
                      value: Professional.tuani,
                      child: Text('TUANI'),
                    ),
                  ],
                  onChanged: (p) => setLocal(() => pro = p ?? Professional.giulia),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await store.deleteService(existing.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Excluir', style: TextStyle(color: AppColors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.text),
              onPressed: () async {
                final s = ServiceItem(
                  id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                  name: name.text.trim(),
                  duration: int.tryParse(duration.text) ?? 30,
                  price: double.tryParse(price.text.replaceAll(',', '.')) ?? 0,
                  professional: pro,
                );
                if (existing == null) {
                  await store.addService(s);
                } else {
                  await store.updateService(s);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class FinancePage extends StatelessWidget {
  final AppStore store;
  const FinancePage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final total = store.appointments.fold<double>(0, (s, a) => s + a.price);
    final received = store.appointments.fold<double>(0, (s, a) => s + a.signal);
    final pending = store.appointments.fold<double>(0, (s, a) => s + a.pending);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Financeiro'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _moneyCard('Total agendado', total, AppColors.text),
          _moneyCard('Sinais recebidos', received, AppColors.green),
          _moneyCard('Pendentes', pending, AppColors.yellow),
          const SizedBox(height: 16),
          const Text(
            'Agendamentos',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...store.appointments.map(
            (a) => Card(
              color: AppColors.card,
              elevation: 0,
              child: ListTile(
                title: Text(a.client),
                subtitle: Text(
                  '${professionalLabel(a.professional)} • ${DateFormat("dd/MM • HH:mm").format(a.start)}',
                ),
                trailing: Text(
                  'R\$ ${a.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyCard(String title, double value, Color color) {
    return Card(
      color: AppColors.card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(.13),
              child: Icon(Icons.attach_money, color: color),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(
                  'R\$ ${value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MorePage extends StatelessWidget {
  final ValueChanged<CalendarView> onView;
  final CalendarView currentView;
  const MorePage({
    super.key,
    required this.onView,
    required this.currentView,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mais'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.notifications_none),
            title: Text('Notificações'),
            subtitle: Text('Configurações de notificações'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_view_day_outlined),
            title: const Text('Visualização da agenda'),
            subtitle: Text(_viewName(currentView)),
            onTap: () => _chooseView(context),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('Aparência'),
            subtitle: Text('Fundo bege, visual limpo e minimalista'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Sobre o DIOLI'),
            subtitle: Text('Agenda interna • DIOLI – Studio de Beleza'),
          ),
        ],
      ),
    );
  }

  String _viewName(CalendarView v) {
    switch (v) {
      case CalendarView.day:
        return 'Dia';
      case CalendarView.threeDays:
        return 'Três dias';
      case CalendarView.week:
        return 'Semana';
      case CalendarView.month:
        return 'Mês';
    }
  }

  Future<void> _chooseView(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: CalendarView.values.map((v) {
          return ListTile(
            title: Text(_viewName(v)),
            trailing: v == currentView ? const Icon(Icons.check) : null,
            onTap: () {
              onView(v);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}

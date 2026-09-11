import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jolabuoskpeyhjmpvech.supabase.co',
    publishableKey: 'sb_publishable_85j7PQD-W41JWyLx9xfnpA_ZvH5FW7G',
  );

  await initializeDateFormatting('pt_BR', null);
  final store = AppStore();
  await store.load();
  runApp(DioliApp(store: store));

  // Sincroniza com o Google em segundo plano,
  // sem impedir o aplicativo de abrir.
  store.syncGoogleCalendars();
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
  String? googleEventId;

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
    this.googleEventId,
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
        'googleEventId': googleEventId,
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
        googleEventId: j['googleEventId'],
      );
}


class DioliCalendarBackend {
  static const _baseUrl =
      'https://jolabuoskpeyhjmpvech.supabase.co/functions/v1/dioli-google-calendar';

  // Defina no build:
  // --dart-define=DIOLI_API_KEY=SUA_CHAVE
  static const _apiKey = String.fromEnvironment('DIOLI_API_KEY');

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'x-dioli-api-key': _apiKey,
      };

  static String _professionalName(Professional p) =>
      p == Professional.tuani ? 'TUANI' : 'GIULIA';

  static Future<List<Appointment>> listEvents(
    Professional professional, {
    required DateTime from,
    required DateTime to,
  }) async {
    final uri = Uri.parse('$_baseUrl/events').replace(
      queryParameters: {
        'professional': _professionalName(professional),
        'timeMin': from.toUtc().toIso8601String(),
        'timeMax': to.toUtc().toIso8601String(),
      },
    );

    final res = await http.get(uri, headers: _headers);
    print('GOOGLE AGENDA STATUS: ${res.statusCode}');
    print('GOOGLE AGENDA RESPOSTA: ${res.body}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Erro ao buscar Google Agenda: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['events'] as List? ?? const []);

    return items.map((raw) {
      final e = Map<String, dynamic>.from(raw as Map);
      final start = DateTime.parse(e['start'] as String).toLocal();
      final end = DateTime.parse(e['end'] as String).toLocal();
      final duration = end.difference(start).inMinutes.clamp(30, 8 * 60);

      return Appointment(
        id: 'google_${_professionalName(professional)}_${e['id']}',
        googleEventId: e['id'] as String?,
        client: (e['title'] as String?)?.trim().isNotEmpty == true
            ? (e['title'] as String).trim()
            : 'Compromisso',
        service: (e['title'] as String?)?.trim().isNotEmpty == true
            ? (e['title'] as String).trim()
            : 'Compromisso',
        professional: professional,
        start: start,
        duration: duration,
        price: 0,
        signal: 0,
        paymentMethod: '',
        color: professionalColor(professional),
        observation: (e['description'] as String?) ?? '',
        status: 'Agendado',
      );
    }).toList();
  }

  static Future<Appointment> createEvent(Appointment a) async {
    final uri = Uri.parse('$_baseUrl/events').replace(
      queryParameters: {
        'professional': _professionalName(a.professional),
      },
    );

    final res = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'title': a.client,
        'description': a.observation,
        'start': a.start.toUtc().toIso8601String(),
        'end': a.end.toUtc().toIso8601String(),
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Erro ao criar evento no Google: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final eventId = data['id'] as String?;

    a.googleEventId = eventId;
    if (eventId != null) {
      a.id = 'google_${_professionalName(a.professional)}_$eventId';
    }
    return a;
  }

  static Future<void> updateEvent(Appointment a) async {
    if (a.googleEventId == null || a.googleEventId!.isEmpty) return;

    final uri = Uri.parse(
      '$_baseUrl/events/${Uri.encodeComponent(a.googleEventId!)}',
    ).replace(
      queryParameters: {
        'professional': _professionalName(a.professional),
      },
    );

    final res = await http.patch(
      uri,
      headers: _headers,
      body: jsonEncode({
        'title': a.client,
        'description': a.observation,
        'start': a.start.toUtc().toIso8601String(),
        'end': a.end.toUtc().toIso8601String(),
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Erro ao atualizar evento no Google: ${res.body}');
    }
  }

  static Future<void> deleteEvent(Appointment a) async {
    if (a.googleEventId == null || a.googleEventId!.isEmpty) return;

    final uri = Uri.parse(
      '$_baseUrl/events/${Uri.encodeComponent(a.googleEventId!)}',
    ).replace(
      queryParameters: {
        'professional': _professionalName(a.professional),
      },
    );

    final res = await http.delete(uri, headers: _headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Erro ao excluir evento no Google: ${res.body}');
    }
  }
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
  final Map<String, int> colorOverrides = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final a = prefs.getString('appointments');
    final s = prefs.getString('services');
    final colors = prefs.getString('appointment_color_overrides');
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
    if (colors != null) {
      colorOverrides
        ..clear()
        ..addAll(Map<String, dynamic>.from(jsonDecode(colors)).map(
          (key, value) => MapEntry(key, (value as num).toInt()),
        ));
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
    await prefs.setString(
      'appointment_color_overrides',
      jsonEncode(colorOverrides),
    );
  }

  Future<void> syncGoogleCalendars() async {
    final now = DateTime.now();
    final from = DateTime(now.year - 1, 1, 1);
    final to = DateTime(now.year + 3, 12, 31, 23, 59);

    for (final professional in [
      Professional.giulia,
      Professional.tuani,
    ]) {
      try {
        // Guarda as cores escolhidas manualmente antes de substituir os
        // eventos vindos do Google. Assim a cor não volta ao padrão após
        // atualizar/reiniciar a agenda.
        for (final a in appointments) {
          if (a.professional == professional &&
              a.googleEventId != null &&
              a.googleEventId!.isNotEmpty) {
            colorOverrides[a.googleEventId!] = a.color.toARGB32();
          }
        }

        final remote = await DioliCalendarBackend.listEvents(
          professional,
          from: from,
          to: to,
        );

        for (final a in remote) {
          final savedColor = colorOverrides[a.googleEventId];
          if (savedColor != null) {
            a.color = Color(savedColor);
          }
        }

        appointments.removeWhere(
          (a) =>
              a.professional == professional &&
              a.googleEventId != null,
        );
        appointments.addAll(remote);
      } catch (e) {
        print('ERRO SINCRONIZANDO ${professional == Professional.tuani ? 'TUANI' : 'GIULIA'}: $e');
      }
    }

    appointments.sort((a, b) => a.start.compareTo(b.start));
    await save();
    notifyListeners();
  }

  Future<void> addAppointment(Appointment a) async {
    try {
      await DioliCalendarBackend.createEvent(a);
    } catch (_) {
      // Salva localmente mesmo se a internet/Google falhar.
    }

    appointments.add(a);
    await save();
    notifyListeners();
  }

  Future<void> updateAppointment(Appointment a) async {
    final i = appointments.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      appointments[i] = a;
      if (a.googleEventId != null && a.googleEventId!.isNotEmpty) {
        colorOverrides[a.googleEventId!] = a.color.toARGB32();
      }
      await save();
      notifyListeners();
    }
  }

  Future<void> syncAppointment(Appointment a) async {
    try {
      if (a.googleEventId == null) {
        final oldId = a.id;
        await DioliCalendarBackend.createEvent(a);
        final i = appointments.indexWhere((x) => x.id == oldId);
        if (i >= 0) appointments[i] = a;
      } else {
        await DioliCalendarBackend.updateEvent(a);
      }
      await save();
      notifyListeners();
    } catch (_) {
      // A alteração continua salva localmente e poderá ser reenviada depois.
    }
  }

  Future<void> deleteAppointment(String id) async {
    final i = appointments.indexWhere((x) => x.id == id);
    if (i < 0) return;

    final a = appointments[i];
    try {
      await DioliCalendarBackend.deleteEvent(a);
    } catch (_) {
      // Remove localmente mesmo se a conexão estiver temporariamente indisponível.
    }

    appointments.removeAt(i);
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
  Timer? nowTimer;
  int tab = 0;
  Professional professional = Professional.giulia;
  CalendarView view = CalendarView.day;
  DateTime selectedDate = DateTime.now();
  String search = '';
  final GlobalKey<_AgendaPageState> agendaKey = GlobalKey<_AgendaPageState>();

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);

    nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.syncGoogleCalendars();
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _selectTab(int index) {
    setState(() => tab = index);
  }

  void _selectView(CalendarView newView) {
    setState(() => view = newView);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tab == 0
          ? (professional == Professional.giulia
              ? const Color(0xFFEAF3FF)
              : const Color(0xFFFFEEF4))
          : AppColors.background,
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            AgendaPage(
              key: agendaKey,
              store: widget.store,
              professional: professional,
              view: view,
              selectedDate: selectedDate,
              onProfessional: (p) {
                setState(() => professional = p);
                widget.store.syncGoogleCalendars();
              },
              onDate: (d) => setState(() => selectedDate = d),
              onView: _selectView,
            ),
            SearchPage(
              store: widget.store,
              initialQuery: search,
              onBack: () => _selectTab(0),
              onOpenAppointment: (a) async {
                setState(() {
                  selectedDate = a.start;
                  professional = a.professional;
                  view = CalendarView.day;
                });
                await agendaKey.currentState?.showAppointmentDetailsExternally(a);
              },
            ),
            ServicesPage(
              store: widget.store,
              onBack: () => _selectTab(0),
            ),
            MorePage(
              onView: _selectView,
              currentView: view,
              onBack: () => _selectTab(0),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 28, 24, 18),
              child: Text(
                'dioli',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 34,
                  fontFamily: 'BostonAngel',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            _drawerItem(
              icon: Icons.calendar_month_outlined,
              title: 'Agenda',
              selected: tab == 0,
              onTap: () {
                Navigator.pop(context);
                _selectTab(0);
              },
            ),
            _drawerItem(
              icon: Icons.search_rounded,
              title: 'Pesquisar',
              selected: tab == 1,
              onTap: () {
                Navigator.pop(context);
                _selectTab(1);
              },
            ),
            _drawerItem(
              icon: Icons.spa_outlined,
              title: 'Serviços',
              selected: tab == 2,
              onTap: () {
                Navigator.pop(context);
                _selectTab(2);
              },
            ),
            _drawerItem(
              icon: Icons.more_horiz,
              title: 'Mais',
              selected: tab == 3,
              onTap: () {
                Navigator.pop(context);
                _selectTab(3);
              },
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 4, 24, 8),
              child: Text(
                'VISUALIZAÇÃO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.muted,
                ),
              ),
            ),
            _drawerViewItem(
              icon: Icons.view_day_outlined,
              title: 'Dia',
              view: CalendarView.day,
              selected: view == CalendarView.day,
            ),
            _drawerViewItem(
              icon: Icons.view_week_outlined,
              title: 'Três dias',
              view: CalendarView.threeDays,
              selected: view == CalendarView.threeDays,
            ),
            _drawerViewItem(
              icon: Icons.calendar_view_week_outlined,
              title: 'Semana',
              view: CalendarView.week,
              selected: view == CalendarView.week,
            ),
            _drawerViewItem(
              icon: Icons.calendar_month_outlined,
              title: 'Mês',
              view: CalendarView.month,
              selected: view == CalendarView.month,
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 4, 24, 8),
              child: Text(
                'PROFISSIONAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.muted,
                ),
              ),
            ),
            _drawerProfessionalItem(
              title: 'GIULIA',
              color: AppColors.giulia,
              selected: professional == Professional.giulia,
              onTap: () {
                Navigator.pop(context);
                setState(() => professional = Professional.giulia);
                widget.store.syncGoogleCalendars();
              },
            ),
            _drawerProfessionalItem(
              title: 'TUANI',
              color: AppColors.tuani,
              selected: professional == Professional.tuani,
              onTap: () {
                Navigator.pop(context);
                setState(() => professional = Professional.tuani);
                widget.store.syncGoogleCalendars();
              },
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 28),
              leading: const Icon(Icons.today_outlined),
              title: const Text('Ir para hoje'),
              onTap: () {
                Navigator.pop(context);
                setState(() => selectedDate = DateTime.now());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        tileColor: selected
            ? (professional == Professional.giulia
                ? const Color(0xFFDCEAFF)
                : const Color(0xFFFFE1EC))
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: Icon(icon, color: AppColors.text),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.text,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _drawerViewItem({
    required IconData icon,
    required String title,
    required CalendarView view,
    required bool selected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        tileColor: selected ? const Color(0xFFE9E9E9) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: Icon(icon, color: AppColors.text),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.text,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_rounded, size: 20)
            : null,
        onTap: () {
          Navigator.pop(context);
          _selectTab(0);
          _selectView(view);
        },
      ),
    );
  }

  Widget _drawerProfessionalItem({
    required String title,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        tileColor: selected ? color.withOpacity(.12) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: CircleAvatar(
          radius: 10,
          backgroundColor: color,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_rounded, color: color, size: 20)
            : null,
        onTap: onTap,
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
  final double hourHeight = 72;
  DateTime? dragOriginal;
  double dragDelta = 0;
  Appointment? resizing;
  double resizeDelta = 0;

  DateTime? creatingStart;
  DateTime? creatingEnd;
  bool refreshing = false;
  final ScrollController monthScroll = ScrollController();
  Timer? nowTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && vertical.hasClients) {
        vertical.jumpTo(8 * hourHeight);
      }
    });
  }

  @override
  void dispose() {
    vertical.dispose();
    monthScroll.dispose();
    nowTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshGoogle() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      await widget.store.syncGoogleCalendars();
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

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
        if (widget.view != CalendarView.month) _dateBar(),
        Expanded(child: _calendar()),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Row(
        children: [
          Builder(
            builder: (menuContext) => IconButton(
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(menuContext).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'dioli',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontFamily: 'BostonAngel',
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Pesquisar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SearchPage(
                  store: widget.store,
                  initialQuery: '',
                  onOpenAppointment: (a) => _showAppointmentDetails(context, a),
                ),
              ),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Hoje',
            onPressed: () => widget.onDate(DateTime.now()),
            icon: const Icon(Icons.today_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar agenda',
            onPressed: refreshing ? null : _refreshGoogle,
            icon: refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
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
            color: selected ? color : Colors.transparent,
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
              color: selected ? Colors.white : AppColors.muted,
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

    return Scrollbar(
      controller: vertical,
      thumbVisibility: true,
      trackVisibility: true,
      thickness: 7,
      radius: const Radius.circular(8),
      child: SingleChildScrollView(
        controller: vertical,
        physics: const ClampingScrollPhysics(),
        child: Column(
        children: [
          Row(
            children: days
                .map((d) => Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          widget.onDate(d);
                          widget.onView(CalendarView.day);
                        },
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
      ),
    );
  }

  Widget _dayView(DateTime day) {
    const timeColumnWidth = 62.0;

    // A visualização diária usa exatamente o mesmo sistema de rolagem
    // das visualizações de 3 dias e semana. A rolagem fica livre no
    // conteúdo inteiro e a criação acontece somente com pressionar e segurar.
    return Stack(
      children: [
        Scrollbar(
          controller: vertical,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 7,
          radius: const Radius.circular(8),
          child: SingleChildScrollView(
            controller: vertical,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              height: 24 * hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: timeColumnWidth,
                    height: 24 * hourHeight,
                    child: Column(
                      children: List.generate(
                        24,
                        (h) => SizedBox(
                          height: hourHeight,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Text(
                              '${h.toString().padLeft(2, '0')}:00',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _timeline(day)),
                ],
              ),
            ),
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

  DateTime _timeFromOffset(DateTime day, double dy) {
    // Usa blocos de 30 minutos por faixa: tocar no começo da hora
    // (ex.: 14:00) deve iniciar exatamente às 14:00, sem exigir
    // que o toque seja no meio do bloco.
    final minutes = ((dy / hourHeight) * 60 / 30).floor() * 30;
    final safeMinutes = minutes.clamp(0, 23 * 60 + 30);
    return DateTime(
      day.year,
      day.month,
      day.day,
      safeMinutes ~/ 60,
      safeMinutes % 60,
    );
  }

  Widget _timeline(DateTime day, {bool showLabels = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Área livre para criar um novo agendamento.
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Arrastar normalmente fica livre para a rolagem da agenda.
                // Só um pressionar + segurar inicia a criação.
                onLongPressStart: (details) {
                  final start = _timeFromOffset(
                    day,
                    details.localPosition.dy,
                  );

                  setState(() {
                    dragOriginal = start;
                    dragDelta = 0;
                    creatingStart = start;
                    creatingEnd = start.add(
                      const Duration(minutes: 30),
                    );
                  });
                },
                onLongPressMoveUpdate: (details) {
                  if (dragOriginal == null) return;

                  dragDelta = details.offsetFromOrigin.dy;

                  final current = _timeFromOffset(
                    day,
                    (dragOriginal!.hour * 60 +
                            dragOriginal!.minute) /
                        60 *
                        hourHeight +
                        dragDelta,
                  );

                  final start = current.isBefore(dragOriginal!)
                      ? current
                      : dragOriginal!;

                  final end = current.isAfter(dragOriginal!)
                      ? current
                      : dragOriginal!.add(
                          const Duration(minutes: 30),
                        );

                  setState(() {
                    creatingStart = start;
                    creatingEnd = end;
                  });
                },
                onLongPressEnd: (_) {
                  if (dragOriginal == null) return;

                  final start = creatingStart ?? dragOriginal!;
                  final end = creatingEnd ??
                      start.add(const Duration(minutes: 30));

                  final duration =
                      ((end.difference(start).inMinutes / 30)
                                  .round() *
                              30)
                          .clamp(30, 8 * 60);

                  setState(() {
                    dragOriginal = null;
                    dragDelta = 0;
                    creatingStart = null;
                    creatingEnd = null;
                  });

                  _showAppointmentDialog(
                    context,
                    initialStart: start,
                    initialDuration: duration,
                  );
                },
              ),
            ),

            // Linha do horário atual, como no Google Agenda.
            if (_sameDay(day, DateTime.now()))
              Positioned(
                top: ((DateTime.now().hour * 60 + DateTime.now().minute) / 60) * hourHeight,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: professionalColor(widget.professional),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: professionalColor(widget.professional),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (creatingStart != null && creatingEnd != null)
              Positioned(
                top: (creatingStart!.hour * 60 +
                        creatingStart!.minute) /
                    60 *
                    hourHeight,
                left: 4,
                right: 4,
                height: ((creatingEnd!
                                    .difference(creatingStart!)
                                    .inMinutes) /
                                60 *
                            hourHeight)
                        .clamp(44.0, 24 * hourHeight),
                child: IgnorePointer(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: professionalColor(
                        widget.professional,
                      ).withOpacity(.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(
                          color: professionalColor(
                            widget.professional,
                          ),
                          width: 4,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${DateFormat("HH:mm").format(creatingStart!)} – '
                      '${DateFormat("HH:mm").format(creatingEnd!)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: professionalColor(
                          widget.professional,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Linhas da agenda.
            for (int h = 0; h < 24; h++)
              Positioned(
                top: h * hourHeight,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: AppColors.line,
                ),
              ),

            // Agendamentos.
            ...widget.store.appointments
                .where(
                  (a) =>
                      a.professional == widget.professional &&
                      _sameDay(a.start, day),
                )
                .map(
                  (a) => _appointmentCard(
                    a,
                    false,
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _appointmentCard(Appointment a, bool showLabels) {
    final minutes = a.start.hour * 60 + a.start.minute;
    final top = minutes / 60 * hourHeight;
    final height =
        (a.duration / 60 * hourHeight).clamp(34.0, 24 * hourHeight);
    const left = 4.0;
    const right = 4.0;

    return Positioned(
      top: top,
      left: left,
      right: right,
      height: height.toDouble(),
      child: GestureDetector(
        onTap: () => _showAppointmentDetails(context, a),

        // Mover o agendamento agora exige segurar primeiro.
        // Isso evita que uma rolagem acidental altere o horário.
        onLongPressStart: (_) {
          dragOriginal = a.start;
          dragDelta = 0;
          setState(() {});
        },
        onLongPressMoveUpdate: (details) {
          if (dragOriginal == null) return;

          dragDelta = details.offsetFromOrigin.dy;
          final minutesDelta = (dragDelta / hourHeight * 60).round();
          final newStart = _snapTime(
            dragOriginal!.add(Duration(minutes: minutesDelta)),
          );

          final updated = _copyAppointment(a, start: newStart);
          widget.store.updateAppointment(updated);
        },
        onLongPressEnd: (_) async {
          if (dragOriginal == null) return;

          dragOriginal = null;
          dragDelta = 0;

          final current = widget.store.appointments
              .where((x) => x.id == a.id)
              .cast<Appointment?>()
              .firstWhere((x) => x != null, orElse: () => null);

          if (current != null) {
            await widget.store.syncAppointment(current);
          }

          if (mounted) setState(() {});
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
                padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showDetails = constraints.maxHeight >= 30;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.client,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (showDetails && a.signal > 0)
                          Text(
                            'Sinal: R\$ ${a.signal.toStringAsFixed(2).replaceAll('.', ',')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // Alça inferior para aumentar/diminuir a duração.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 14,
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
                        ((a.duration + minutesDelta) / 30).round() * 30;
                    final safe = newDuration.clamp(30, 8 * 60);

                    widget.store.updateAppointment(
                      _copyAppointment(a, duration: safe),
                    );
                  },
                  onVerticalDragEnd: (_) async {
                    resizing = null;
                    resizeDelta = 0;

                    final current = widget.store.appointments
                        .where((x) => x.id == a.id)
                        .cast<Appointment?>()
                        .firstWhere((x) => x != null, orElse: () => null);

                    if (current != null) {
                      await widget.store.syncAppointment(current);
                    }
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
    final rounded = ((d.minute / 30).round() * 30);
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
      googleEventId: a.googleEventId,
    );
  }

  void _moveMonth(int months) {
    final d = widget.selectedDate;
    final target = DateTime(d.year, d.month + months, 1);
    widget.onDate(DateTime(target.year, target.month, 1));
  }

  Widget _monthView() {
    final first = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    final daysInMonth =
        DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0).day;
    final startOffset = first.weekday - 1;
    final cells = startOffset + daysInMonth;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -250) {
          _moveMonth(1);
        } else if (velocity > 250) {
          _moveMonth(-1);
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () => _moveMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'pt_BR')
                        .format(widget.selectedDate)
                        .toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  onPressed: () => _moveMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM']
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Scrollbar(
              controller: monthScroll,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 7,
              radius: const Radius.circular(8),
              child: GridView.builder(
                controller: monthScroll,
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
                        color: selected
                            ? AppColors.text.withOpacity(.08)
                            : AppColors.card,
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
          ),
        ],
      ),
    );
  }

  Future<void> showAppointmentDetailsExternally(Appointment a) async {
    if (!mounted) return;
    await _showAppointmentDetails(context, a);
  }

  Future<void> _showAppointmentDetails(
    BuildContext context,
    Appointment a,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .94,
        child: Material(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Text(
                          'Agendamento',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _showAppointmentDialog(
                            context,
                            existing: a,
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 5,
                    height: 76,
                    decoration: BoxDecoration(
                      color: a.color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    a.client,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _detailRow(
                    Icons.calendar_today_outlined,
                    'Data',
                    DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR')
                        .format(a.start),
                  ),
                  _detailRow(
                    Icons.schedule_outlined,
                    'Horário',
                    '${DateFormat('HH:mm').format(a.start)} – '
                        '${DateFormat('HH:mm').format(a.end)}',
                  ),
                  if (a.signal > 0)
                    _detailRow(
                      Icons.payments_outlined,
                      'Sinal',
                      'R\$ ${a.signal.toStringAsFixed(2).replaceAll('.', ',')}',
                    ),
                  if (a.observation.trim().isNotEmpty)
                    _detailRow(
                      Icons.notes_outlined,
                      'Observação',
                      a.observation.trim(),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.text,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _showAppointmentDialog(
                          context,
                          existing: a,
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar agendamento'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: AppColors.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<TimeOfDay?> _pickTimeWheel(
    BuildContext context,
    TimeOfDay initial,
  ) async {
    DateTime value = DateTime(
      2024,
      1,
      1,
      initial.hour,
      initial.minute,
    );

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          height: 310,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Selecionar horário',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  minuteInterval: 5,
                  initialDateTime: value,
                  onDateTimeChanged: (d) => value = d,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.text,
                    ),
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      TimeOfDay(hour: value.hour, minute: value.minute),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAppointmentDialog(
    BuildContext context, {
    Appointment? existing,
    DateTime? initialStart,
    int? initialDuration,
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
    DateTime start = existing?.start ??
        initialStart ??
        DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          9,
          0,
        );
    final initialEnd = existing?.end ??
        start.add(Duration(minutes: initialDuration ?? 30));
    DateTime end = initialEnd;
    Color color = existing?.color ?? professionalColor(pro);
    String payment = existing?.paymentMethod ?? 'Pix';
    bool signalPaid = (existing?.signal ?? 0) > 0;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Future<void> pickDate() async {
              final d = await showDatePicker(
                context: context,
                locale: const Locale('pt', 'BR'),
                initialDate: start,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                helpText: 'Selecionar data',
                cancelText: 'Cancelar',
                confirmText: 'OK',
              );
              if (d == null) return;
              setLocal(() {
                start = DateTime(d.year, d.month, d.day, start.hour, start.minute);
                end = DateTime(d.year, d.month, d.day, end.hour, end.minute);
              });
            }

            return FractionallySizedBox(
              heightFactor: .96,
              child: Material(
                color: AppColors.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext, false),
                              icon: const Icon(Icons.close),
                            ),
                            Expanded(
                              child: Text(
                                existing == null
                                    ? 'Novo agendamento'
                                    : 'Editar agendamento',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                          child: Column(
                            children: [
                              TextField(
                                controller: client,
                                autofocus: existing == null,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Nome da cliente',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.calendar_today_outlined),
                                title: const Text('Data'),
                                subtitle: Text(
                                  DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR')
                                      .format(start),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: pickDate,
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.schedule_outlined),
                                title: const Text('Hora de início'),
                                subtitle: Text(DateFormat('HH:mm').format(start)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  final t = await _pickTimeWheel(
                                    context,
                                    TimeOfDay.fromDateTime(start),
                                  );
                                  if (t == null) return;
                                  setLocal(() {
                                    start = DateTime(
                                      start.year,
                                      start.month,
                                      start.day,
                                      t.hour,
                                      t.minute,
                                    );
                                    if (!end.isAfter(start)) {
                                      end = start.add(const Duration(minutes: 30));
                                    }
                                  });
                                },
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.schedule_outlined),
                                title: const Text('Hora de término'),
                                subtitle: Text(DateFormat('HH:mm').format(end)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  final t = await _pickTimeWheel(
                                    context,
                                    TimeOfDay.fromDateTime(end),
                                  );
                                  if (t == null) return;
                                  setLocal(() {
                                    end = DateTime(
                                      start.year,
                                      start.month,
                                      start.day,
                                      t.hour,
                                      t.minute,
                                    );
                                  });
                                },
                              ),
                              const Divider(height: 28),
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
                              const SizedBox(height: 18),
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
                              const SizedBox(height: 18),
                              TextField(
                                controller: obs,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Observação',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  if (existing != null)
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.red,
                                        ),
                                        onPressed: () async {
                                          await widget.store.deleteAppointment(existing.id);
                                          if (context.mounted) {
                                            Navigator.pop(sheetContext, true);
                                          }
                                        },
                                        child: const Text('Excluir'),
                                      ),
                                    ),
                                  if (existing != null) const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.text,
                                        padding: const EdgeInsets.symmetric(vertical: 15),
                                      ),
                                      onPressed: () async {
                                        if (!end.isAfter(start)) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('A hora de término deve ser depois da hora de início.'),
                                            ),
                                          );
                                          return;
                                        }
                                        final total = double.tryParse(price.text.replaceAll(',', '.')) ?? 0;
                                        final sig = signalPaid
                                            ? (double.tryParse(signal.text.replaceAll(',', '.')) ?? 0)
                                            : 0;
                                        final duration = end.difference(start).inMinutes;
                                        final a = Appointment(
                                          id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                                          client: client.text.trim(),
                                          service: existing?.service ?? '',
                                          professional: pro,
                                          start: start,
                                          duration: duration.clamp(5, 24 * 60),
                                          price: total,
                                          signal: sig.toDouble(),
                                          paymentMethod: signalPaid ? payment : '',
                                          color: color,
                                          observation: obs.text.trim(),
                                          status: existing?.status ?? 'Agendado',
                                        );
                                        if (existing == null) {
                                          await widget.store.addAppointment(a);
                                        } else {
                                          a.googleEventId = existing.googleEventId;
                                          await widget.store.updateAppointment(a);
                                          await widget.store.syncAppointment(a);
                                        }
                                        if (context.mounted) {
                                          Navigator.pop(sheetContext, true);
                                        }
                                      },
                                      child: const Text('Salvar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
  final VoidCallback? onBack;
  final Future<void> Function(Appointment appointment)? onOpenAppointment;
  const SearchPage({
    super.key,
    required this.store,
    required this.initialQuery,
    this.onBack,
    this.onOpenAppointment,
  });

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
    final q = query.toLowerCase().trim();
    final results = q.isEmpty
        ? <Appointment>[]
        : widget.store.appointments.where((a) {
            return a.client.toLowerCase().contains(q) ||
                a.observation.toLowerCase().contains(q);
          }).toList()
      ..sort((a, b) {
        final now = DateTime.now();
        final aFuture = !a.start.isBefore(now);
        final bFuture = !b.start.isBefore(now);
        if (aFuture && bFuture) return a.start.compareTo(b.start);
        if (!aFuture && !bFuture) return b.start.compareTo(a.start);
        return aFuture ? -1 : 1;
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: widget.onBack ?? () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Pesquisar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Pesquisar cliente ou informação',
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
                          '${professionalLabel(a.professional)} • ${DateFormat("dd/MM/yyyy • HH:mm").format(a.start)}',
                        ),
                        isThreeLine: false,
                        onTap: widget.onOpenAppointment == null
                            ? null
                            : () => widget.onOpenAppointment!(a),
                      ),
                    );
                  },
                ),
        ),
      ],
      ),
    );
  }
}

class ServicesPage extends StatelessWidget {
  final AppStore store;
  final VoidCallback onBack;
  const ServicesPage({super.key, required this.store, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
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
  final VoidCallback onBack;
  const MorePage({
    super.key,
    required this.onView,
    required this.currentView,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              'GOOGLE AGENDA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.muted,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('GIULIA'),
            subtitle: const Text('Sincronização Google configurada'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('TUANI'),
            subtitle: const Text('Sincronização Google configurada'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
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

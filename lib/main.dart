import 'dart:async';

import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api_client.dart';
import 'models/notification_item.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  runApp(const MyApp());
}

final List<NotificationItem> notifications = [];

class _FakeNotificationFormData {
  final String nombre;
  final String monto;
  final String codigoSeguridad;

  _FakeNotificationFormData({
    required this.nombre,
    required this.monto,
    required this.codigoSeguridad,
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool notificationPermission = false;
  bool batteryOptimizationIgnored = false;
  StreamSubscription<dynamic>? _notificationSub;

  static const EventChannel _notificationsChannel = EventChannel(
    'not_yape/notifications',
  );

  static const MethodChannel _notificationAccessChannel = MethodChannel(
    'not_yape/notification_access',
  );

  static const MethodChannel _deviceSettingsChannel = MethodChannel(
    'not_yape/device_settings',
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncNotificationAccess());
    unawaited(_syncBatteryOptimization());
    unawaited(_loadNotificationsFromApi());

    _notificationSub = _notificationsChannel.receiveBroadcastStream().listen(
      (event) {
        if (!mounted) return;
        if (event is! Map) return;

        final map = Map<String, dynamic>.from(event);
        final timestamp = map['timestamp'];

        final montoRaw = (map['monto'] ?? '').toString();
        final monto = montoRaw.replaceFirst(RegExp(r'^\s*S/\s*'), '').trim();

        final item = NotificationItem(
          app: (map['app'] ?? '').toString(),
          nombre: (map['nombre'] ?? '').toString(),
          monto: monto,
          codigoSeguridad: (map['codigoSeguridad'] ?? '').toString(),
          fecha: timestamp is int
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now(),
        );

        setState(() {
          notifications.insert(0, item);
        });

        unawaited(sendNotificationToApi(item));
      },
      onError: (error) {
        debugPrint('Notification stream error: $error');
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncNotificationAccess());
      unawaited(_syncBatteryOptimization());
    }
  }

  Future<void> _syncNotificationAccess() async {
    try {
      final enabled =
          await _notificationAccessChannel.invokeMethod<bool>('isEnabled') ??
          false;
      if (!mounted) return;
      setState(() {
        notificationPermission = enabled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        notificationPermission = false;
      });
    }
  }

  Future<void> _syncBatteryOptimization() async {
    try {
      final ignored =
          await _deviceSettingsChannel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
      if (!mounted) return;
      setState(() {
        batteryOptimizationIgnored = ignored;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        batteryOptimizationIgnored = false;
      });
    }
  }

  String _notificationKey(NotificationItem n) {
    return '${n.app}|${n.nombre}|${n.monto}|${n.codigoSeguridad}|${n.fecha.millisecondsSinceEpoch}';
  }

  Future<void> _loadNotificationsFromApi() async {
    final items = await fetchNotificationsFromApi();
    if (!mounted) return;
    if (items.isEmpty) return;

    setState(() {
      final existingKeys = notifications.map(_notificationKey).toSet();
      for (final n in items) {
        if (existingKeys.add(_notificationKey(n))) {
          notifications.add(n);
        }
      }
      notifications.sort((a, b) => b.fecha.compareTo(a.fecha));
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Abrir pantalla de permisos Android
  Future<void> openNotificationSettings() async {
    const AndroidIntent intent = AndroidIntent(
      action: 'android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS',
    );

    await intent.launch();
  }

  Future<void> _insertFakeNotificationFromForm({
    required String nombre,
    required String monto,
    required String codigoSeguridad,
  }) async {
    final montoNormalized = monto.replaceFirst(RegExp(r'^\s*S/\s*'), '').trim();
    final montoParsed = double.tryParse(montoNormalized.replaceAll(',', '.'));
    final montoFixed = (montoParsed ?? 0).toStringAsFixed(2);

    final item = NotificationItem(
      app: 'Yape',
      nombre: nombre.trim(),
      monto: montoFixed,
      codigoSeguridad: codigoSeguridad.trim(),
      fecha: DateTime.now(),
    );

    if (!mounted) return;
    setState(() {
      notifications.insert(0, item);
    });

    unawaited(sendNotificationToApi(item));
  }

  Future<void> _openFakeNotificationDialog(BuildContext hostContext) async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController();
    final montoController = TextEditingController();
    final codigoController = TextEditingController();

    _FakeNotificationFormData? data;
    try {
      data = await showDialog<_FakeNotificationFormData>(
        context: hostContext,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Enviar prueba (fake)'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Ingresa un nombre';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: montoController,
                      decoration: const InputDecoration(labelText: 'Monto'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final raw = (value ?? '').replaceFirst(
                          RegExp(r'^\s*S/\s*'),
                          '',
                        );
                        final parsed = double.tryParse(
                          raw.trim().replaceAll(',', '.'),
                        );
                        if (parsed == null) return 'Ingresa un monto válido';
                        if (parsed <= 0) return 'El monto debe ser mayor a 0';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: codigoController,
                      decoration: const InputDecoration(
                        labelText: 'Código de seguridad (3 dígitos)',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (!RegExp(r'^\d{3}$').hasMatch(v)) {
                          return 'Debe tener 3 dígitos';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) async {
                        final valid = formKey.currentState?.validate() ?? false;
                        if (!valid) return;
                        Navigator.of(dialogContext).pop(
                          _FakeNotificationFormData(
                            nombre: nombreController.text,
                            monto: montoController.text,
                            codigoSeguridad: codigoController.text,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final valid = formKey.currentState?.validate() ?? false;
                  if (!valid) return;
                  Navigator.of(dialogContext).pop(
                    _FakeNotificationFormData(
                      nombre: nombreController.text,
                      monto: montoController.text,
                      codigoSeguridad: codigoController.text,
                    ),
                  );
                },
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      );
    } finally {
      nombreController.dispose();
      montoController.dispose();
      codigoController.dispose();
    }

    if (data == null) return;
    await _insertFakeNotificationFromForm(
      nombre: data.nombre,
      monto: data.monto,
      codigoSeguridad: data.codigoSeguridad,
    );
  }

  @override
  Widget build(BuildContext context) {
    const pfBlue = Color(0xFF1976D2);
    const pfYellow = Color(0xFFFFC107);
    const pfRed = Color(0xFFE53935);
    const pfInk = Color(0xFF0B0B0F);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: pfBlue,
              brightness: Brightness.light,
            ).copyWith(
              primary: pfBlue,
              secondary: pfYellow,
              error: pfRed,
              surface: Colors.white,
            ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: pfBlue,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0x220B0B0F),
          thickness: 1,
        ),
        textTheme: ThemeData.light().textTheme.copyWith(
          titleLarge: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
          titleMedium: const TextStyle(fontWeight: FontWeight.w800),
          bodyMedium: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: pfBlue,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: pfInk, width: 2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: pfBlue,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return pfBlue;
            return const Color(0xFFB0B4BF);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return pfYellow;
            return const Color(0xFFD8DCE6);
          }),
          trackOutlineColor: const WidgetStatePropertyAll(pfInk),
          trackOutlineWidth: const WidgetStatePropertyAll(1.5),
        ),
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(Color(0xFFE9F1FF)),
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.w900,
            color: pfInk,
          ),
          dataTextStyle: TextStyle(fontWeight: FontWeight.w700, color: pfInk),
          dividerThickness: 1,
        ),
      ),

      home: Scaffold(
        appBar: AppBar(
          title: const Text("Captura de Notificaciones"),
          actions: [
            IconButton(
              onPressed: _loadNotificationsFromApi,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),

        body: Column(
          children: [
            // SWITCH DE PERMISOS
            SwitchListTile(
              title: const Text("Permiso de notificaciones"),

              subtitle: const Text("Activar acceso a notificaciones"),

              value: notificationPermission,

              onChanged: (value) async {
                await openNotificationSettings();
              },
            ),

            SwitchListTile(
              title: const Text("Ejecución en segundo plano"),
              subtitle: const Text("Desactivar optimización de batería"),
              value: batteryOptimizationIgnored,
              onChanged: (value) async {
                if (batteryOptimizationIgnored) {
                  await _deviceSettingsChannel.invokeMethod<void>(
                    'openBatteryOptimizationSettings',
                  );
                } else {
                  await _deviceSettingsChannel.invokeMethod<void>(
                    'requestIgnoreBatteryOptimizations',
                  );
                }
                await _syncBatteryOptimization();
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: Builder(
                  builder: (buttonContext) {
                    return ElevatedButton(
                      onPressed: () =>
                          _openFakeNotificationDialog(buttonContext),
                      child: const Text('Enviar prueba (fake)'),
                    );
                  },
                ),
              ),
            ),

            const Divider(),

            // TABLA
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: pfInk, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x220B0B0F),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("App")),
                            DataColumn(label: Text("Nombre")),
                            DataColumn(label: Text("Monto")),
                            DataColumn(label: Text("Cód. Seguridad")),
                            DataColumn(label: Text("Fecha")),
                          ],
                          rows: notifications.map((n) {
                            return DataRow(
                              cells: [
                                DataCell(Text(n.app)),
                                DataCell(Text(n.nombre)),
                                DataCell(Text(n.monto)),
                                DataCell(Text(n.codigoSeguridad)),
                                DataCell(Text(n.fecha.toString())),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

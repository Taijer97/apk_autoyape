class NotificationItem {
  final String app;
  final String nombre;
  final String monto;
  final String codigoSeguridad;
  final DateTime fecha;

  NotificationItem({
    required this.app,
    required this.nombre,
    required this.monto,
    required this.codigoSeguridad,
    required this.fecha,
  });

  Map<String, dynamic> toJson() {
    return {
      'app': app,
      'nombre': nombre,
      'monto': monto,
      'codigoSeguridad': codigoSeguridad,
      'fecha': fecha.toIso8601String(),
      'timestamp': fecha.millisecondsSinceEpoch,
    };
  }
}

// ============================================================
// BIOSENSE — Health State Model
// Modelo inmutable. Provider + inmutabilidad = 0 bugs de estado.
// ============================================================

enum AlertLevel { estable, vigilancia, preAlerta, alerta, critico }
enum AlertTrend { estable, subiendoLeve, subiendo, bajando, critico }

class ChannelReading {
  final double value;
  final ChannelStatus status;

  const ChannelReading({required this.value, required this.status});

  ChannelReading copyWith({double? value, ChannelStatus? status}) =>
      ChannelReading(
        value: value ?? this.value,
        status: status ?? this.status,
      );
}

enum ChannelStatus { normal, leve, moderado, alto }

class HealthState {
  final double dhsi;
  final double velocity;
  final double jerk;
  final String statusKey;       // 'stable' | 'fatigue' | 'alert' | 'danger'
  final double confidenceLevel; // 0.0 - 1.0
  final int timestamp;
  final ChannelReading hrv;
  final ChannelReading temp;
  final ChannelReading resp;
  final ChannelReading gsr;
  final int cycle;

  const HealthState({
    required this.dhsi,
    required this.velocity,
    required this.jerk,
    required this.statusKey,
    required this.confidenceLevel,
    required this.timestamp,
    required this.hrv,
    required this.temp,
    required this.resp,
    required this.gsr,
    required this.cycle,
  });

  factory HealthState.initial() => HealthState(
        dhsi: 1.0,
        velocity: 0.0,
        jerk: 0.0,
        statusKey: 'stable',
        confidenceLevel: 0.0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hrv:  const ChannelReading(value: 1.0, status: ChannelStatus.normal),
        temp: const ChannelReading(value: 1.0, status: ChannelStatus.normal),
        resp: const ChannelReading(value: 1.0, status: ChannelStatus.normal),
        gsr:  const ChannelReading(value: 1.0, status: ChannelStatus.normal),
        cycle: 0,
      );

  factory HealthState.fromRepository(Map<String, dynamic> data) {
    return HealthState(
      dhsi:       (data['dhsi'] as num).toDouble(),
      velocity:   (data['velocity'] as num).toDouble(),
      jerk:       (data['jerk'] as num).toDouble(),
      statusKey:  data['status_key'] as String,
      confidenceLevel: (data['confidence_level'] as num).toDouble(),
      timestamp:  data['timestamp'] as int,
      hrv:        data['hrv'] as ChannelReading,
      temp:       data['temp'] as ChannelReading,
      resp:       data['resp'] as ChannelReading,
      gsr:        data['gsr'] as ChannelReading,
      cycle:      data['cycle'] as int,
    );
  }

  int get dhsiPercentage => (dhsi * 100).clamp(0, 100).round();

  AlertLevel get level {
    switch (statusKey) {
      case 'fatigue': return AlertLevel.vigilancia;
      case 'alert':   return AlertLevel.preAlerta;
      case 'danger':  return AlertLevel.alerta;
      case 'critical':return AlertLevel.critico;
      default:        return AlertLevel.estable;
    }
  }

  HealthState copyWith({
    double? dhsi,
    double? velocity,
    double? jerk,
    String? statusKey,
    double? confidenceLevel,
    int? timestamp,
    ChannelReading? hrv,
    ChannelReading? temp,
    ChannelReading? resp,
    ChannelReading? gsr,
    int? cycle,
  }) {
    return HealthState(
      dhsi:       dhsi ?? this.dhsi,
      velocity:   velocity ?? this.velocity,
      jerk:       jerk ?? this.jerk,
      statusKey:  statusKey ?? this.statusKey,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      timestamp:  timestamp ?? this.timestamp,
      hrv:  hrv ?? this.hrv,
      temp: temp ?? this.temp,
      resp: resp ?? this.resp,
      gsr:  gsr ?? this.gsr,
      cycle: cycle ?? this.cycle,
    );
  }
}

// ============================================================
// BIOSENSE v1.0 — Event Log (Bitácora Rápida)
// Factor de Confusión: limpieza dinámica de datos
//
// Si BioSense detecta pico de pulso pero el usuario marcó
// "Tomé un espresso", el algoritmo resta ese evento y evalúa
// si DEBAJO de la cafeína sigue habiendo tendencia real.
//
// Eso es Limpieza Dinámica de Datos — superior a cualquier
// reloj comercial que no sabe si el pico fue estrés o café.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Tipos de evento con su factor de confusión conocido
enum EventType {
  cafe,       // ☕ Cafeína: HRV↓, Temp↑, Resp↑ transitorio ~45min
  medicina,   // 💊 Medicación: variable según tipo
  ejercicio,  // 🏃 Ejercicio: todos los canales elevados ~2h
  estres,     // ⚡ Estrés agudo: GSR↑↑, HRV↓, Resp↑
  comida,     // 🍽️ Comida: Temp↑ leve, GSR variable ~1h
  alcohol,    // 🍺 Alcohol: HRV↓↓, Temp↑, Resp↓
  suenoMal,  // 😴 Mal sueño: todos los canales levemente alterados
  dolor,      // 🤕 Dolor físico: GSR↑, Resp↑, HRV↓
}

class BiologicalEvent {
  final EventType type;
  final DateTime timestamp;
  final String note;
  // Factores de confusión conocidos por canal (offset a restar del DHSI)
  final double hrvOffset;
  final double tempOffset;
  final double respOffset;
  final double gsrOffset;
  final int durationMinutes; // Cuánto tiempo dura el efecto

  const BiologicalEvent({
    required this.type,
    required this.timestamp,
    this.note = '',
    required this.hrvOffset,
    required this.tempOffset,
    required this.respOffset,
    required this.gsrOffset,
    required this.durationMinutes,
  });

  bool get isActive =>
      DateTime.now().difference(timestamp).inMinutes < durationMinutes;

  double get remainingFraction {
    final elapsed = DateTime.now().difference(timestamp).inMinutes;
    if (elapsed >= durationMinutes) return 0.0;
    return 1.0 - (elapsed / durationMinutes);
  }

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
    'hrvOffset': hrvOffset,
    'tempOffset': tempOffset,
    'respOffset': respOffset,
    'gsrOffset': gsrOffset,
    'durationMinutes': durationMinutes,
  };

  factory BiologicalEvent.fromJson(Map<String, dynamic> j) => BiologicalEvent(
    type: EventType.values[j['type'] as int],
    timestamp: DateTime.parse(j['timestamp'] as String),
    note: j['note'] as String? ?? '',
    hrvOffset: (j['hrvOffset'] as num).toDouble(),
    tempOffset: (j['tempOffset'] as num).toDouble(),
    respOffset: (j['respOffset'] as num).toDouble(),
    gsrOffset: (j['gsrOffset'] as num).toDouble(),
    durationMinutes: j['durationMinutes'] as int,
  );
}

// ── Definición de factores de confusión por evento
// Basado en literatura fisiológica conocida
BiologicalEvent createEvent(EventType type, {String note = ''}) {
  final now = DateTime.now();
  switch (type) {
    case EventType.cafe:
      return BiologicalEvent(
        type: type, timestamp: now, note: note,
        hrvOffset: -0.06,   // HRV baja por cafeína
        tempOffset:  0.03,  // Temp sube levemente
        respOffset:  0.04,  // Resp sube levemente
        gsrOffset:   0.05,  // GSR sube (estimulante)
        durationMinutes: 45,
      );
    case EventType.ejercicio:
      return BiologicalEvent(
        type: type, timestamp: now, note: note,
        hrvOffset: -0.20,   // HRV baja fuerte durante y post ejercicio
        tempOffset:  0.18,  // Temp sube
        respOffset:  0.25,  // Resp sube fuerte
        gsrOffset:   0.20,  // GSR sube por sudoración
        durationMinutes: 120,
      );
    case EventType.estres:
      return BiologicalEvent(
        type: type, timestamp: now, note: note,
        hrvOffset: -0.12,
        tempOffset:  0.04,
        respOffset:  0.10,
        gsrOffset:   0.18,  // GSR es el marcador principal de estrés
        durationMinutes: 60,
      );
    case EventType.comida:
      return BiologicalEvent(
        type: type, timestamp: now, note: note,
        hrvOffset: -0.03,
        tempOffset:  0.05,  // Efecto termogénico postprandial
        respOffset:  0.02,
        gsrOffset:   0.04,
        durationMinutes: 90,
      );
    case EventType.alcohol:
      return BiologicalEvent(
        type: type, timestamp: now, note: note,
        hrvOffset: -0.15,   // Alcohol reduce HRV significativamente
        tempOffset:  0.08,
        respOffset: -0.03,  // Resp puede bajar
        gsrOffset:   0.06,
        durationMinutes: 180,
      );
    case EventType.suenoMal:
      return BiologicalEvent(
        type: type, timestamp: now, note: note,
        hrvOffset: -0.08,
        tempOffset:  0.03,
        respOffset:  0.05,
        gsrOffset:   0.07,
        durationMinutes: 480, // Efecto dura todo el día
      );
    case EventType.dolor:
      return BiologicalEvent(
        type: type, timestamp: now, note: note,
        hrvOffset: -0.10,
        tempOffset:  0.02,
        respOffset:  0.08,
        gsrOffset:   0.15,
        durationMinutes: 120,
      );
    case EventType.medicina:
      return BiologicalEvent(
        type: type, timestamp: now, note: note,
        hrvOffset: -0.04,   // Variable — conservador
        tempOffset: -0.02,
        respOffset: -0.02,
        gsrOffset:  -0.03,
        durationMinutes: 240,
      );
  }
}

// ── Gestión de la bitácora
class EventLog {
  static const String _key = 'biosense_events';
  List<BiologicalEvent> _events = [];

  List<BiologicalEvent> get events => List.unmodifiable(_events);
  List<BiologicalEvent> get activeEvents =>
      _events.where((e) => e.isActive).toList();

  // ── Carga desde SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_key);
    if (raw != null) {
      final List<dynamic> list = jsonDecode(raw);
      _events = list
          .map((e) => BiologicalEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      // Limpiar eventos muy antiguos (> 24h)
      _events.removeWhere((e) =>
          DateTime.now().difference(e.timestamp).inHours > 24);
    }
  }

  // ── Guardar en SharedPreferences
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key,
        jsonEncode(_events.map((e) => e.toJson()).toList()));
  }

  // ── Añadir evento
  Future<void> addEvent(EventType type, {String note = ''}) async {
    _events.add(createEvent(type, note: note));
    await _save();
  }

  // Desmarcar/quitar un evento activo
  Future<void> removeEvent(EventType type) async {
    _events.removeWhere((e) => e.type == type);
    await _save();
  }

  // Toggle: si ya existe activo lo quita, si no existe lo agrega
  Future<void> toggleEvent(EventType type) async {
    final isActive = _events.any((e) => e.type == type && e.isActive);
    if (isActive) {
      await removeEvent(type);
    } else {
      await addEvent(type);
    }
  }

  bool isActive(EventType type) =>
      _events.any((e) => e.type == type && e.isActive);

  // ── Limpieza dinámica de datos (el factor diferenciador)
  // Calcula el offset total activo que debe restarse al DHSI
  // para eliminar los factores de confusión conocidos
  ConfusionCorrection getActiveCorrection() {
    double hrvCorr = 0, tempCorr = 0, respCorr = 0, gsrCorr = 0;
    final active = activeEvents;

    for (final e in active) {
      final f = e.remainingFraction; // Se desvanece con el tiempo
      hrvCorr  += e.hrvOffset  * f;
      tempCorr += e.tempOffset * f;
      respCorr += e.respOffset * f;
      gsrCorr  += e.gsrOffset  * f;
    }

    return ConfusionCorrection(
      hrv:  hrvCorr,
      temp: tempCorr,
      resp: respCorr,
      gsr:  gsrCorr,
      activeCount: active.length,
      activeLabels: active.map((e) => _eventLabel(e.type)).toList(),
    );
  }

  String _eventLabel(EventType type) {
    switch (type) {
      case EventType.cafe:      return '☕ Café';
      case EventType.medicina:  return '💊 Medicina';
      case EventType.ejercicio: return '🏃 Ejercicio';
      case EventType.estres:    return '⚡ Estrés';
      case EventType.comida:    return '🍽️ Comida';
      case EventType.alcohol:   return '🍺 Alcohol';
      case EventType.suenoMal: return '😴 Mal sueño';
      case EventType.dolor:     return '🤕 Dolor';
    }
  }
}

class ConfusionCorrection {
  final double hrv;
  final double temp;
  final double resp;
  final double gsr;
  final int activeCount;
  final List<String> activeLabels;

  const ConfusionCorrection({
    required this.hrv,
    required this.temp,
    required this.resp,
    required this.gsr,
    required this.activeCount,
    required this.activeLabels,
  });

  bool get hasCorrection => activeCount > 0;
}

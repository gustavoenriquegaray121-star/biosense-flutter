// ============================================================
// BIOSENSE — Localization Manager
// Textos bilingües ES/EN centralizados
// ============================================================

enum AppLanguage { es, en }

class LocalizationManager {
  AppLanguage _current = AppLanguage.es;

  AppLanguage get current => _current;
  void setLanguage(AppLanguage lang) => _current = lang;

  static const Map<String, Map<String, String>> _strings = {
    'es': {
      'stable_title':    '🟢😊 ESTABLE',
      'stable_msg':      'Tu cuerpo está funcionando normalmente.',
      'fatigue_title':   '🟡 DESCANSA UN POCO',
      'fatigue_msg':     'Tu cuerpo está comenzando a fatigarse. Tómatelo con calma hoy.',
      'alert_title':     '🟠 CUÍDATE HOY',
      'alert_msg':       'Hay cambios importantes. Descansa, toma agua y evita esfuerzos.',
      'danger_title':    '🔴 VE AL MÉDICO',
      'danger_msg':      'Tu cuerpo está mostrando señales de alerta. Consulta a un médico hoy.',
      'critical_title':  '🚨 NECESITAS AYUDA',
      'critical_msg':    'Señales importantes detectadas. Acude con un médico o llama a emergencias.',
      'trend_stable':    '🟢 Tu cuerpo sigue estable',
      'trend_leve':      '🟡↗ Tu cuerpo está comenzando a fatigarse',
      'trend_concern':   '🟠↗ Hay señales tempranas. Descansa hoy',
      'trend_falling':   '🟠↘ La fatiga está aumentando',
      'trend_critical':  '🔴 Necesitas atención. No esperes',
      'voice_stable':    'Todo bien. Tu cuerpo está estable.',
      'voice_fatigue':   'Oye, tu cuerpo está un poco cansado. Descansa un momento.',
      'voice_alert':     'Atención. Hay cambios en tu cuerpo. Toma agua y descansa.',
      'voice_danger':    'Alerta. Es importante que veas a un médico hoy.',
      'voice_critical':  'Atención urgente. Por favor busca ayuda médica ahora.',
      'voice_coffee':    'El café te aceleró un poco. Tu base sigue bien. Tranquilo.',
      'guardian_stable': 'está bien 🟢',
      'guardian_fatigue':'necesita descanso 🟡',
      'guardian_alert':  'tiene cambios importantes 🟠 — considera llamarle',
      'guardian_danger': 'necesita atención 🔴 — contáctale ahora',
    },
    'en': {
      'stable_title':    '🟢😊 STABLE',
      'stable_msg':      'Your body is functioning normally.',
      'fatigue_title':   '🟡 REST A LITTLE',
      'fatigue_msg':     'Your body is starting to fatigue. Take it easy today.',
      'alert_title':     '🟠 TAKE CARE TODAY',
      'alert_msg':       'There are significant changes. Rest, hydrate and avoid effort.',
      'danger_title':    '🔴 SEE A DOCTOR',
      'danger_msg':      'Your body is showing warning signs. See a doctor today.',
      'critical_title':  '🚨 YOU NEED HELP',
      'critical_msg':    'Important signals detected. See a doctor or call emergency services.',
      'trend_stable':    '🟢 Your body remains stable',
      'trend_leve':      '🟡↗ Your body is beginning to fatigue',
      'trend_concern':   '🟠↗ Early signs detected. Rest today',
      'trend_falling':   '🟠↘ Fatigue is increasing',
      'trend_critical':  '🔴 You need attention. Do not wait',
      'voice_stable':    'All good. Your body is stable.',
      'voice_fatigue':   'Hey, your body is a little tired. Take a moment to rest.',
      'voice_alert':     'Attention. There are changes in your body. Drink water and rest.',
      'voice_danger':    'Alert. It is important that you see a doctor today.',
      'voice_critical':  'Urgent attention needed. Please seek medical help now.',
      'voice_coffee':    'The coffee spiked things a bit. Your baseline is fine. Relax.',
      'guardian_stable': 'is doing well 🟢',
      'guardian_fatigue':'needs rest 🟡',
      'guardian_alert':  'has important changes 🟠 — consider calling them',
      'guardian_danger': 'needs attention 🔴 — contact them now',
    },
  };

  String t(String key) =>
      _strings[_current.name]?[key] ?? _strings['es']![key] ?? key;

  String tFor(String key, AppLanguage lang) =>
      _strings[lang.name]?[key] ?? _strings['es']![key] ?? key;
}

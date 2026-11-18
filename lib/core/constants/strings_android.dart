part of 'strings.dart';

// Android wording.
//
// Most of the app reads the same on both platforms. What differs is how
// blocking works: on the iPhone through Apple's Screen Time, on Android
// through an accessibility service the user switches on. These classes
// replace the texts that name it; everything else is inherited.
//
// The iPhone-only settings (whose iPhone this is, uninstall protection) are
// not shown on Android, so their texts have no variant here.

class _EnAndroid extends _En {
  @override
  String get privacyPolicyBody =>
      'Unspend stores all data locally on your device. No personal data is collected, transmitted, or shared with third parties.\n\n'
      'Your blocking profiles, settings, and PIN are saved using on-device storage (SharedPreferences and the Android Keystore). '
      'No analytics, tracking, or telemetry is used.\n\n'
      'To block apps, Unspend uses an Android accessibility service. It only learns which app is opened; it cannot read what is on your screen. This information stays on your device.\n\n'
      'You can delete all your data at any time from Settings > Delete All Data.';
  @override
  String get onboardingBody3 =>
      'A blocked app is covered the moment it opens. A PIN and cooldown timer prevent impulsive disabling.';
  @override
  String get authBannerTitle => 'Accessibility access needed';
  @override
  String get authBannerBody =>
      'Unspend can\'t block apps until you switch on its accessibility service.';
  @override
  String get authDeniedHint => 'Switch Unspend on in Settings › Accessibility.';
  @override
  String get onboardingTitle4 => 'Allow Accessibility Access';
  @override
  String get onboardingBody4 =>
      'Unspend uses an Android accessibility service to notice which app you open and block the ones you choose. It can\'t read your screen, and nothing leaves this device.';
  @override
  String get errorNotAuthorized =>
      'Unspend\'s accessibility service is switched off.';
  @override
  String get errorUnavailable =>
      'App blocking is not available on this device.';
}

class _DeAndroid extends _De {
  @override
  String get privacyPolicyBody =>
      'Unspend speichert alle Daten lokal auf deinem Gerät. Es werden keine personenbezogenen Daten erhoben, übermittelt oder an Dritte weitergegeben.\n\n'
      'Deine Blockierprofile, Einstellungen und deine PIN werden im Gerätespeicher (SharedPreferences und Android Keystore) gesichert. '
      'Es werden keine Analyse-, Tracking- oder Telemetriedienste verwendet.\n\n'
      'Zum Blockieren nutzt Unspend einen Android-Bedienungshilfen-Dienst. Er erfährt nur, welche App geöffnet wird; er kann nicht lesen, was auf deinem Bildschirm steht. Diese Information verbleibt auf deinem Gerät.\n\n'
      'Du kannst alle Daten jederzeit unter Einstellungen > Alle Daten löschen entfernen.';
  @override
  String get onboardingBody3 =>
      'Eine blockierte App wird verdeckt, sobald sie sich öffnet. Eine PIN und ein Abkühl-Timer verhindern impulsives Deaktivieren.';
  @override
  String get authBannerTitle => 'Zugriff auf Bedienungshilfen erforderlich';
  @override
  String get authBannerBody =>
      'Unspend kann Apps erst blockieren, wenn du seinen Bedienungshilfen-Dienst einschaltest.';
  @override
  String get authDeniedHint =>
      'Schalte Unspend unter Einstellungen › Bedienungshilfen ein.';
  @override
  String get onboardingTitle4 => 'Bedienungshilfen erlauben';
  @override
  String get onboardingBody4 =>
      'Unspend erkennt mit einem Android-Bedienungshilfen-Dienst, welche App du öffnest, und blockiert die von dir gewählten. Es kann deinen Bildschirm nicht lesen, und nichts verlässt dieses Gerät.';
  @override
  String get errorNotAuthorized =>
      'Der Bedienungshilfen-Dienst von Unspend ist ausgeschaltet.';
  @override
  String get errorUnavailable =>
      'App-Blockierung ist auf diesem Gerät nicht verfügbar.';
}

class _EsAndroid extends _Es {
  @override
  String get privacyPolicyBody =>
      'Unspend almacena todos los datos localmente en tu dispositivo. No se recopilan, transmiten ni comparten datos personales con terceros.\n\n'
      'Tus perfiles de bloqueo, ajustes y PIN se guardan en el almacenamiento del dispositivo (SharedPreferences y el Keystore de Android). '
      'No se utiliza ningún servicio de análisis, rastreo o telemetría.\n\n'
      'Para bloquear apps, Unspend usa un servicio de accesibilidad de Android. Solo sabe qué app se abre; no puede leer lo que hay en tu pantalla. Esta información permanece en tu dispositivo.\n\n'
      'Puedes eliminar todos tus datos en cualquier momento desde Ajustes > Eliminar todos los datos.';
  @override
  String get onboardingBody3 =>
      'Una app bloqueada se cubre en cuanto se abre. Un PIN y un temporizador de espera previenen la desactivación impulsiva.';
  @override
  String get authBannerTitle => 'Se necesita acceso de accesibilidad';
  @override
  String get authBannerBody =>
      'Unspend no puede bloquear apps hasta que actives su servicio de accesibilidad.';
  @override
  String get authDeniedHint => 'Activa Unspend en Ajustes › Accesibilidad.';
  @override
  String get onboardingTitle4 => 'Permite la accesibilidad';
  @override
  String get onboardingBody4 =>
      'Unspend usa un servicio de accesibilidad de Android para saber qué app abres y bloquear las que elijas. No puede leer tu pantalla y nada sale de este dispositivo.';
  @override
  String get errorNotAuthorized =>
      'El servicio de accesibilidad de Unspend está desactivado.';
  @override
  String get errorUnavailable =>
      'El bloqueo de apps no está disponible en este dispositivo.';
}

class _FrAndroid extends _Fr {
  @override
  String get privacyPolicyBody =>
      'Unspend stocke toutes les données localement sur votre appareil. Aucune donnée personnelle n\'est collectée, transmise ou partagée avec des tiers.\n\n'
      'Vos profils de blocage, paramètres et PIN sont enregistrés dans le stockage de l\'appareil (SharedPreferences et le Keystore Android). '
      'Aucun service d\'analyse, de suivi ou de télémétrie n\'est utilisé.\n\n'
      'Pour bloquer des apps, Unspend utilise un service d\'accessibilité Android. Il sait seulement quelle app est ouverte ; il ne peut pas lire ce qui est affiché sur votre écran. Cette information reste sur votre appareil.\n\n'
      'Vous pouvez supprimer toutes vos données à tout moment depuis Réglages > Supprimer toutes les données.';
  @override
  String get onboardingBody3 =>
      'Une app bloquée est masquée dès qu\'elle s\'ouvre. Un PIN et un minuteur de refroidissement empêchent la désactivation impulsive.';
  @override
  String get authBannerTitle => 'Accès à l\'accessibilité requis';
  @override
  String get authBannerBody =>
      'Unspend ne peut pas bloquer d\'apps tant que vous n\'activez pas son service d\'accessibilité.';
  @override
  String get authDeniedHint =>
      'Activez Unspend dans Paramètres › Accessibilité.';
  @override
  String get onboardingTitle4 => 'Autoriser l\'accessibilité';
  @override
  String get onboardingBody4 =>
      'Unspend utilise un service d\'accessibilité Android pour savoir quelle app vous ouvrez et bloquer celles que vous choisissez. Il ne peut pas lire votre écran et rien ne quitte cet appareil.';
  @override
  String get errorNotAuthorized =>
      'Le service d\'accessibilité d\'Unspend est désactivé.';
  @override
  String get errorUnavailable =>
      'Le blocage d\'apps n\'est pas disponible sur cet appareil.';
}

class _HrAndroid extends _Hr {
  @override
  String get privacyPolicyBody =>
      'Unspend pohranjuje sve podatke lokalno na tvom uređaju. Nikakvi osobni podaci se ne prikupljaju, prenose ili dijele s trećim stranama.\n\n'
      'Tvoji profili blokiranja, postavke i PIN se pohranjuju pomoću lokalne pohrane (SharedPreferences i Android Keystore). '
      'Ne koriste se nikakve analitike, praćenje ili telemetrija.\n\n'
      'Za blokiranje aplikacija Unspend koristi Androidovu uslugu pristupačnosti. Ona saznaje samo koja se aplikacija otvara; ne može čitati što je na tvom zaslonu. Ta informacija ostaje na tvom uređaju.\n\n'
      'Možeš obrisati sve podatke u bilo kojem trenutku iz Postavki > Obriši sve podatke.';
  @override
  String get onboardingBody3 =>
      'Blokirana aplikacija prekriva se čim se otvori. PIN i tajmer hlađenja sprječavaju impulzivno isključivanje.';
  @override
  String get authBannerTitle => 'Potreban je pristup pristupačnosti';
  @override
  String get authBannerBody =>
      'Unspend ne može blokirati aplikacije dok ne uključiš njegovu uslugu pristupačnosti.';
  @override
  String get authDeniedHint => 'Uključi Unspend u Postavke › Pristupačnost.';
  @override
  String get onboardingTitle4 => 'Dopusti pristupačnost';
  @override
  String get onboardingBody4 =>
      'Unspend koristi Androidovu uslugu pristupačnosti kako bi znao koju aplikaciju otvaraš i blokirao one koje odabereš. Ne može čitati tvoj zaslon i ništa ne napušta ovaj uređaj.';
  @override
  String get errorNotAuthorized =>
      'Unspendova usluga pristupačnosti je isključena.';
  @override
  String get errorUnavailable =>
      'Blokiranje aplikacija nije dostupno na ovom uređaju.';
}

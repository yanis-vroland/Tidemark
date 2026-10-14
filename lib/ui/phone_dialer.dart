import 'package:url_launcher/url_launcher.dart';

/// Ouvre le composeur du téléphone sur un numéro, sans l'appeler (spec 002, CA11).
abstract interface class PhoneDialer {
  /// Vrai si le composeur s'est ouvert ; faux ou exception sinon (CA12).
  Future<bool> dial(String number);
}

/// [PhoneDialer] du téléphone, par `url_launcher` (`tel:`). Aucune donnée envoyée,
/// aucune connexion réseau (RM1).
class UrlLauncherDialer implements PhoneDialer {
  const UrlLauncherDialer();

  @override
  Future<bool> dial(String number) =>
      launchUrl(Uri(scheme: 'tel', path: number));
}

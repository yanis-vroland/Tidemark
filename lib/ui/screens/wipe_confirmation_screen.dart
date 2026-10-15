import 'package:flutter/material.dart';

import '../../wipe/journal_wiper.dart';

/// Confirmation de la suppression totale (glossaire : `WipeConfirmationScreen`,
/// spec 005, CA14 à CA21, CA27) : la personne écrit « SUPPRIMER ».
class WipeConfirmationScreen extends StatefulWidget {
  const WipeConfirmationScreen({
    super.key,
    required this.wiper,
    this.keyMissing = false,
    this.onWiped,
  });

  final JournalWiper wiper;

  /// Ouverte depuis l'écran « clé introuvable » (CA27) : liste et avertissement
  /// adaptés, retour « Retour » au lieu de « Réglages ».
  final bool keyMissing;

  /// Appelé après une suppression réussie ; par défaut, l'app est rouverte par
  /// `AppHost` avec le message de fin (CA18).
  final Future<void> Function()? onWiped;

  @override
  State<WipeConfirmationScreen> createState() => _WipeConfirmationScreenState();
}

class _WipeConfirmationScreenState extends State<WipeConfirmationScreen> {
  @override
  Widget build(BuildContext context) => const Scaffold();
}

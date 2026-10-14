import 'package:tidemark/ui/phone_dialer.dart';

/// Composeur factice : note les numéros demandés ; [succeeds] à faux, ou [error],
/// simulent un téléphone qui ne peut pas lancer d'appel (spec 002, CA12).
class FakePhoneDialer implements PhoneDialer {
  FakePhoneDialer({this.succeeds = true, this.error});

  bool succeeds;
  Object? error;
  final List<String> dialed = [];

  @override
  Future<bool> dial(String number) async {
    dialed.add(number);
    if (error != null) throw error!;
    return succeeds;
  }
}

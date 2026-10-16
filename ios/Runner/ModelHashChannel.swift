import CryptoKit
import Flutter
import Foundation

/// SHA-256 du modèle par la bibliothèque du système (CryptoKit, accélérée par le
/// processeur), pour la vérification avant le premier chargement (ADR-004,
/// option F ; spec 003, CA34 à CA36). Côté Dart : `lib/model/system_file_hasher.dart`,
/// qui garde le calcul Dart en repli. Le calcul tourne sur une file d'arrière-plan,
/// jamais sur le fil principal : l'interface ne se fige pas.
enum ModelHashChannel {
  static let name = "dev.tidemark/model_hash"
  static let method = "sha256OfFile"

  /// Blocs de 4 Mo : peu d'appels, mémoire bornée.
  private static let chunkSize = 4 << 20
  private static let queue = DispatchQueue(label: "dev.tidemark.model_hash", qos: .utility)

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == method else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(FlutterError(code: "bad_arguments", message: nil, details: nil))
        return
      }
      queue.async {
        let reply: Any
        do {
          reply = try sha256(ofFileAt: path)
        } catch {
          // Sans le chemin ni le contenu : le Dart refait le calcul en repli.
          reply = FlutterError(code: "unreadable", message: nil, details: nil)
        }
        DispatchQueue.main.async { result(reply) }
      }
    }
  }

  /// Empreinte en hexadécimal minuscule, lue en flux par blocs de [chunkSize].
  static func sha256(ofFileAt path: String) throws -> String {
    let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    defer { try? handle.close() }
    var hasher = SHA256()
    var done = false
    while !done {
      try autoreleasepool {
        if let data = try handle.read(upToCount: chunkSize), !data.isEmpty {
          hasher.update(data: data)
        } else {
          done = true
        }
      }
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }
}

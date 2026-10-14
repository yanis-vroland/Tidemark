import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeJournalFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Exclut des sauvegardes iCloud et Finder le dossier où Dart range la base chiffrée
  /// (Application Support/tidemark), avant toute écriture (ADR-002, spec 001 CA25).
  private func excludeJournalFromBackup() {
    guard let support = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first else { return }
    var folder = support.appendingPathComponent("tidemark", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? folder.setResourceValues(values)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

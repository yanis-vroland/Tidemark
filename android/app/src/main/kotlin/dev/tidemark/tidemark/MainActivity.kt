package dev.tidemark.tidemark

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.FileInputStream
import java.security.MessageDigest

/// Canal du SHA-256 du modèle (ADR-004, option F ; spec 003, CA34 à CA36). Côté
/// Dart : `lib/model/system_file_hasher.dart`, qui garde le calcul Dart en repli.
private const val MODEL_HASH_CHANNEL = "dev.tidemark/model_hash"
private const val MODEL_HASH_METHOD = "sha256OfFile"

/// Blocs de 4 Mo : peu d'appels, mémoire bornée.
private const val CHUNK_SIZE = 4 shl 20

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // File d'arrière-plan : le calcul ne passe jamais par le fil principal.
        MethodChannel(
            messenger,
            MODEL_HASH_CHANNEL,
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            if (call.method != MODEL_HASH_METHOD) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("bad_arguments", null, null)
                return@setMethodCallHandler
            }
            try {
                result.success(sha256OfFile(path))
            } catch (e: Throwable) {
                // Exception ou Error (mémoire) : toujours une réponse, sans le chemin
                // ni le contenu ; le Dart refait le calcul en repli.
                result.error("unreadable", null, null)
            }
        }
    }
}

/// Empreinte en hexadécimal minuscule, lue en flux par blocs de [CHUNK_SIZE] ;
/// `MessageDigest` passe par le fournisseur du système (Conscrypt).
internal fun sha256OfFile(path: String): String {
    val digest = MessageDigest.getInstance("SHA-256")
    val buffer = ByteArray(CHUNK_SIZE)
    FileInputStream(path).use { input ->
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            digest.update(buffer, 0, read)
        }
    }
    return digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) }
}

package tn.isetbizerte.tp4_alertes

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var resultatPermission: MethodChannel.Result? = null

    private lateinit var canalAlerte: MethodChannel
    private var actionEnAttente: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messager = flutterEngine.dartExecutor.binaryMessenger

        Alertes.creerCanal(this)

        // Étape 1 : canal "alerte/notifier"
        canalAlerte = MethodChannel(messager, "alerte/notifier")
        actionEnAttente = lireAction(intent)

        canalAlerte.setMethodCallHandler { call, result ->
            when (call.method) {
                "demanderPermission" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                        == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        resultatPermission = result
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            REQ_NOTIF
                        )
                    }
                }

                "notifier" -> {
                    val titre = call.argument<String>("titre") ?: "Alerte"
                    val texte = call.argument<String>("texte") ?: ""

                    if (Alertes.autorisee(this)) {
                        result.success(Alertes.afficher(this, titre, texte))
                    } else {
                        result.error(
                            "NOTIF_REFUSEES",
                            "Notifications non autorisées",
                            null
                        )
                    }
                }

                "actionInitiale" -> {
                    result.success(actionEnAttente)
                    actionEnAttente = null
                }

                else -> result.notImplemented()
            }
        }

        // Étape 3 : canal "sync/planifier"
        MethodChannel(messager, "sync/planifier")
            .setMethodCallHandler(Planificateur(this))

        // Étape 4 : canal "service/surveillance"
        MethodChannel(messager, "service/surveillance")
            .setMethodCallHandler(ControleService(this))
    }

    // Application déjà ouverte : Android lui remet le nouvel intent
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        lireAction(intent)?.let {
            canalAlerte.invokeMethod("surAction", it)
        }
    }

    // Extrait l'action d'un intent de notification, et ferme cette notification
    private fun lireAction(intent: Intent?): Map<String, Any?>? {
        val action = intent?.getStringExtra(Alertes.EXTRA_ACTION) ?: return null
        val id = intent.getIntExtra(Alertes.EXTRA_ID, 0)

        Alertes.fermer(this, id)

        return mapOf(
            "action" to action,
            "titre" to intent.getStringExtra(Alertes.EXTRA_TITRE),
            "id" to id
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == REQ_NOTIF) {
            resultatPermission?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            )
            resultatPermission = null
        }
    }

    companion object {
        private const val REQ_NOTIF = 43
    }
}
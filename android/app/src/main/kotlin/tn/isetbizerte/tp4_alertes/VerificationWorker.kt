package tn.isetbizerte.tp4_alertes

import android.content.Context
import android.os.BatteryManager
import android.util.Log
import androidx.work.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

// Le travail : exécuté par Android, sans Flutter, même application fermée
class VerificationWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val seuil = inputData.getInt(CLE_SEUIL, 20)
        val niveau = applicationContext.getSystemService(BatteryManager::class.java)
            .getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)      // en %
        Log.d("TP4", "Vérification : batterie $niveau % (seuil $seuil %)")

        if (niveau <= seuil && Alertes.autorisee(applicationContext)) {
            Alertes.creerCanal(applicationContext)
            Alertes.afficher(applicationContext, "Batterie faible", "Niveau $niveau % (seuil $seuil %)")
        }
        return Result.success()
    }

    companion object {
        const val CLE_SEUIL = "seuil"
        const val NOM = "verification_periodique"
    }
}

// Le canal "sync/planifier" : Flutter programme, teste ou annule la tournée
class Planificateur(context: Context) : MethodChannel.MethodCallHandler {

    private val workManager = WorkManager.getInstance(context)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val seuil = call.argument<Int>("seuil") ?: 20
        val donnees = workDataOf(VerificationWorker.CLE_SEUIL to seuil)

        when (call.method) {
            "planifier" -> {
                val requete = PeriodicWorkRequestBuilder<VerificationWorker>(15, TimeUnit.MINUTES)
                    .setInputData(donnees)
                    .build()

                workManager.enqueueUniquePeriodicWork(
                    VerificationWorker.NOM,
                    ExistingPeriodicWorkPolicy.UPDATE,
                    requete
                )
                result.success(null)
            }

            "maintenant" -> {
                workManager.enqueue(
                    OneTimeWorkRequestBuilder<VerificationWorker>().setInputData(donnees).build()
                )
                result.success(null)
            }

            "annuler" -> {
                workManager.cancelUniqueWork(VerificationWorker.NOM)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
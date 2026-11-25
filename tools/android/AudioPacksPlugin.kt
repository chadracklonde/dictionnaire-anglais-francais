package com.chadracklonde.dicoenfr

import android.app.Activity
import android.media.AudioAttributes
import android.media.MediaPlayer
import com.google.android.play.core.assetpacks.AssetPackManager
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import com.google.android.play.core.assetpacks.AssetPackState
import com.google.android.play.core.assetpacks.AssetPackStateUpdateListener
import com.google.android.play.core.assetpacks.model.AssetPackStatus
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Packs d'enregistrements audio livrés par Play Asset Delivery, et lecture des fichiers.
 * Canal « dicoenfr/audio_packs » : chemin, statut, telecharger, supprimer, confirmer, jouer.
 * Canal d'événements « dicoenfr/audio_packs/events » : progression des téléchargements.
 * Sans Google Play (APK installé à la main), aucun pack n'est trouvé : l'application se rabat
 * sur la synthèse vocale.
 */
class AudioPacksPlugin(private val activity: Activity, engine: FlutterEngine) {
    private val manager: AssetPackManager? = try {
        AssetPackManagerFactory.getInstance(activity.applicationContext)
    } catch (e: Throwable) {
        null
    }
    private var evenements: EventChannel.EventSink? = null
    private var lecteur: MediaPlayer? = null

    private val ecouteur = AssetPackStateUpdateListener { etat ->
        activity.runOnUiThread { evenements?.success(versMap(etat)) }
    }

    private fun statut(code: Int): String = when (code) {
        AssetPackStatus.PENDING -> "attente"
        AssetPackStatus.DOWNLOADING -> "telechargement"
        AssetPackStatus.TRANSFERRING -> "transfert"
        AssetPackStatus.COMPLETED -> "pret"
        AssetPackStatus.FAILED -> "echec"
        AssetPackStatus.CANCELED -> "annule"
        AssetPackStatus.WAITING_FOR_WIFI -> "wifi"
        AssetPackStatus.NOT_INSTALLED -> "absent"
        AssetPackStatus.REQUIRES_USER_CONFIRMATION -> "confirmation"
        else -> "inconnu"
    }

    private fun versMap(etat: AssetPackState): Map<String, Any> = mapOf(
        "pack" to etat.name(),
        "statut" to statut(etat.status()),
        "telecharge" to etat.bytesDownloaded(),
        "total" to etat.totalBytesToDownload(),
    )

    /** Chemin d'un fichier d'un pack sur le disque ; null s'il n'est pas (encore) disponible. */
    private fun chemin(pack: String, fichier: String): String? {
        val gestionnaire = manager
        try {
            val lieu = gestionnaire?.getPackLocation(pack)
            if (lieu != null) {
                val f = File(lieu.assetsPath(), "audio/$fichier")
                if (f.exists()) return f.absolutePath
            }
        } catch (e: Throwable) {
            // continue avec les assets installés avec l'application
        }
        // Pack livré à l'installation : ses fichiers sont lus comme des assets de l'application.
        return try {
            val cible = File(activity.cacheDir, "audio/$fichier")
            if (!cible.exists()) {
                cible.parentFile?.mkdirs()
                activity.assets.open("audio/$fichier").use { entree ->
                    cible.outputStream().use { sortie -> entree.copyTo(sortie) }
                }
            }
            cible.absolutePath
        } catch (e: Throwable) {
            null
        }
    }

    private fun jouer(chemin: String): Boolean {
        return try {
            lecteur?.release()
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )
            mp.setDataSource(chemin)
            mp.setOnCompletionListener { it.release(); if (lecteur === it) lecteur = null }
            mp.setOnErrorListener { p, _, _ -> p.release(); if (lecteur === p) lecteur = null; true }
            mp.setOnPreparedListener { it.start() }
            lecteur = mp
            mp.prepareAsync()
            true
        } catch (e: Throwable) {
            false
        }
    }

    init {
        MethodChannel(engine.dartExecutor.binaryMessenger, "dicoenfr/audio_packs")
            .setMethodCallHandler { appel, resultat ->
                val pack = appel.argument<String>("pack") ?: ""
                when (appel.method) {
                    "chemin" -> {
                        val fichier = appel.argument<String>("fichier") ?: ""
                        resultat.success(chemin(pack, fichier))
                    }
                    "jouer" -> resultat.success(jouer(appel.argument<String>("chemin") ?: ""))
                    "statut" -> {
                        val gestionnaire = manager
                        if (gestionnaire == null) {
                            resultat.success(mapOf("pack" to pack, "statut" to "indisponible",
                                "telecharge" to 0L, "total" to 0L))
                        } else {
                            gestionnaire.getPackStates(listOf(pack))
                                .addOnSuccessListener { etats ->
                                    val etat = etats.packStates()[pack]
                                    resultat.success(
                                        if (etat != null) versMap(etat)
                                        else mapOf("pack" to pack, "statut" to "absent",
                                            "telecharge" to 0L, "total" to 0L)
                                    )
                                }
                                .addOnFailureListener {
                                    resultat.success(mapOf("pack" to pack, "statut" to "indisponible",
                                        "telecharge" to 0L, "total" to 0L))
                                }
                        }
                    }
                    "telecharger" -> {
                        val gestionnaire = manager
                        if (gestionnaire == null) {
                            resultat.success(false)
                        } else {
                            try {
                                gestionnaire.fetch(listOf(pack))
                                resultat.success(true)
                            } catch (e: Throwable) {
                                resultat.success(false)
                            }
                        }
                    }
                    "supprimer" -> {
                        try {
                            manager?.removePack(pack)
                            resultat.success(true)
                        } catch (e: Throwable) {
                            resultat.success(false)
                        }
                    }
                    "confirmer" -> {
                        try {
                            manager?.showCellularDataConfirmation(activity)
                            resultat.success(true)
                        } catch (e: Throwable) {
                            resultat.success(false)
                        }
                    }
                    else -> resultat.notImplemented()
                }
            }
        EventChannel(engine.dartExecutor.binaryMessenger, "dicoenfr/audio_packs/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    evenements = sink
                    manager?.registerListener(ecouteur)
                }

                override fun onCancel(arguments: Any?) {
                    evenements = null
                    manager?.unregisterListener(ecouteur)
                }
            })
    }
}

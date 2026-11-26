package com.chadracklonde.dicoenfr

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/**
 * Rappel quotidien de révision, entièrement local : une alarme répétée une fois par jour (sans droit
 * d'alarme exacte) qui affiche une notification. Aucune connexion, aucune donnée envoyée.
 * Canal « dicoenfr/rappel » : permission, autorise, planifier(heure, minute), annuler.
 */
object Rappel {
    const val CANAL = "rappel_revision"
    private const val PREFS = "rappel"
    private const val CODE_ALARME = 4101

    private fun intentAlarme(c: Context): PendingIntent {
        val intent = Intent(c, RappelReceiver::class.java)
        val drapeaux = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getBroadcast(c, CODE_ALARME, intent, drapeaux)
    }

    fun planifier(c: Context, heure: Int, minute: Int) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("actif", true).putInt("heure", heure).putInt("minute", minute).apply()
        val gestionnaire = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val alarme = intentAlarme(c)
        gestionnaire.cancel(alarme)
        val quand = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, heure)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        gestionnaire.setInexactRepeating(
            AlarmManager.RTC_WAKEUP, quand.timeInMillis, AlarmManager.INTERVAL_DAY, alarme
        )
    }

    fun annuler(c: Context) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("actif", false).apply()
        (c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(intentAlarme(c))
    }

    /** Après un redémarrage ou une mise à jour : les alarmes sont perdues, on les remet. */
    fun replanifier(c: Context) {
        val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (p.getBoolean("actif", false)) planifier(c, p.getInt("heure", 18), p.getInt("minute", 0))
    }

    fun autorise(c: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        val n = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return n.areNotificationsEnabled()
    }

    fun afficher(c: Context) {
        if (!autorise(c)) return
        val n = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val constructeur: Notification.Builder
        if (Build.VERSION.SDK_INT >= 26) {
            n.createNotificationChannel(
                NotificationChannel(CANAL, "Rappel de révision", NotificationManager.IMPORTANCE_DEFAULT)
            )
            constructeur = Notification.Builder(c, CANAL)
        } else {
            constructeur = Notification.Builder(c)
        }
        val icone = c.resources.getIdentifier("ic_rappel", "drawable", c.packageName)
        constructeur
            .setSmallIcon(if (icone != 0) icone else c.applicationInfo.icon)
            .setContentTitle("Anglais Français")
            .setContentText("C'est l'heure de réviser vos mots.")
            .setAutoCancel(true)
        val ouvrir = c.packageManager.getLaunchIntentForPackage(c.packageName)
        if (ouvrir != null) {
            val drapeaux = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
            constructeur.setContentIntent(PendingIntent.getActivity(c, 0, ouvrir, drapeaux))
        }
        n.notify(4100, constructeur.build())
    }
}

class RappelReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Rappel.afficher(context)
    }
}

class RappelBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Rappel.replanifier(context)
    }
}

class RappelPlugin(private val activity: Activity, engine: FlutterEngine) {
    private var attente: MethodChannel.Result? = null

    init {
        MethodChannel(engine.dartExecutor.binaryMessenger, "dicoenfr/rappel").setMethodCallHandler { appel, resultat ->
            when (appel.method) {
                "autorise" -> resultat.success(Rappel.autorise(activity))
                "permission" -> demanderPermission(resultat)
                "planifier" -> {
                    Rappel.planifier(
                        activity,
                        appel.argument<Int>("heure") ?: 18,
                        appel.argument<Int>("minute") ?: 0
                    )
                    resultat.success(true)
                }
                "annuler" -> {
                    Rappel.annuler(activity)
                    resultat.success(true)
                }
                else -> resultat.notImplemented()
            }
        }
    }

    private fun demanderPermission(resultat: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || Rappel.autorise(activity)) {
            resultat.success(Rappel.autorise(activity))
            return
        }
        attente?.success(false)
        attente = resultat
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), CODE_PERMISSION)
    }

    fun surPermission(code: Int, resultats: IntArray) {
        if (code != CODE_PERMISSION) return
        val accorde = resultats.isNotEmpty() && resultats[0] == PackageManager.PERMISSION_GRANTED
        attente?.success(accorde)
        attente = null
    }

    companion object {
        const val CODE_PERMISSION = 4102
    }
}

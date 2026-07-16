package com.example.not_yape

import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class NotificationService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {

        val packageName = sbn.packageName
        val notification = sbn.notification
        val extras = notification.extras

        val title = extras.getString("android.title")
        val text = extras.getCharSequence("android.text")

        Log.d("NOTIFICATION", "$packageName | $title | $text")
        logLong(
            "NOTIFICATION_RAW",
            buildString {
                appendLine("packageName=$packageName")
                appendLine("id=${sbn.id}")
                appendLine("tag=${sbn.tag}")
                appendLine("postTime=${sbn.postTime}")
                appendLine("isClearable=${sbn.isClearable}")
                appendLine("isOngoing=${sbn.isOngoing}")
                appendLine("key=${sbn.key}")
                appendLine("notification.when=${notification.`when`}")
                appendLine("notification.flags=${notification.flags}")
                appendLine("notification.channelId=${notification.channelId}")
                appendLine("notification.category=${notification.category}")
                appendLine("notification.group=${notification.group}")
                appendLine("notification.sortKey=${notification.sortKey}")
                appendLine("notification.tickerText=${notification.tickerText}")
                appendLine("extrasDump=${dumpExtras(extras)}")
            }
        )

        val yapeData = parseYapePayment(packageName, title, extras)
        if (yapeData != null) {
            NotificationEventEmitter.emit(
                mapOf(
                    "app" to "Yape",
                    "nombre" to yapeData.nombre,
                    "monto" to yapeData.monto,
                    "codigoSeguridad" to yapeData.codigoSeguridad,
                    "timestamp" to sbn.postTime
                )
            )
        }
    }

    private data class YapePayment(
        val nombre: String,
        val monto: String,
        val codigoSeguridad: String
    )

    private fun parseYapePayment(packageName: String, title: String?, extras: Bundle?): YapePayment? {
        if (packageName != "com.bcp.innovacxion.yapeapp") return null
        if (title?.trim() != "Confirmación de Pago") return null

        val body = extras?.getCharSequence("android.bigText")
            ?: extras?.getCharSequence("android.text")
            ?: return null

        val raw = body.toString().trim()

        val regex = Regex(
            pattern = """^(.*?)\s+te envió un pago por\s+S/\s*([0-9]+(?:[.,][0-9]{1,2})?).*?(?:c[oó]d\.?\s*de seguridad\s*es:)\s*([0-9]+)\s*$""",
            option = RegexOption.IGNORE_CASE
        )

        val match = regex.find(raw) ?: return null
        val nombre = match.groupValues[1].trim()
        val monto = match.groupValues[2].trim().replace(",", ".")
        val codigo = match.groupValues[3].trim()

        if (nombre.isEmpty() || codigo.isEmpty()) return null

        return YapePayment(
            nombre = nombre,
            monto = monto,
            codigoSeguridad = codigo
        )
    }

    private fun dumpExtras(extras: Bundle?): String {
        if (extras == null) return "null"
        val keys = extras.keySet().toList().sorted()
        return buildString {
            append("{")
            keys.forEachIndexed { index, key ->
                val value = try {
                    extras.get(key)
                } catch (e: Exception) {
                    "error:${e.javaClass.simpleName}:${e.message}"
                }
                if (index > 0) append(", ")
                append(key)
                append("=")
                append(value?.toString())
                if (value != null) {
                    append("(${value.javaClass.simpleName})")
                }
            }
            append("}")
        }
    }

    private fun logLong(tag: String, message: String) {
        val chunkSize = 3500
        var i = 0
        while (i < message.length) {
            val end = (i + chunkSize).coerceAtMost(message.length)
            Log.d(tag, message.substring(i, end))
            i = end
        }
    }
}

package com.example.digiblock

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Process
import java.util.*
import kotlin.collections.HashMap

class MainActivity: FlutterActivity() {
    private val CHANNEL = "app_usage_stats"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getUsageStats" -> {
                    if (!checkUsageStatsPermission()) {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.error("PERMISSION_DENIED", "Usage access permission required", null)
                        return@setMethodCallHandler
                    }
                    result.success(getAppUsageStats())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getAppUsageStats(): List<Map<String, Any>> {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.add(Calendar.DAY_OF_YEAR, -1) // Get last 24 hours
        val startTime = calendar.timeInMillis

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        val appUsageMap = HashMap<String, Long>()
        val eventMap = HashMap<String, Long>()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val packageName = event.packageName

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    eventMap[packageName] = event.timeStamp
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val startTime = eventMap[packageName]
                    if (startTime != null) {
                        val usageTime = event.timeStamp - startTime
                        appUsageMap[packageName] = (appUsageMap[packageName] ?: 0) + usageTime
                        eventMap.remove(packageName)
                    }
                }
            }
        }

        val packageManager = context.packageManager
        return appUsageMap.map { (packageName, timeInMillis) ->
            try {
                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                val appName = packageManager.getApplicationLabel(appInfo).toString()
                mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                    "timeInMillis" to timeInMillis
                )
            } catch (e: Exception) {
                mapOf(
                    "packageName" to packageName,
                    "appName" to packageName,
                    "timeInMillis" to timeInMillis
                )
            }
        }
    }
}
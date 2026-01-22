package com.lingshichat.paper_whisper_flutter

import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "paper_whisper/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isHarmonyOS" -> {
                    result.success(isHarmonyOS())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    /**
     * 检测当前设备是否为鸿蒙系统
     * 
     * 检测逻辑：
     * 1. 检查 Build.MANUFACTURER 是否为华为
     * 2. 尝试读取 ro.build.version.harmonyos 系统属性
     * 3. 检查 ohos 相关类是否存在
     */
    private fun isHarmonyOS(): Boolean {
        // 1. 首先检查是否为华为设备
        val isHuaweiDevice = Build.MANUFACTURER.equals("HUAWEI", ignoreCase = true) ||
                             Build.BRAND.equals("HUAWEI", ignoreCase = true) ||
                             Build.MANUFACTURER.equals("HONOR", ignoreCase = true) ||
                             Build.BRAND.equals("HONOR", ignoreCase = true)
        
        if (!isHuaweiDevice) {
            return false
        }
        
        // 2. 尝试通过系统属性检测鸿蒙
        try {
            val harmonyVersion = getSystemProperty("hw_sc.build.platform.version")
            if (!harmonyVersion.isNullOrEmpty()) {
                android.util.Log.d("PlatformUtils", "检测到鸿蒙系统: $harmonyVersion")
                return true
            }
        } catch (e: Exception) {
            android.util.Log.w("PlatformUtils", "读取鸿蒙版本失败: ${e.message}")
        }
        
        // 3. 备用检测：尝试检测 ohos 相关类
        try {
            Class.forName("ohos.app.Application")
            android.util.Log.d("PlatformUtils", "检测到 ohos.app.Application 类")
            return true
        } catch (e: ClassNotFoundException) {
            // 类不存在，可能是 EMUI 而非鸿蒙
        }
        
        // 4. 再尝试另一个系统属性
        try {
            val harmonyOs = getSystemProperty("ro.build.version.harmonyos")
            if (!harmonyOs.isNullOrEmpty() && harmonyOs != "0") {
                android.util.Log.d("PlatformUtils", "检测到 HarmonyOS 属性: $harmonyOs")
                return true
            }
        } catch (e: Exception) {
            // 忽略
        }
        
        // 华为设备但未检测到鸿蒙特征，按鸿蒙处理（保守策略）
        // 因为新版华为设备基本都是鸿蒙
        android.util.Log.d("PlatformUtils", "华为设备，保守判定为鸿蒙")
        return true
    }
    
    /**
     * 读取系统属性
     */
    private fun getSystemProperty(key: String): String? {
        return try {
            val clazz = Class.forName("android.os.SystemProperties")
            val method = clazz.getMethod("get", String::class.java)
            method.invoke(null, key) as? String
        } catch (e: Exception) {
            null
        }
    }
}

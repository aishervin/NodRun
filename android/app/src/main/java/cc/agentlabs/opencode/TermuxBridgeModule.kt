package cc.agentlabs.opencode

import android.content.Intent
import android.net.Uri
import com.facebook.react.ReactApplication
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.uimanager.ViewManager

class TermuxBridgeModule(private val context: ReactApplicationContext) : ReactContextBaseJavaModule(context) {
  override fun getName() = "TermuxBridge"

  @ReactMethod
  fun runCommand(command: String, promise: Promise) {
    try {
      val intent = Intent("com.termux.RUN_COMMAND").apply {
        setClassName("com.termux", "com.termux.app.RunCommandService")
        putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash")
        putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-lc", command))
        putExtra("com.termux.RUN_COMMAND_WORKDIR", "/data/data/com.termux/files/home")
        putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
      }
      context.startService(intent)
      promise.resolve(true)
    } catch (error: Exception) {
      promise.reject("TERMUX_BRIDGE_FAILED", error.message ?: "Could not start a Termux command", error)
    }
  }

  @ReactMethod
  fun openTermux(promise: Promise) {
    try {
      val intent = context.packageManager.getLaunchIntentForPackage("com.termux")
      if (intent == null) {
        promise.reject("TERMUX_NOT_INSTALLED", "Install Termux from F-Droid or GitHub first")
        return
      }
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      context.startActivity(intent)
      promise.resolve(true)
    } catch (error: Exception) {
      promise.reject("TERMUX_OPEN_FAILED", error.message ?: "Could not open Termux", error)
    }
  }
}

class TermuxBridgePackage : com.facebook.react.ReactPackage {
  override fun createNativeModules(context: ReactApplicationContext): List<com.facebook.react.bridge.NativeModule> =
    listOf(TermuxBridgeModule(context))

  override fun createViewManagers(context: ReactApplicationContext): List<ViewManager<*, *>> = emptyList()
}

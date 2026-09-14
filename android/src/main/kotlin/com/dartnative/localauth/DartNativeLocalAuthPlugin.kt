package com.dartnative.localauth

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Flutter plugin entry for local_auth_kit.
 *
 * Loads the JNI `.so` and tracks the current [FragmentActivity] via
 * [Application.ActivityLifecycleCallbacks] so [BiometricPrompt] has a host.
 * DartNative's `DartNativeActivity` is an AppCompatActivity.
 */
class DartNativeLocalAuthPlugin : FlutterPlugin {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        LocalAuthHost.attach(binding.applicationContext)
        try {
            System.loadLibrary("local_auth_kit")
        } catch (e: UnsatisfiedLinkError) {
            android.util.Log.e(
                "DNLocalAuth",
                "Failed to load liblocal_auth_kit.so: ${e.message}",
            )
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        LocalAuthHost.detach(binding.applicationContext)
    }
}

internal object LocalAuthHost : Application.ActivityLifecycleCallbacks {
    @Volatile
    var activity: FragmentActivity? = null

    @Volatile
    var applicationContext: Context? = null

    private var registered = false

    fun attach(context: Context) {
        applicationContext = context.applicationContext
        val app = context.applicationContext as? Application ?: return
        if (!registered) {
            app.registerActivityLifecycleCallbacks(this)
            registered = true
        }
    }

    fun detach(context: Context) {
        val app = context.applicationContext as? Application
        if (registered && app != null) {
            app.unregisterActivityLifecycleCallbacks(this)
            registered = false
        }
        activity = null
        applicationContext = null
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        remember(activity)
    }

    override fun onActivityStarted(activity: Activity) {
        remember(activity)
    }

    override fun onActivityResumed(activity: Activity) {
        remember(activity)
    }

    override fun onActivityPaused(activity: Activity) {
        // Keep the last FragmentActivity — BiometricPrompt can still be up.
    }

    override fun onActivityStopped(activity: Activity) {}

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

    override fun onActivityDestroyed(activity: Activity) {
        if (this.activity == activity) {
            this.activity = null
        }
    }

    private fun remember(activity: Activity) {
        if (activity is FragmentActivity) {
            this.activity = activity
        }
    }
}

package com.dartnative.localauth

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.Keep
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

private const val TAG = "DNLocalAuth"

private const val RESULT_SUCCESS = 0
private const val RESULT_USER_CANCELED = 1
private const val RESULT_SYSTEM_CANCELED = 2
private const val RESULT_NOT_AVAILABLE = 3
private const val RESULT_NOT_ENROLLED = 4
private const val RESULT_LOCKED_OUT = 5
private const val RESULT_PERMANENTLY_LOCKED_OUT = 6
private const val RESULT_TIMEOUT = 7
private const val RESULT_PASSCODE_NOT_SET = 8
private const val RESULT_BIOMETRIC_ONLY_NOT_SUPPORTED = 9
private const val RESULT_NO_ACTIVITY = 10
private const val RESULT_UI_UNAVAILABLE = 11
private const val RESULT_ERROR = 12

private const val OPTION_BIOMETRIC_ONLY = 1 shl 0
private const val OPTION_SENSITIVE = 1 shl 1
private const val OPTION_PERSIST = 1 shl 2

private const val BIT_FINGERPRINT = 1 shl 0
private const val BIT_FACE = 1 shl 1
private const val BIT_IRIS = 1 shl 2
private const val BIT_WEAK = 1 shl 3
private const val BIT_STRONG = 1 shl 4

@Volatile private var dispatcherPtr: Long = 0L
@Volatile private var dispatcherGen: Long = 0L

private val mainHandler = Handler(Looper.getMainLooper())

private var prompt: BiometricPrompt? = null
private var persistObserver: DefaultLifecycleObserver? = null
private var persistActivity: FragmentActivity? = null

@Keep
fun setDispatcher(ptr: Long) {
    dispatcherPtr = ptr
    dispatcherGen = nativeIsolateGen()
}

private fun deliver(token: Long, status: Int, raw: String) {
    mainHandler.post {
        if (dispatcherGen != nativeIsolateGen()) return@post
        val ptr = dispatcherPtr
        if (ptr == 0L) return@post
        nativeDeliverAuthResult(ptr, token, status, raw)
    }
}

private external fun nativeIsolateGen(): Long

private external fun nativeDeliverAuthResult(
    ptr: Long,
    token: Long,
    status: Int,
    raw: String,
)

private fun appContext(): Context? =
    LocalAuthHost.activity ?: LocalAuthHost.applicationContext

@Keep
fun isDeviceSupported(): Int {
    val ctx = appContext() ?: return 0
    val bm = BiometricManager.from(ctx)
    val biometric = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK)
    val credential = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        bm.canAuthenticate(BiometricManager.Authenticators.DEVICE_CREDENTIAL)
    } else {
        biometric
    }
    return if (isCapable(biometric) || isCapable(credential)) 1 else 0
}

@Keep
fun canCheckBiometrics(): Int {
    val ctx = appContext() ?: return 0
    val status = BiometricManager.from(ctx)
        .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK)
    return if (
        status == BiometricManager.BIOMETRIC_SUCCESS ||
        status == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED
    ) 1 else 0
}

@Keep
fun availableBiometrics(): Int {
    val ctx = appContext() ?: return 0
    val bm = BiometricManager.from(ctx)
    val weakOk = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK) ==
        BiometricManager.BIOMETRIC_SUCCESS
    val strongOk = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
        BiometricManager.BIOMETRIC_SUCCESS
    if (!weakOk && !strongOk) return 0

    var mask = 0
    val pm = ctx.packageManager
    if (pm.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)) {
        mask = mask or BIT_FINGERPRINT
    }
    if (pm.hasSystemFeature(PackageManager.FEATURE_FACE)) {
        mask = mask or BIT_FACE
    }
    if (pm.hasSystemFeature(PackageManager.FEATURE_IRIS)) {
        mask = mask or BIT_IRIS
    }
    if (weakOk) mask = mask or BIT_WEAK
    if (strongOk) mask = mask or BIT_STRONG
    return mask
}

@Keep
fun authenticate(token: Long, reason: String?, options: Int) {
    if (reason.isNullOrBlank()) {
        deliver(token, RESULT_ERROR, "localizedReason must not be empty")
        return
    }
    mainHandler.post {
        startPrompt(token, reason, options, isRetry = false)
    }
}

@Keep
fun stopAuthentication(): Int {
    val had = prompt != null
    cancelPrompt()
    return if (had) 1 else 0
}

private fun startPrompt(token: Long, reason: String, options: Int, isRetry: Boolean) {
    val activity = LocalAuthHost.activity
    if (activity == null) {
        deliver(token, RESULT_NO_ACTIVITY, "No FragmentActivity attached")
        return
    }

    val biometricOnly = options and OPTION_BIOMETRIC_ONLY != 0
    val persist = options and OPTION_PERSIST != 0
    val sensitive = options and OPTION_SENSITIVE != 0

    val authenticators = if (biometricOnly) {
        BiometricManager.Authenticators.BIOMETRIC_WEAK
    } else {
        BiometricManager.Authenticators.BIOMETRIC_WEAK or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL
    }

    val capability = BiometricManager.from(activity).canAuthenticate(authenticators)
    if (capability == BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE ||
        capability == BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE
    ) {
        deliver(
            token,
            if (biometricOnly) RESULT_BIOMETRIC_ONLY_NOT_SUPPORTED else RESULT_NOT_AVAILABLE,
            "authenticator unavailable",
        )
        return
    }
    if (capability == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED) {
        deliver(
            token,
            if (biometricOnly) RESULT_NOT_ENROLLED else RESULT_PASSCODE_NOT_SET,
            "nothing enrolled",
        )
        return
    }

    cancelPrompt()

    val callback = object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
            clearPersist(activity)
            prompt = null
            deliver(token, RESULT_SUCCESS, "")
        }

        override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
            prompt = null
            val mapped = mapError(errorCode)
            if (persist && mapped == RESULT_SYSTEM_CANCELED && !isRetry) {
                retryWhenResumed(activity, token, reason, options)
                return
            }
            clearPersist(activity)
            deliver(token, mapped, errString.toString())
        }

        override fun onAuthenticationFailed() {
            // Intermediate reject (wrong finger). Prompt stays up.
        }
    }

    val infoBuilder = BiometricPrompt.PromptInfo.Builder()
        .setTitle(reason)
        .setAllowedAuthenticators(authenticators)
        .setConfirmationRequired(sensitive)

    if (biometricOnly) {
        infoBuilder.setNegativeButtonText("Cancel")
    }

    try {
        val next = BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), callback)
        prompt = next
        next.authenticate(infoBuilder.build())
    } catch (e: Exception) {
        Log.w(TAG, "authenticate failed: ${e.message}")
        deliver(token, RESULT_UI_UNAVAILABLE, e.message ?: "prompt failed")
    }
}

private fun retryWhenResumed(
    activity: FragmentActivity,
    token: Long,
    reason: String,
    options: Int,
) {
    clearPersist(activity)
    val observer = object : DefaultLifecycleObserver {
        override fun onResume(owner: LifecycleOwner) {
            clearPersist(activity)
            startPrompt(token, reason, options, isRetry = true)
        }
    }
    persistObserver = observer
    persistActivity = activity
    activity.lifecycle.addObserver(observer)
}

private fun clearPersist(activity: FragmentActivity? = persistActivity) {
    val observer = persistObserver
    if (observer != null && activity != null) {
        activity.lifecycle.removeObserver(observer)
    }
    persistObserver = null
    persistActivity = null
}

private fun cancelPrompt() {
    try {
        prompt?.cancelAuthentication()
    } catch (e: Exception) {
        Log.w(TAG, "cancelAuthentication: ${e.message}")
    }
    prompt = null
    clearPersist()
}

private fun isCapable(status: Int): Boolean =
    status == BiometricManager.BIOMETRIC_SUCCESS ||
        status == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED

private fun mapError(errorCode: Int): Int = when (errorCode) {
    BiometricPrompt.ERROR_USER_CANCELED,
    BiometricPrompt.ERROR_NEGATIVE_BUTTON,
    -> RESULT_USER_CANCELED
    BiometricPrompt.ERROR_CANCELED -> RESULT_SYSTEM_CANCELED
    BiometricPrompt.ERROR_NO_BIOMETRICS -> RESULT_NOT_ENROLLED
    BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> RESULT_PASSCODE_NOT_SET
    BiometricPrompt.ERROR_HW_NOT_PRESENT,
    BiometricPrompt.ERROR_HW_UNAVAILABLE,
    -> RESULT_NOT_AVAILABLE
    BiometricPrompt.ERROR_LOCKOUT -> RESULT_LOCKED_OUT
    BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> RESULT_PERMANENTLY_LOCKED_OUT
    BiometricPrompt.ERROR_TIMEOUT -> RESULT_TIMEOUT
    BiometricPrompt.ERROR_NO_SPACE,
    BiometricPrompt.ERROR_VENDOR,
    BiometricPrompt.ERROR_UNABLE_TO_PROCESS,
    -> RESULT_ERROR
    else -> RESULT_ERROR
}

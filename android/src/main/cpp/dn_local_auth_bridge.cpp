/**
 * dn_local_auth_bridge.cpp — local_auth_kit Android JNI/C bridge.
 *
 * Dart ──[FFI]──► extern "C" DNLocalAuth* ──[JNI]──► Kotlin DNLocalAuthBridgeKt
 */

#include <jni.h>
#include <cstdint>
#include <dlfcn.h>
#include <android/log.h>

#define LOG_TAG "DNLocalAuth"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static JavaVM* g_jvm = nullptr;
static jclass g_bridgeClass = nullptr;
static jmethodID g_isDeviceSupported = nullptr;
static jmethodID g_canCheckBiometrics = nullptr;
static jmethodID g_availableBiometrics = nullptr;
static jmethodID g_authenticate = nullptr;
static jmethodID g_stopAuthentication = nullptr;
static jmethodID g_setDispatcher = nullptr;

static JNIEnv* getEnv() {
    JNIEnv* env = nullptr;
    if (!g_jvm) return nullptr;
    if (g_jvm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK) return nullptr;
    return env;
}

static jmethodID safeGet(JNIEnv* env, jclass cls, const char* name, const char* sig) {
    jmethodID mid = env->GetStaticMethodID(cls, name, sig);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return nullptr;
    }
    return mid;
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* /*reserved*/) {
    g_jvm = vm;
    JNIEnv* env = nullptr;
    if (vm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK) return JNI_ERR;

    jclass cls = env->FindClass("com/dartnative/localauth/DNLocalAuthBridgeKt");
    if (!cls) {
        LOGE("JNI_OnLoad: class DNLocalAuthBridgeKt not found");
        return JNI_ERR;
    }
    g_bridgeClass = (jclass)env->NewGlobalRef(cls);
    env->DeleteLocalRef(cls);

    g_isDeviceSupported = safeGet(env, g_bridgeClass, "isDeviceSupported", "()I");
    g_canCheckBiometrics = safeGet(env, g_bridgeClass, "canCheckBiometrics", "()I");
    g_availableBiometrics = safeGet(env, g_bridgeClass, "availableBiometrics", "()I");
    g_authenticate = safeGet(env, g_bridgeClass, "authenticate", "(JLjava/lang/String;ILjava/lang/String;)V");
    g_stopAuthentication = safeGet(env, g_bridgeClass, "stopAuthentication", "()I");
    g_setDispatcher = safeGet(env, g_bridgeClass, "setDispatcher", "(J)V");

    if (!g_isDeviceSupported || !g_canCheckBiometrics || !g_availableBiometrics ||
        !g_authenticate || !g_stopAuthentication || !g_setDispatcher) {
        LOGE("JNI_OnLoad: missing Kotlin method(s)");
        return JNI_ERR;
    }

    LOGI("JNI_OnLoad OK");
    return JNI_VERSION_1_6;
}

extern "C" __attribute__((visibility("default")))
int32_t DNLocalAuthIsDeviceSupported() {
    JNIEnv* env = getEnv();
    if (!env || !g_bridgeClass || !g_isDeviceSupported) return 0;
    jint r = env->CallStaticIntMethod(g_bridgeClass, g_isDeviceSupported);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return 0;
    }
    return (int32_t)r;
}

extern "C" __attribute__((visibility("default")))
int32_t DNLocalAuthCanCheckBiometrics() {
    JNIEnv* env = getEnv();
    if (!env || !g_bridgeClass || !g_canCheckBiometrics) return 0;
    jint r = env->CallStaticIntMethod(g_bridgeClass, g_canCheckBiometrics);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return 0;
    }
    return (int32_t)r;
}

extern "C" __attribute__((visibility("default")))
int32_t DNLocalAuthGetAvailableBiometrics() {
    JNIEnv* env = getEnv();
    if (!env || !g_bridgeClass || !g_availableBiometrics) return 0;
    jint r = env->CallStaticIntMethod(g_bridgeClass, g_availableBiometrics);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return 0;
    }
    return (int32_t)r;
}

extern "C" __attribute__((visibility("default")))
void DNLocalAuthSetDispatcher(int64_t callbackPtr) {
    JNIEnv* env = getEnv();
    if (!env || !g_bridgeClass || !g_setDispatcher) return;
    env->CallStaticVoidMethod(g_bridgeClass, g_setDispatcher, (jlong)callbackPtr);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" __attribute__((visibility("default")))
void DNLocalAuthAuthenticate(
    int64_t token, const char* reason, int32_t options, const char* messages
) {
    JNIEnv* env = getEnv();
    if (!env || !g_bridgeClass || !g_authenticate) return;
    jstring jReason = reason ? env->NewStringUTF(reason) : nullptr;
    jstring jMessages = messages ? env->NewStringUTF(messages) : nullptr;
    env->CallStaticVoidMethod(
        g_bridgeClass, g_authenticate, (jlong)token, jReason, (jint)options, jMessages
    );
    if (jReason) env->DeleteLocalRef(jReason);
    if (jMessages) env->DeleteLocalRef(jMessages);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" __attribute__((visibility("default")))
int32_t DNLocalAuthStopAuthentication() {
    JNIEnv* env = getEnv();
    if (!env || !g_bridgeClass || !g_stopAuthentication) return 0;
    jint r = env->CallStaticIntMethod(g_bridgeClass, g_stopAuthentication);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return 0;
    }
    return (int32_t)r;
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_dartnative_localauth_DNLocalAuthBridgeKt_nativeIsolateGen(JNIEnv*, jclass) {
    using GenFn = uint64_t (*)();
    static GenFn fn = (GenFn)dlsym(RTLD_DEFAULT, "DN_IsolateGen");
    return fn ? (jlong)fn() : 0;
}

extern "C" JNIEXPORT void JNICALL
Java_com_dartnative_localauth_DNLocalAuthBridgeKt_nativeDeliverAuthResult(
    JNIEnv* env, jclass, jlong ptr, jlong token, jint status, jstring raw
) {
    if (!ptr) return;
    using DispatchFn = void (*)(int64_t, int32_t, const char*);
    const char* c = raw ? env->GetStringUTFChars(raw, nullptr) : nullptr;
    ((DispatchFn)ptr)((int64_t)token, (int32_t)status, c ? c : "");
    if (raw && c) env->ReleaseStringUTFChars(raw, c);
}

package com.valkiriacode.charadeando

import android.annotation.TargetApi
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodChannel

// Herramientas del juego "Letras" (canal "charadeando/voz"): saber si el
// celular reconoce el español sin internet, pedir que descargue el paquete
// de español y silenciar el "bip" que suena cada vez que empieza a escuchar.
class VoiceTools(private val context: Context) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var muted = false

    // Los sonidos del sistema y de notificaciones (donde suena el bip en
    // muchos celulares). La música del juego no se toca.
    private val streams = intArrayOf(AudioManager.STREAM_NOTIFICATION, AudioManager.STREAM_SYSTEM)

    fun handle(method: String, argument: Any?, result: MethodChannel.Result) {
        when (method) {
            "diagnostico" -> diagnose(argument as? String ?: "es-CO", result)
            "descargarIdioma" -> result.success(download(argument as? String ?: "es-CO"))
            "silenciarBip" -> result.success(mute(argument == true))
            else -> result.notImplemented()
        }
    }

    private fun intentFor(language: String) =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            // "es_US" no lo entiende: tiene que ser "es-US".
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language.replace('_', '-'))
        }

    private fun diagnose(language: String, result: MethodChannel.Result) {
        val info = HashMap<String, Any?>()
        info["sdk"] = Build.VERSION.SDK_INT
        info["reconocimiento"] = SpeechRecognizer.isRecognitionAvailable(context)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            info["enCelular"] = false
            result.success(info)
            return
        }
        val onDevice = SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        info["enCelular"] = onDevice
        if (!onDevice || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(info)
            return
        }
        // Desde Android 13 se puede preguntar qué idiomas tiene descargados.
        checkSupport(language, info, result)
    }

    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    private fun checkSupport(language: String, info: HashMap<String, Any?>, result: MethodChannel.Result) {
        try {
            val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            var answered = false
            recognizer.checkRecognitionSupport(
                intentFor(language),
                context.mainExecutor,
                object : RecognitionSupportCallback {
                    override fun onSupportResult(support: RecognitionSupport) {
                        if (answered) return
                        answered = true
                        info["instalados"] = support.installedOnDeviceLanguages
                        info["pendientes"] = support.pendingOnDeviceLanguages
                        info["soportados"] = support.supportedOnDeviceLanguages
                        info["enLinea"] = support.onlineLanguages
                        recognizer.destroy()
                        result.success(info)
                    }

                    override fun onError(error: Int) {
                        if (answered) return
                        answered = true
                        info["error"] = error
                        recognizer.destroy()
                        result.success(info)
                    }
                },
            )
        } catch (e: Exception) {
            info["error"] = e.toString()
            result.success(info)
        }
    }

    // Pide al sistema que descargue el paquete de [language] para reconocer
    // sin internet (Android 13 o más nuevo). El sistema muestra su aviso.
    private fun download(language: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        return downloadModel(language)
    }

    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    private fun downloadModel(language: String): Boolean {
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) return false
        return try {
            val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            recognizer.triggerModelDownload(intentFor(language))
            recognizer.destroy()
            true
        } catch (e: Exception) {
            false
        }
    }

    // Silencia (o vuelve a dejar como estaban) los sonidos del sistema y
    // de notificaciones.
    private fun mute(on: Boolean): Boolean {
        if (on == muted) return true
        return try {
            val direction = if (on) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE
            for (stream in streams) audio.adjustStreamVolume(stream, direction, 0)
            muted = on
            true
        } catch (e: SecurityException) {
            // Con "No molestar" activo, Android no deja cambiar estos sonidos.
            false
        }
    }

    fun release() {
        mute(false)
    }
}

package com.valkiriacode.charadeando

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.hardware.display.DisplayManager
import android.media.MediaRouter
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.Surface
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var tv: TvConnection? = null
    private var screen: ScreenSide? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val connection = TvConnection(this)
        tv = connection
        EventChannel(messenger, "charadeando/tv/conexion").setStreamHandler(connection)
        MethodChannel(messenger, "charadeando/tv").setMethodCallHandler { call, result ->
            when (call.method) {
                "abrirAjustes" -> result.success(openCastSettings())
                "conectado" -> result.success(connection.isConnected())
                "desconectar" -> result.success(stopCasting())
                else -> result.notImplemented()
            }
        }
        // El turno gira solo hacia el lado en que se tenga el celular, aunque
        // el giro automático del sistema esté apagado.
        val pantalla = MethodChannel(messenger, "charadeando/pantalla")
        val side = ScreenSide(this, pantalla)
        screen = side
        pantalla.setMethodCallHandler { call, result ->
            when (call.method) {
                "girarLibre" -> {
                    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                    side.start()
                    result.success(side.current())
                }
                "lado" -> result.success(side.current())
                else -> result.notImplemented()
            }
        }
        // Identificador del celular para los códigos promocionales. Desde
        // Android 8 es fijo por app y celular: sobrevive a desinstalar y
        // reinstalar la app (solo cambia al restablecer de fábrica).
        MethodChannel(messenger, "charadeando/dispositivo").setMethodCallHandler { call, result ->
            when (call.method) {
                "androidId" -> result.success(
                    try {
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    } catch (e: Exception) {
                        null
                    }
                )
                else -> result.notImplemented()
            }
        }
    }

    // Al volver a la app (por ejemplo, después de dejar de duplicar la
    // pantalla desde el menú del sistema) se revisa otra vez el TV.
    override fun onResume() {
        super.onResume()
        tv?.refresh()
    }

    override fun onDestroy() {
        tv?.onCancel(null)
        screen?.stop()
        super.onDestroy()
    }

    // Deja de transmitir a un Chromecast u otra ruta de video. Si no hay
    // una ruta que la app pueda cortar (HDMI, Miracast de algunas marcas),
    // abre la pantalla del sistema para detenerla desde ahí.
    private fun stopCasting(): Boolean {
        try {
            val router = getSystemService(Context.MEDIA_ROUTER_SERVICE) as MediaRouter
            val route = router.getSelectedRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO)
            if (route != router.defaultRoute) {
                router.selectRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO, router.defaultRoute)
                return true
            }
        } catch (e: SecurityException) {
            // El sistema no deja cambiar la ruta desde la app.
        }
        return openCastSettings()
    }

    // Abre la lista de pantallas para transmitir del sistema.
    private fun openCastSettings(): Boolean {
        for (action in listOf(Settings.ACTION_CAST_SETTINGS, "android.settings.WIFI_DISPLAY_SETTINGS")) {
            try {
                startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                // Este celular no tiene esa pantalla; se prueba la siguiente.
            } catch (e: SecurityException) {
                // Algunas marcas la bloquean para otras apps.
            }
        }
        return false
    }
}

// Avisa a Flutter si el celular se está viendo en un televisor: una
// pantalla externa (HDMI, Miracast) o una ruta de video en vivo distinta
// del celular (transmitir pantalla a un Chromecast).
private class TvConnection(context: Context) : EventChannel.StreamHandler {
    private val displays = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val router = context.getSystemService(Context.MEDIA_ROUTER_SERVICE) as MediaRouter
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var last: Boolean? = null

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = refresh()
        override fun onDisplayRemoved(displayId: Int) = refresh()
        override fun onDisplayChanged(displayId: Int) = refresh()
    }

    private val routerCallback = object : MediaRouter.SimpleCallback() {
        override fun onRouteSelected(router: MediaRouter, type: Int, info: MediaRouter.RouteInfo) = refresh()
        override fun onRouteUnselected(router: MediaRouter, type: Int, info: MediaRouter.RouteInfo) = refresh()
        override fun onRouteChanged(router: MediaRouter, info: MediaRouter.RouteInfo) = refresh()
        override fun onRoutePresentationDisplayChanged(router: MediaRouter, info: MediaRouter.RouteInfo) = refresh()
    }

    fun isConnected(): Boolean = connected()

    // Revisa ahora y otra vez un momento después: al dejar de transmitir,
    // algunos celulares avisan antes de que la ruta del sistema cambie, y
    // con una sola revisión el TV quedaba como conectado.
    fun refresh() {
        send()
        main.removeCallbacks(recheck)
        main.postDelayed(recheck, 500)
        main.postDelayed(recheck, 2000)
    }

    private val recheck = Runnable { send() }

    private fun connected(): Boolean {
        if (displays.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).isNotEmpty()) {
            return true
        }
        val route = router.getSelectedRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO)
        return route != router.defaultRoute || route.presentationDisplay != null
    }

    private fun send() {
        val now = connected()
        if (now == last) return
        last = now
        sink?.success(now)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        last = null
        displays.registerDisplayListener(displayListener, main)
        router.addCallback(MediaRouter.ROUTE_TYPE_LIVE_VIDEO, routerCallback)
        send()
    }

    override fun onCancel(arguments: Any?) {
        if (sink == null) return
        main.removeCallbacks(recheck)
        displays.unregisterDisplayListener(displayListener)
        router.removeCallback(routerCallback)
        sink = null
    }
}

// Avisa a Flutter hacia qué lado está girada la pantalla horizontal
// ("izquierda" o "derecha", como landscapeLeft y landscapeRight de
// Flutter). Al girar 180° Android no cambia la configuración, así que se
// escucha la pantalla misma.
private class ScreenSide(context: Context, private val channel: MethodChannel) {
    private val displays = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val windows = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val main = Handler(Looper.getMainLooper())
    private var listening = false
    private var last: String? = null

    private val listener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {
            val now = current() ?: return
            if (now == last) return
            last = now
            channel.invokeMethod("giro", now)
        }
    }

    fun start() {
        last = current()
        if (listening) return
        listening = true
        displays.registerDisplayListener(listener, main)
    }

    fun stop() {
        if (!listening) return
        listening = false
        displays.unregisterDisplayListener(listener)
    }

    // Null si la pantalla está vertical.
    @Suppress("DEPRECATION")
    fun current(): String? {
        val display = windows.defaultDisplay
        val rotation = display.rotation
        val metrics = DisplayMetrics()
        display.getRealMetrics(metrics)
        if (metrics.widthPixels <= metrics.heightPixels) return null
        // En casi todos los celulares la pantalla natural es vertical y la
        // horizontal "izquierda" es girar 90°; en tabletas es la de 0°.
        val upright = rotation == Surface.ROTATION_0 || rotation == Surface.ROTATION_90
        return if (upright) "izquierda" else "derecha"
    }
}

package com.moyue.application

import android.annotation.TargetApi
import android.app.Activity
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsAnimation
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/** Observes a sibling of FlutterView; never replaces Flutter's insets callbacks. */
class EditorKeyboardObserver(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    private val channel = EventChannel(messenger, "com.moyue.application/editor_keyboard")
    private var probe: View? = null

    init {
        channel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        detach()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            events.error("unsupported", "IME animation events require Android 11", null)
            return
        }
        attach(events)
    }

    @TargetApi(Build.VERSION_CODES.R)
    private fun attach(events: EventChannel.EventSink) {
        val parent = activity.findViewById<ViewGroup>(android.R.id.content)
        val observer = View(activity)
        val animations = mutableSetOf<WindowInsetsAnimation>()
        var lastBottom = -1
        var changing = false
        fun publishSettled(insets: WindowInsets?) {
            if (insets == null || animations.isNotEmpty()) return
            val bottom = if (insets.isVisible(WindowInsets.Type.ime())) {
                insets.getInsets(WindowInsets.Type.ime()).bottom
            } else 0
            if (changing || bottom != lastBottom) {
                changing = false
                lastBottom = bottom
                events.success(mapOf("phase" to "settled", "bottom" to bottom))
            }
        }
        observer.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        observer.isFocusable = false
        observer.setWindowInsetsAnimationCallback(object : WindowInsetsAnimation.Callback(
            WindowInsetsAnimation.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE
        ) {
            override fun onPrepare(animation: WindowInsetsAnimation) {
                if (animation.typeMask and WindowInsets.Type.ime() == 0) return
                animations.add(animation)
                if (!changing) {
                    changing = true
                    events.success(mapOf("phase" to "changing"))
                }
            }

            // Android requires this override. No Dart message, work or redraw per frame.
            override fun onProgress(
                insets: WindowInsets,
                runningAnimations: MutableList<WindowInsetsAnimation>,
            ): WindowInsets = insets

            override fun onEnd(animation: WindowInsetsAnimation) {
                if (!animations.remove(animation)) return
                publishSettled(observer.rootWindowInsets)
            }
        })
        observer.setOnApplyWindowInsetsListener { _, insets ->
            // Handles the initial state, rotation and keyboards with animations disabled.
            publishSettled(insets)
            insets
        }
        probe = observer
        parent.addView(observer, 0, ViewGroup.LayoutParams(0, 0))
        observer.requestApplyInsets()
        observer.post {
            if (probe === observer) publishSettled(observer.rootWindowInsets)
        }
    }

    override fun onCancel(arguments: Any?) = detach()

    private fun detach() {
        probe?.let { observer ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                observer.setWindowInsetsAnimationCallback(null)
                observer.setOnApplyWindowInsetsListener(null)
            }
            (observer.parent as? ViewGroup)?.removeView(observer)
        }
        probe = null
    }

    fun dispose() {
        detach()
        channel.setStreamHandler(null)
    }
}

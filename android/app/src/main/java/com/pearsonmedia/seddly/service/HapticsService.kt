package com.pearsonmedia.seddly.service

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView

/**
 * Centralized haptic feedback for Android (US-139). Mirrors iOS HapticsService
 * so both platforms share the same "haptic language" — row taps, confirmations,
 * celebrations all feel identical cross-platform.
 */
object HapticsService {

    @Suppress("DEPRECATION")
    private fun getVibrator(context: Context): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        } else {
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    /** Light tap — row taps, toggles. */
    fun tap(view: View) {
        view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
    }

    /** Selection change — picker/tab switches. */
    fun select(view: View) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
        } else {
            view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
        }
    }

    /** Success — fulfill, save, upgrade completed. */
    fun success(context: Context) {
        val vib = getVibrator(context) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            vib.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_DOUBLE_CLICK))
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vib.vibrate(VibrationEffect.createOneShot(40, VibrationEffect.DEFAULT_AMPLITUDE))
        }
    }

    /** Warning — validation failures, limits reached. */
    fun warning(context: Context) {
        val vib = getVibrator(context) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            vib.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK))
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vib.vibrate(VibrationEffect.createOneShot(55, VibrationEffect.DEFAULT_AMPLITUDE))
        }
    }

    /** Long press — bulk selection enter, contextual menu. */
    fun longPress(view: View) {
        view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
    }

    /** Celebratory double-tap — streak milestones, Pro purchase. */
    fun celebrate(context: Context) {
        val vib = getVibrator(context) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val pattern = longArrayOf(0, 30, 60, 40)
            val amplitudes = intArrayOf(0, 180, 0, 230)
            vib.vibrate(VibrationEffect.createWaveform(pattern, amplitudes, -1))
        }
    }
}

/** Composable helper providing scoped haptic functions. */
@Composable
fun rememberHaptics(): Haptics {
    val view = LocalView.current
    val context = LocalContext.current
    return Haptics(view, context)
}

class Haptics(private val view: View, private val context: Context) {
    fun tap() = HapticsService.tap(view)
    fun select() = HapticsService.select(view)
    fun longPress() = HapticsService.longPress(view)
    fun success() = HapticsService.success(context)
    fun warning() = HapticsService.warning(context)
    fun celebrate() = HapticsService.celebrate(context)
}

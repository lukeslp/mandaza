package com.lukesteuber.mandaza

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.MediaRecorder
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class TiltMonitor(context: Context) : SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor = manager.getDefaultSensor(Sensor.TYPE_GRAVITY)
        ?: manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    var offset by mutableStateOf(Offset.Zero); private set

    fun start() { sensor?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) } }
    fun stop() { manager.unregisterListener(this); offset = Offset.Zero }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    override fun onSensorChanged(event: SensorEvent) {
        val x = (-event.values[0] / SensorManager.GRAVITY_EARTH).coerceIn(-1f, 1f)
        val y = (event.values[1] / SensorManager.GRAVITY_EARTH).coerceIn(-1f, 1f)
        offset = Offset(offset.x * 0.82f + x * 0.18f, offset.y * 0.82f + y * 0.18f)
    }
}

@Suppress("DEPRECATION")
class AudioLevelMonitor {
    private var recorder: MediaRecorder? = null
    private var polling: Job? = null
    var level by mutableFloatStateOf(0f); private set

    fun start() {
        if (recorder != null) return
        val next = runCatching {
            MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.UNPROCESSED)
                setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP)
                setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
                setOutputFile("/dev/null")
                prepare()
                start()
            }
        }.getOrElse {
            level = 0f
            return
        }
        recorder = next
        polling = CoroutineScope(Dispatchers.Main).launch {
            while (isActive) {
                val amplitude = runCatching { next.maxAmplitude }.getOrDefault(0)
                val normalized = (amplitude / 14000f).coerceIn(0f, 1f)
                level = level * 0.72f + normalized * 0.28f
                delay(50)
            }
        }
    }

    fun stop() {
        polling?.cancel(); polling = null
        runCatching { recorder?.stop() }
        recorder?.release(); recorder = null
        level = 0f
    }
}

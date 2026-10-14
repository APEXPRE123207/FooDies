package com.foodies.app.foodies

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.URL
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "foodies/video_transcriber"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "extractWavFromVideoUrl") {
                val videoUrl = call.argument<String>("videoUrl")
                if (videoUrl.isNullOrEmpty()) {
                    result.error("INVALID_URL", "URL is empty", null)
                    return@setMethodCallHandler
                }

                thread {
                    try {
                        val wavFile = convertMp4UrlToWav(videoUrl, cacheDir)
                        runOnUiThread {
                            result.success(wavFile.absolutePath)
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error("WAV_EXTRACTION_FAILED", e.message ?: "Unknown extraction error", null)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun convertMp4UrlToWav(videoUrl: String, cacheDir: File): File {
        val tempMp4 = File.createTempFile("reel_", ".mp4", cacheDir)
        val tempWav = File.createTempFile("audio_", ".wav", cacheDir)

        try {
            // 1. Download MP4
            URL(videoUrl).openStream().use { input ->
                FileOutputStream(tempMp4).use { output -> input.copyTo(output) }
            }

            val extractor = MediaExtractor()
            extractor.setDataSource(tempMp4.absolutePath)

            var audioTrackIndex = -1
            var sampleRate = 16000
            var channelCount = 1
            var format: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val fmt = extractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    format = fmt
                    if (fmt.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        sampleRate = fmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                    if (fmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        channelCount = fmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                    break
                }
            }

            if (audioTrackIndex == -1 || format == null) {
                throw IllegalStateException("No audio track found in media file")
            }

            extractor.selectTrack(audioTrackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: "audio/mp4a-latm"
            val codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val pcmStream = ByteArrayOutputStream()
            val bufferInfo = MediaCodec.BufferInfo()
            var isEOS = false

            while (!isEOS) {
                val inIndex = codec.dequeueInputBuffer(10000)
                if (inIndex >= 0) {
                    val buffer = codec.getInputBuffer(inIndex)!!
                    val sampleSize = extractor.readSampleData(buffer, 0)
                    if (sampleSize < 0) {
                        codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        isEOS = true
                    } else {
                        codec.queueInputBuffer(inIndex, 0, sampleSize, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
                val outIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
                if (outIndex >= 0) {
                    val outBuffer = codec.getOutputBuffer(outIndex)!!
                    val chunk = ByteArray(bufferInfo.size)
                    outBuffer.get(chunk)
                    pcmStream.write(chunk)
                    codec.releaseOutputBuffer(outIndex, false)
                }
            }

            codec.stop()
            codec.release()
            extractor.release()

            val rawPcmBytes = pcmStream.toByteArray()
            // Resample down to 16kHz Mono 16-bit PCM for Whisper if needed
            val final16kHzPcm = if (sampleRate != 16000 || channelCount != 1) {
                resampleTo16kHzMono(rawPcmBytes, sampleRate, channelCount)
            } else {
                rawPcmBytes
            }

            writeWavFile(tempWav, final16kHzPcm, 16000, 1)
            return tempWav
        } finally {
            try {
                if (tempMp4.exists()) tempMp4.delete()
            } catch (_: Exception) {}
        }
    }

    private fun resampleTo16kHzMono(inputBytes: ByteArray, inSampleRate: Int, inChannels: Int): ByteArray {
        val totalSamples = inputBytes.size / (2 * inChannels)
        if (totalSamples == 0) return ByteArray(0)

        // 1. Convert to mono 16-bit short samples
        val monoSamples = ShortArray(totalSamples)
        for (i in 0 until totalSamples) {
            var sum = 0
            for (ch in 0 until inChannels) {
                val idx = (i * inChannels + ch) * 2
                val low = inputBytes[idx].toInt() and 0xFF
                val high = inputBytes[idx + 1].toInt()
                val sample = (high shl 8) or low
                sum += sample.toShort().toInt()
            }
            monoSamples[i] = (sum / inChannels).coerceIn(-32768, 32767).toShort()
        }

        // 2. Resample from inSampleRate to 16000 Hz using linear interpolation
        val targetRate = 16000
        val outSampleCount = ((totalSamples.toLong() * targetRate) / inSampleRate).toInt()
        val outBytes = ByteArray(outSampleCount * 2)

        for (i in 0 until outSampleCount) {
            val srcIdx = (i.toDouble() * inSampleRate / targetRate)
            val idx0 = srcIdx.toInt().coerceIn(0, totalSamples - 1)
            val idx1 = (idx0 + 1).coerceIn(0, totalSamples - 1)
            val frac = srcIdx - idx0

            val sample0 = monoSamples[idx0].toDouble()
            val sample1 = monoSamples[idx1].toDouble()
            val interpolated = (sample0 + frac * (sample1 - sample0)).toInt().coerceIn(-32768, 32767)

            outBytes[i * 2] = (interpolated and 0xFF).toByte()
            outBytes[i * 2 + 1] = ((interpolated shr 8) and 0xFF).toByte()
        }

        return outBytes
    }

    private fun writeWavFile(wavFile: File, pcmBytes: ByteArray, sampleRate: Int, channels: Int) {
        val totalDataLen = pcmBytes.size + 36
        val byteRate = sampleRate * channels * 16 / 8

        FileOutputStream(wavFile).use { out ->
            out.write("RIFF".toByteArray())
            out.write(intToByteArray(totalDataLen), 0, 4)
            out.write("WAVE".toByteArray())
            out.write("fmt ".toByteArray())
            out.write(intToByteArray(16), 0, 4) // SubChunk1Size (16 for PCM)
            out.write(shortToByteArray(1.toShort()), 0, 2) // AudioFormat (1 for PCM)
            out.write(shortToByteArray(channels.toShort()), 0, 2)
            out.write(intToByteArray(sampleRate), 0, 4)
            out.write(intToByteArray(byteRate), 0, 4)
            out.write(shortToByteArray((channels * 16 / 8).toShort()), 0, 2) // BlockAlign
            out.write(shortToByteArray(16.toShort()), 0, 2) // BitsPerSample
            out.write("data".toByteArray())
            out.write(intToByteArray(pcmBytes.size), 0, 4)
            out.write(pcmBytes)
        }
    }

    private fun intToByteArray(i: Int): ByteArray = byteArrayOf(
        (i and 0xff).toByte(),
        ((i shr 8) and 0xff).toByte(),
        ((i shr 16) and 0xff).toByte(),
        ((i shr 24) and 0xff).toByte()
    )

    private fun shortToByteArray(s: Short): ByteArray = byteArrayOf(
        (s.toInt() and 0xff).toByte(),
        ((s.toInt() shr 8) and 0xff).toByte()
    )
}

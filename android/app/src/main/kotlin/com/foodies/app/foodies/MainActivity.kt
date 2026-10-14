package com.foodies.app.foodies

import android.content.Intent
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
    private val CHANNEL = "foodies/video_transcriber"
    private val mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "transcribeVideoUrl") {
                    val videoUrl = call.argument<String>("videoUrl")
                    val language = call.argument<String>("language") ?: "en-IN"
                    if (videoUrl.isNullOrEmpty()) {
                        result.error("INVALID_URL", "Video URL is null or empty", null)
                        return@setMethodCallHandler
                    }
                    transcribeFromVideoUrl(videoUrl, language, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun transcribeFromVideoUrl(
        videoUrl: String,
        language: String,
        channelResult: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            channelResult.error("UNSUPPORTED_SDK", "Requires Android 13 (API 33)+", null)
            return
        }

        mainScope.launch {
            var tempMp4: File? = null
            try {
                // 1. Download the .mp4 video to cache directory on IO thread
                tempMp4 = withContext(Dispatchers.IO) {
                    val file = File.createTempFile("reel_audio_", ".mp4", cacheDir)
                    val connection = (URL(videoUrl).openConnection() as HttpURLConnection).apply {
                        connectTimeout = 10000
                        readTimeout = 15000
                        setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 14)")
                    }
                    connection.inputStream.use { input ->
                        FileOutputStream(file).use { output -> input.copyTo(output) }
                    }
                    file
                }

                // 2. Inspect audio track format (sampleRate & channelCount)
                val audioMeta = withContext(Dispatchers.IO) {
                    getAudioMetadata(tempMp4.absolutePath)
                } ?: throw Exception("No audio track found in video")

                // 3. Create OS Pipe: pipe[0] = Read FD (for SpeechRecognizer), pipe[1] = Write FD (for MediaCodec)
                val pipe = ParcelFileDescriptor.createPipe()
                val readFd = pipe[0]
                val writeFd = pipe[1]

                // 4. Start decoding MP4 audio into the Write FD in the background
                val mp4Path = tempMp4.absolutePath
                val decodeJob = launch(Dispatchers.IO) {
                    decodeMp4AudioToPipe(mp4Path, writeFd)
                }

                // 5. Run Android SpeechRecognizer reading from Read FD on Main Thread
                runSpeechRecognizerOnPipe(
                    readFd = readFd,
                    sampleRate = audioMeta.first,
                    channelCount = audioMeta.second,
                    language = language
                ) { transcript ->
                    decodeJob.cancel()
                    try { readFd.close() } catch (_: Exception) {}
                    tempMp4?.delete()
                    channelResult.success(transcript)
                }

            } catch (e: Exception) {
                tempMp4?.delete()
                channelResult.error("TRANSCRIPTION_FAILED", e.message, null)
            }
        }
    }

    /**
     * Reads sample rate and channel count from the MP4's audio track
     */
    private fun getAudioMetadata(mp4Path: String): Pair<Int, Int>? {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(mp4Path)
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    return Pair(sampleRate, channels)
                }
            }
            return null
        } finally {
            extractor.release()
        }
    }

    /**
     * Decodes AAC/MP4 audio into raw 16-bit PCM bytes and writes them into the pipe
     */
    private fun decodeMp4AudioToPipe(mp4Path: String, writeFd: ParcelFileDescriptor) {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        val outStream = ParcelFileDescriptor.AutoCloseOutputStream(writeFd)

        try {
            extractor.setDataSource(mp4Path)
            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }

            if (audioTrackIndex == -1 || audioFormat == null) return

            extractor.selectTrack(audioTrackIndex)
            val mime = audioFormat.getString(MediaFormat.KEY_MIME)!!
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(audioFormat, null, null, 0)
            codec.start()

            val bufferInfo = MediaCodec.BufferInfo()
            var isInputEOS = false
            var isOutputEOS = false

            while (!isOutputEOS) {
                if (!isInputEOS) {
                    val inIndex = codec.dequeueInputBuffer(10000)
                    if (inIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inIndex)!!
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            isInputEOS = true
                        } else {
                            codec.queueInputBuffer(inIndex, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
                if (outIndex >= 0) {
                    val outputBuffer = codec.getOutputBuffer(outIndex)!!
                    val chunk = ByteArray(bufferInfo.size)
                    outputBuffer.get(chunk)
                    outputBuffer.clear()

                    if (chunk.isNotEmpty()) {
                        outStream.write(chunk)
                    }
                    codec.releaseOutputBuffer(outIndex, false)

                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        isOutputEOS = true
                    }
                }
            }
        } catch (_: Exception) {
            // Pipe closed early by recognizer completion
        } finally {
            try { outStream.close() } catch (_: Exception) {}
            try { codec?.stop(); codec?.release() } catch (_: Exception) {}
            extractor.release()
        }
    }

    /**
     * Feeds the decoded PCM pipe directly into Android's SpeechRecognizer (No Microphone!)
     */
    private fun runSpeechRecognizerOnPipe(
        readFd: ParcelFileDescriptor,
        sampleRate: Int,
        channelCount: Int,
        language: String,
        onComplete: (String) -> Unit
    ) {
        val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        val fullTranscript = StringBuilder()
        var lastPartial = ""
        var finished = false

        fun finishOnce() {
            if (finished) return
            finished = true
            try {
                recognizer.stopListening()
                recognizer.destroy()
            } catch (_: Exception) {}
            val finalResult = fullTranscript.toString().ifBlank { lastPartial }.trim()
            onComplete(finalResult)
        }

        // Safety timeout (25 seconds max)
        Handler(Looper.getMainLooper()).postDelayed({ finishOnce() }, 25000)

        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty() && matches[0].isNotBlank()) {
                    lastPartial = matches[0]
                }
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty() && matches[0].isNotBlank()) {
                    fullTranscript.append(matches[0]).append(" ")
                }
                finishOnce()
            }

            override fun onSegmentResults(segmentResults: Bundle) {
                val matches = segmentResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty() && matches[0].isNotBlank()) {
                    fullTranscript.append(matches[0]).append(" ")
                    lastPartial = ""
                }
            }

            override fun onEndOfSegmentedSession() {
                finishOnce()
            }

            override fun onError(error: Int) {
                finishOnce()
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val channelConfig = if (channelCount >= 2) {
            AudioFormat.CHANNEL_IN_STEREO
        } else {
            AudioFormat.CHANNEL_IN_MONO
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE)
            // Feed the decoded MP4 pipe instead of the physical microphone!
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, readFd)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, sampleRate)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, channelConfig)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
        }

        recognizer.startListening(intent)
    }
}

import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { RecordingState } from './RecordingState';
import { VoiceActivityDetector } from './VoiceActivityDetector';

const SAMPLE_RATE_16K: audio.AudioSamplingRate = audio.AudioSamplingRate.SAMPLE_RATE_16000;
const MONO_CHANNEL: audio.AudioChannel = audio.AudioChannel.CHANNEL_1;
const PCM_16BIT: audio.AudioSampleFormat = audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE;
const RAW_ENCODING: audio.AudioEncodingType = audio.AudioEncodingType.ENCODING_TYPE_RAW;
const READ_BUFFER_SIZE: number = 4096;
const PCM16_FULL_SCALE: number = 32768;
const MIN_DISPLAY_DBFS: number = -60;
const MAX_DISPLAY_DBFS: number = -6;

export class AudioRecorder {
  private audioCapturer: audio.AudioCapturer | null = null;
  private state: RecordingState = RecordingState.IDLE;
  private onAudioLevelChanged: ((level: number) => void) | null = null;
  private chunks: ArrayBuffer[] = [];
  private totalBytes: number = 0;
  private isReading: boolean = false;
  private readLoopPromise: Promise<void> | null = null;
  private conversationActive: boolean = false;
  private isProcessingUtterance: boolean = false;
  private onUtteranceCompleted: ((audioBuffer: ArrayBuffer) => Promise<void>) | null = null;
  private voiceActivityDetector: VoiceActivityDetector = new VoiceActivityDetector();

  setAudioLevelCallback(callback: (level: number) => void): void {
    this.onAudioLevelChanged = callback;
  }

  getState(): RecordingState {
    return this.state;
  }

  async startRecording(): Promise<void> {
    if (this.isBusy()) {
      throw new Error(`当前录音器正处于${this.state}状态，暂时不能开始新的录音`);
    }

    try {
      await this.safeReleaseCapturer();
      const streamInfo: audio.AudioStreamInfo = {
        samplingRate: SAMPLE_RATE_16K,
        channels: MONO_CHANNEL,
        sampleFormat: PCM_16BIT,
        encodingType: RAW_ENCODING
      };
      const capturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      };

      this.state = RecordingState.IDLE;
      this.resetAudioChunks();
      this.audioCapturer = await audio.createAudioCapturer({ streamInfo, capturerInfo });
      await this.audioCapturer.start();
      this.state = RecordingState.RECORDING;
      this.startReadLoop(this.audioCapturer);
      this.emitAudioLevel(new ArrayBuffer(0));
    } catch (error) {
      await this.handleFailure(error as BusinessError, '录制失败');
    }
  }

  async stopRecording(): Promise<ArrayBuffer> {
    if (!this.audioCapturer || (this.state !== RecordingState.RECORDING && this.state !== RecordingState.RECOGNIZING)) {
      throw new Error('当前没有正在进行的录音');
    }

    this.state = RecordingState.STOPPING;

    try {
      const capturer: audio.AudioCapturer = this.audioCapturer;
      this.isReading = false;
      await capturer.stop();
      await this.waitReadLoopStopped();
      await this.safeReleaseCapturer();
      this.state = RecordingState.COMPLETED;
      this.emitAudioLevel(new ArrayBuffer(0));
      return this.mergeArrayBuffers(this.chunks, this.totalBytes);
    } catch (error) {
      return await this.handleFailure(error as BusinessError, '停止录制失败');
    }
  }

  isRecordingActive(): boolean {
    return this.state === RecordingState.RECORDING;
  }

  isBusy(): boolean {
    return this.state === RecordingState.RECORDING ||
      this.state === RecordingState.STOPPING ||
      this.state === RecordingState.RECOGNIZING;
  }

  markRecognizing(): void {
    this.state = RecordingState.RECOGNIZING;
  }

  markCompleted(): void {
    this.state = RecordingState.COMPLETED;
  }

  markFailed(): void {
    this.state = RecordingState.FAILED;
  }

  resetState(): void {
    this.state = RecordingState.IDLE;
  }

  async startConversation(onUtteranceCompleted: (audioBuffer: ArrayBuffer) => Promise<void>): Promise<void> {
    this.conversationActive = true;
    this.isProcessingUtterance = false;
    this.onUtteranceCompleted = onUtteranceCompleted;
    this.voiceActivityDetector.reset();
    try {
      await this.startRecording();
    } catch (error) {
      this.conversationActive = false;
      this.onUtteranceCompleted = null;
      throw error as Error;
    }
  }

  async stopConversation(): Promise<void> {
    this.conversationActive = false;
    this.isProcessingUtterance = false;
    this.onUtteranceCompleted = null;
    this.voiceActivityDetector.reset();
    if (this.audioCapturer && this.isReading) {
      await this.stopRecording();
      return;
    }
    this.state = RecordingState.IDLE;
    this.emitAudioLevel(new ArrayBuffer(0));
  }

  private startReadLoop(capturer: audio.AudioCapturer): void {
    this.isReading = true;
    this.readLoopPromise = this.readAudioLoop(capturer);
  }

  private async readAudioLoop(capturer: audio.AudioCapturer): Promise<void> {
    while (this.isReading && this.audioCapturer === capturer) {
      try {
        const readResult: ArrayBuffer = await capturer.read(READ_BUFFER_SIZE, true);
        if (readResult.byteLength > 0 && this.isReading) {
          this.emitAudioLevel(readResult);
          if (this.conversationActive) {
            if (!this.isProcessingUtterance) {
              const level: number = AudioRecorder.calculateAudioLevel(readResult);
              const utterance: ArrayBuffer | null = this.voiceActivityDetector.push(readResult, level);
              if (utterance) {
                this.handleCompletedUtterance(utterance);
              }
            }
          } else {
            this.chunks.push(readResult);
            this.totalBytes += readResult.byteLength;
          }
        }
      } catch (error) {
        if (this.isReading) {
          console.warn('[AudioRecorder] 读取音频数据失败', error);
        }
        return;
      }
    }
  }

  private async waitReadLoopStopped(): Promise<void> {
    if (!this.readLoopPromise) {
      return;
    }

    try {
      await this.readLoopPromise;
    } catch (error) {
      console.warn('[AudioRecorder] 等待读取循环结束失败', error);
    } finally {
      this.readLoopPromise = null;
    }
  }

  private resetAudioChunks(): void {
    this.chunks = [];
    this.totalBytes = 0;
  }

  private emitAudioLevel(buffer: ArrayBuffer): void {
    if (!this.onAudioLevelChanged) {
      return;
    }

    this.onAudioLevelChanged(AudioRecorder.calculateAudioLevel(buffer));
  }

  static calculateAudioLevel(buffer: ArrayBuffer): number {
    const int16Array: Int16Array = new Int16Array(buffer);
    if (int16Array.length === 0) {
      return 0;
    }

    let sumOfSquares: number = 0;

    for (let i: number = 0; i < int16Array.length; i++) {
      const sample: number = int16Array[i];
      sumOfSquares += sample * sample;
    }

    const rms: number = Math.sqrt(sumOfSquares / int16Array.length);
    if (rms === 0) {
      return 0;
    }

    const dbfs: number = 20 * Math.log10(rms / PCM16_FULL_SCALE);
    const displayLevel: number = ((dbfs - MIN_DISPLAY_DBFS) / (MAX_DISPLAY_DBFS - MIN_DISPLAY_DBFS)) * 100;
    return Math.min(Math.max(displayLevel, 0), 100);
  }

  private async handleCompletedUtterance(utterance: ArrayBuffer): Promise<void> {
    if (!this.onUtteranceCompleted || !this.conversationActive) {
      return;
    }
    this.isProcessingUtterance = true;
    this.state = RecordingState.RECOGNIZING;
    try {
      await this.onUtteranceCompleted(utterance);
    } catch (error) {
      console.error('[AudioRecorder] 处理语音话轮失败', error);
    } finally {
      this.isProcessingUtterance = false;
      if (this.conversationActive && this.isReading) {
        this.state = RecordingState.RECORDING;
      }
    }
  }

  private async handleFailure(error: BusinessError, prefix: string): Promise<never> {
    this.state = RecordingState.FAILED;
    this.isReading = false;
    await this.safeReleaseCapturer();
    await this.waitReadLoopStopped();
    const detail: string = typeof error.code === 'number'
      ? `${error.code}, ${error.message}`
      : String(error);
    throw new Error(`${prefix}: ${detail}`);
  }

  private async safeReleaseCapturer(): Promise<void> {
    if (!this.audioCapturer) {
      return;
    }

    try {
      try {
        await this.audioCapturer.stop();
      } catch (error) {
        console.warn('[AudioRecorder] 停止录音器失败', error);
      }
      await this.audioCapturer.release();
    } catch (error) {
      console.warn('[AudioRecorder] 释放录音器失败', error);
    } finally {
      this.audioCapturer = null;
    }
  }

  private mergeArrayBuffers(chunks: ArrayBuffer[], totalBytes: number): ArrayBuffer {
    const result: ArrayBuffer = new ArrayBuffer(totalBytes);
    const resultView: Uint8Array = new Uint8Array(result);
    let offset: number = 0;

    for (let i: number = 0; i < chunks.length; i++) {
      const chunk: Uint8Array = new Uint8Array(chunks[i]);
      resultView.set(chunk, offset);
      offset += chunk.byteLength;
    }

    return result;
  }
}

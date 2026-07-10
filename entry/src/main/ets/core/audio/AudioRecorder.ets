import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { RecordingState } from './RecordingState';

const SAMPLE_RATE_16K: audio.AudioSamplingRate = audio.AudioSamplingRate.SAMPLE_RATE_16000;
const MONO_CHANNEL: audio.AudioChannel = audio.AudioChannel.CHANNEL_1;
const PCM_16BIT: audio.AudioSampleFormat = audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE;
const RAW_ENCODING: audio.AudioEncodingType = audio.AudioEncodingType.ENCODING_TYPE_RAW;
const READ_BUFFER_SIZE: number = 4096;
const MAX_READ_COUNT: number = 240;

export class AudioRecorder {
  private audioCapturer: audio.AudioCapturer | null = null;
  private state: RecordingState = RecordingState.IDLE;
  private onAudioLevelChanged: ((level: number) => void) | null = null;

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
      this.audioCapturer = await audio.createAudioCapturer({ streamInfo, capturerInfo });
      await this.audioCapturer.start();
      this.state = RecordingState.RECORDING;
      this.emitAudioLevel(new ArrayBuffer(0));
    } catch (error) {
      await this.handleFailure(error as BusinessError, '录制失败');
    }
  }

  async stopRecording(): Promise<ArrayBuffer> {
    if (!this.audioCapturer || this.state !== RecordingState.RECORDING) {
      throw new Error('当前没有正在进行的录音');
    }

    this.state = RecordingState.STOPPING;

    try {
      const capturer: audio.AudioCapturer = this.audioCapturer;
      const chunks: ArrayBuffer[] = [];
      let totalBytes: number = 0;
      let readCount: number = 0;
      let readLen: number = 0;

      do {
        const readResult: ArrayBuffer = await capturer.read(READ_BUFFER_SIZE, true);
        readLen = readResult.byteLength;
        readCount++;

        if (readLen > 0) {
          chunks.push(readResult);
          totalBytes += readLen;
          this.emitAudioLevel(readResult);
        }
      } while (readLen > 0 && readCount < MAX_READ_COUNT);

      await capturer.stop();
      await this.safeReleaseCapturer();
      this.state = RecordingState.COMPLETED;
      this.emitAudioLevel(new ArrayBuffer(0));
      return this.mergeArrayBuffers(chunks, totalBytes);
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

  private emitAudioLevel(buffer: ArrayBuffer): void {
    if (!this.onAudioLevelChanged) {
      return;
    }

    const int16Array: Int16Array = new Int16Array(buffer);
    let sum: number = 0;

    for (let i: number = 0; i < int16Array.length; i++) {
      sum += Math.abs(int16Array[i]);
    }

    const average: number = int16Array.length > 0 ? sum / int16Array.length : 0;
    const normalizedLevel: number = Math.min((average / 32768) * 100, 100);
    this.onAudioLevelChanged(normalizedLevel);
  }

  private async handleFailure(error: BusinessError, prefix: string): Promise<never> {
    this.state = RecordingState.FAILED;
    await this.safeReleaseCapturer();
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

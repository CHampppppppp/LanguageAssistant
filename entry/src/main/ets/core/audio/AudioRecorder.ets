import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { RecordingState } from './RecordingState';

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
    if (this.state === RecordingState.RECORDING) {
      throw new Error('录音已经在进行中');
    }

    try {
      const streamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      const capturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      };

      this.audioCapturer = await audio.createAudioCapturer({ streamInfo, capturerInfo });
      await this.audioCapturer.start();
      this.state = RecordingState.RECORDING;
    } catch (error) {
      this.state = RecordingState.FAILED;
      const err = error as BusinessError;
      throw new Error(`录制失败: ${err.code}, ${err.message}`);
    }
  }

  async stopRecording(): Promise<ArrayBuffer> {
    if (!this.audioCapturer) {
      throw new Error('录音设备未初始化');
    }

    this.state = RecordingState.STOPPING;

    try {
      const capturer: audio.AudioCapturer = this.audioCapturer;
      const chunks: ArrayBuffer[] = [];
      const bufferSize: number = 4096;
      const maxReadCount: number = 240;
      let totalBytes: number = 0;
      let readCount: number = 0;
      let readLen: number = 0;

      do {
        const readResult: ArrayBuffer = await capturer.read(bufferSize, true);
        readLen = readResult.byteLength;
        readCount++;

        if (readLen > 0) {
          chunks.push(readResult);
          totalBytes += readLen;
          this.emitAudioLevel(readResult);
        }
      } while (readLen > 0 && readCount < maxReadCount);

      await capturer.stop();
      await capturer.release();
      this.audioCapturer = null;
      this.state = RecordingState.COMPLETED;
      return this.mergeArrayBuffers(chunks, totalBytes);
    } catch (error) {
      this.state = RecordingState.FAILED;
      const err = error as BusinessError;
      throw new Error(`停止录制失败: ${err.code}, ${err.message}`);
    }
  }

  isRecordingActive(): boolean {
    return this.state === RecordingState.RECORDING;
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

import { AudioRecorder } from './audio/AudioRecorder';
import { RecordingState } from './audio/RecordingState';
import { AsrService } from './asr/AsrService';
import { IFlytekAsrService } from './asr/IFlytekAsrService';
import { createChineseIFlytekBusiness } from './asr/IFlytekTypes';

const MIN_VALID_PCM16_BYTES: number = 2;

export class SpeechRecognizer {
  private audioRecorder: AudioRecorder;
  private asrService: AsrService;

  constructor(
    audioRecorder: AudioRecorder = new AudioRecorder(),
    asrService: AsrService = new IFlytekAsrService(createChineseIFlytekBusiness())
  ) {
    this.audioRecorder = audioRecorder;
    this.asrService = asrService;
  }

  setAudioLevelCallback(callback: (level: number) => void): void {
    this.audioRecorder.setAudioLevelCallback(callback);
  }

  async startRecording(): Promise<void> {
    await this.audioRecorder.startRecording();
    console.info('语音录制已开始');
  }

  async stopRecording(): Promise<ArrayBuffer> {
    const audioBuffer: ArrayBuffer = await this.audioRecorder.stopRecording();
    console.info(`录制完成，总字节数: ${audioBuffer.byteLength}`);
    return audioBuffer;
  }

  async recognize(audioBuffer: ArrayBuffer): Promise<string> {
    const startTime: number = Date.now();

    try {
      const validBuffer: ArrayBuffer = this.normalizePcm16Buffer(audioBuffer);
      if (validBuffer.byteLength < MIN_VALID_PCM16_BYTES) {
        console.warn('[SpeechRecognizer] 音频数据为空或长度无效');
        this.audioRecorder.markFailed();
        return '';
      }

      this.audioRecorder.markRecognizing();
      const result: string = await this.asrService.recognize(validBuffer);
      const duration: number = Date.now() - startTime;
      console.info(`识别耗时: ${duration}ms`);
      if (result) {
        this.audioRecorder.markCompleted();
      } else {
        this.audioRecorder.markFailed();
      }
      return result;
    } catch (error) {
      this.audioRecorder.markFailed();
      console.error('语音识别失败:', error);
      return '';
    }
  }

  isRecordingActive(): boolean {
    return this.audioRecorder.isRecordingActive();
  }

  getRecordingState(): RecordingState {
    return this.audioRecorder.getState();
  }

  private normalizePcm16Buffer(audioBuffer: ArrayBuffer): ArrayBuffer {
    const validLength: number = Math.floor(audioBuffer.byteLength / 2) * 2;
    if (validLength === 0) {
      return new ArrayBuffer(0);
    }

    if (validLength === audioBuffer.byteLength) {
      return audioBuffer;
    }

    const validBuffer: ArrayBuffer = new ArrayBuffer(validLength);
    const validView: Uint8Array = new Uint8Array(validBuffer);
    const sourceView: Uint8Array = new Uint8Array(audioBuffer, 0, validLength);
    validView.set(sourceView);
    return validBuffer;
  }
}

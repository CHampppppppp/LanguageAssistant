import { AudioRecorder } from './audio/AudioRecorder';
import { RecordingState } from './audio/RecordingState';
import { AsrService } from './asr/AsrService';
import { IFlytekAsrService } from './asr/IFlytekAsrService';
import { createChineseIFlytekBusiness } from './asr/IFlytekTypes';

const MIN_VALID_PCM16_BYTES: number = 2;

export class SpeechRecognizer {
  private audioRecorder: AudioRecorder;
  private asrService: AsrService;
  private lastRecognitionDurationMs: number = 0;
  private lastErrorMessage: string = '';

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

  async startConversation(onUtteranceCompleted: (audioBuffer: ArrayBuffer) => Promise<void>): Promise<void> {
    this.lastErrorMessage = '';
    await this.audioRecorder.startConversation(onUtteranceCompleted);
    console.info('语音对话已开始');
  }

  async stopConversation(): Promise<void> {
    await this.audioRecorder.stopConversation();
    console.info('语音对话已结束');
  }

  async startRecording(): Promise<void> {
    this.lastErrorMessage = '';
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
    this.lastErrorMessage = '';
    this.lastRecognitionDurationMs = 0;

    try {
      const validBuffer: ArrayBuffer = this.normalizePcm16Buffer(audioBuffer);
      if (validBuffer.byteLength < MIN_VALID_PCM16_BYTES) {
        console.warn('[SpeechRecognizer] 音频数据为空或长度无效');
        this.audioRecorder.markFailed();
        this.lastErrorMessage = '音频数据为空或长度无效';
        return '';
      }

      this.audioRecorder.markRecognizing();
      const result: string = await this.asrService.recognize(validBuffer);
      const duration: number = Date.now() - startTime;
      this.lastRecognitionDurationMs = duration;
      console.info(`识别耗时: ${duration}ms`);
      if (result) {
        this.audioRecorder.markCompleted();
      } else {
        this.audioRecorder.markFailed();
        this.lastErrorMessage = '识别失败，未返回文字';
      }
      return result;
    } catch (error) {
      this.audioRecorder.markFailed();
      this.lastRecognitionDurationMs = Date.now() - startTime;
      this.lastErrorMessage = String(error);
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

  getLastRecognitionDurationMs(): number {
    return this.lastRecognitionDurationMs;
  }

  getLastErrorMessage(): string {
    return this.lastErrorMessage;
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

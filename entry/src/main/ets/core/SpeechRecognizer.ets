import { AudioRecorder, RecordingDiagnostics } from './audio/AudioRecorder';
import { RecordingState } from './audio/RecordingState';
import { AsrService } from './asr/AsrService';
import { IFlytekAsrService } from './asr/IFlytekAsrService';
import { createChineseIFlytekBusiness } from './asr/IFlytekTypes';

const MIN_VALID_PCM16_BYTES: number = 2;

export type RecognitionFailureKind = 'none' | 'empty_audio' | 'no_text' | 'api_or_network' | 'unknown';

export interface RecognitionProfileInfo {
  profileId: string;
  language: string;
  scenario: string;
  boundaryNote: string;
}

const CHINESE_REALTIME_PROFILE: RecognitionProfileInfo = {
  profileId: 'chinese_realtime',
  language: 'zh-CN',
  scenario: '实时录音识别',
  boundaryNote: '实时录音默认使用中文识别配置；LibriSpeech 评测应单独使用英文识别配置。'
};

export class SpeechRecognizer {
  private audioRecorder: AudioRecorder;
  private asrService: AsrService;
  private lastRecognitionDurationMs: number = 0;
  private lastErrorMessage: string = '';
  private lastFailureKind: RecognitionFailureKind = 'none';
  private lastRecognizedText: string = '';
  private profileInfo: RecognitionProfileInfo;

  constructor(
    audioRecorder: AudioRecorder = new AudioRecorder(),
    asrService: AsrService = new IFlytekAsrService(createChineseIFlytekBusiness()),
    profileInfo: RecognitionProfileInfo = CHINESE_REALTIME_PROFILE
  ) {
    this.audioRecorder = audioRecorder;
    this.asrService = asrService;
    this.profileInfo = profileInfo;
  }

  setAudioLevelCallback(callback: (level: number) => void): void {
    this.audioRecorder.setAudioLevelCallback(callback);
  }

  async startRecording(): Promise<void> {
    this.lastErrorMessage = '';
    this.lastFailureKind = 'none';
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
    this.lastFailureKind = 'none';
    this.lastRecognizedText = '';

    try {
      const validBuffer: ArrayBuffer = this.normalizePcm16Buffer(audioBuffer);
      if (validBuffer.byteLength < MIN_VALID_PCM16_BYTES) {
        console.warn('[SpeechRecognizer] 音频数据为空或长度无效');
        this.audioRecorder.markFailed();
        this.lastErrorMessage = '音频数据为空或长度无效';
        this.lastFailureKind = 'empty_audio';
        return '';
      }

      this.audioRecorder.markRecognizing();
      const result: string = this.normalizeRecognizedText(await this.asrService.recognize(validBuffer));
      const duration: number = Date.now() - startTime;
      this.lastRecognitionDurationMs = duration;
      console.info(`识别耗时: ${duration}ms`);
      if (result) {
        this.audioRecorder.markCompleted();
        this.lastRecognizedText = result;
      } else {
        this.audioRecorder.markFailed();
        this.lastErrorMessage = '识别失败，未返回文字';
        this.lastFailureKind = 'no_text';
      }
      return result;
    } catch (error) {
      this.audioRecorder.markFailed();
      this.lastRecognitionDurationMs = Date.now() - startTime;
      this.lastErrorMessage = String(error);
      this.lastFailureKind = this.classifyFailureKind(error);
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

  getLastFailureKind(): RecognitionFailureKind {
    return this.lastFailureKind;
  }

  getLastRecognizedText(): string {
    return this.lastRecognizedText;
  }

  getRecognitionProfileInfo(): RecognitionProfileInfo {
    return {
      profileId: this.profileInfo.profileId,
      language: this.profileInfo.language,
      scenario: this.profileInfo.scenario,
      boundaryNote: this.profileInfo.boundaryNote
    };
  }

  getLastRecordingDiagnostics(): RecordingDiagnostics {
    return this.audioRecorder.getLastDiagnostics();
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

  private normalizeRecognizedText(text: string): string {
    return text.replace(/\s+/g, ' ').trim();
  }

  private classifyFailureKind(error: unknown): RecognitionFailureKind {
    const errorMessage: string = String(error).toLowerCase();
    if (
      errorMessage.includes('network') ||
      errorMessage.includes('timeout') ||
      errorMessage.includes('socket') ||
      errorMessage.includes('api') ||
      errorMessage.includes('http')
    ) {
      return 'api_or_network';
    }
    return 'unknown';
  }
}

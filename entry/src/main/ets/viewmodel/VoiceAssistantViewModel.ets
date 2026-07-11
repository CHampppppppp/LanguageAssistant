import { RecognitionFailureKind, RecognitionProfileInfo, SpeechRecognizer } from '../core/SpeechRecognizer';
import { SemanticUnderstanding } from '../core/SemanticUnderstanding';
import { VoiceCommand } from '../model/VoiceCommand';
import { DatasetLoader } from '../utils/DatasetLoader';
import { PerformanceMonitor } from '../utils/PerformanceMonitor';
import { MockCommandExecutor } from '../core/command/CommandExecutor';
import { CommandExecutionResult } from '../core/command/CommandResult';
import { TextFeedback } from '../core/feedback/TextFeedback';
import { IFlytekAsrService } from '../core/asr/IFlytekAsrService';
import { createEnglishIFlytekBusiness } from '../core/asr/IFlytekTypes';
import { LibriSpeechEvaluator } from '../core/evaluation/LibriSpeechEvaluator';
import { EvaluationDetail, EvaluationSummary } from '../core/evaluation/EvaluationTypes';
import { AssistantFlowState } from './AssistantFlowState';
import { RecordingDiagnostics } from '../core/audio/AudioRecorder';

export interface RecognitionResult {
  recognizedText: string;
  commandResult: string;
  feedback: string;
  semanticConfidence: number;
  responseTime: number;
  failureKind: RecognitionFailureKind;
  errorDetail: string;
  recognitionProfile: RecognitionProfileInfo;
  recordingDiagnostics: RecordingDiagnostics;
}

export interface TestResult {
  wordAccuracy: number;
  sampleCount: number;
  evaluatedCount: number;
  avgResponseTime: number;
  successRate: number;
  accuracyTargetMet: boolean;
  responseTimeTargetMet: boolean;
  reportText: string;
  details: TestDetail[];
}

export interface TestDetail {
  sampleId: string;
  recognizedText: string;
  groundTruth: string;
  wordAccuracy: number;
  wordErrorRate: number;
  responseTime: number;
  meetsAccuracyTarget: boolean;
  meetsResponseTimeTarget: boolean;
  success: boolean;
  audioFormat: string;
  audioPreparation: string;
  failureCategory: string;
  reason: string;
}

export class VoiceAssistantViewModel {
  private speechRecognizer: SpeechRecognizer = new SpeechRecognizer();
  private semanticUnderstanding: SemanticUnderstanding = new SemanticUnderstanding();
  private commandExecutor: MockCommandExecutor = new MockCommandExecutor();
  private textFeedback: TextFeedback = new TextFeedback();
  private datasetLoader: DatasetLoader | null = null;
  private performanceMonitor: PerformanceMonitor = new PerformanceMonitor();
  private context: Context | undefined = undefined;
  private flowStateCallback: ((state: AssistantFlowState) => void) | null = null;

  private createDefaultRecordingDiagnostics(): RecordingDiagnostics {
    return {
      durationMs: 0,
      capturedBytes: 0,
      chunkCount: 0,
      readCount: 0,
      isEmptyAudio: true,
      finalState: this.speechRecognizer.getRecordingState(),
      errorMessage: ''
    };
  }

  setAudioLevelCallback(callback: (level: number) => void): void {
    this.speechRecognizer.setAudioLevelCallback(callback);
  }

  setFlowStateCallback(callback: (state: AssistantFlowState) => void): void {
    this.flowStateCallback = callback;
  }

  setContext(context: Context): void {
    this.context = context;
    console.info(`[ViewModel] Context 已设置：${this.context ? '是' : '否'}`);
  }

  init(): void {
    const datasetPath: string = 'rawfile/dev-clean/LibriSpeech/dev-clean';
    this.datasetLoader = new DatasetLoader(datasetPath, this.context);
    console.info('语音助手 ViewModel 初始化');
  }

  destroy(): void {
    this.textFeedback.release();
    this.flowStateCallback = null;
    console.info('语音助手 ViewModel 销毁');
  }

  async processVoiceCommand(): Promise<RecognitionResult> {
    try {
      await this.speechRecognizer.startRecording();
      this.updateFlowState(AssistantFlowState.RECORDING);
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 3000);
      });
      const audioBuffer: ArrayBuffer = await this.speechRecognizer.stopRecording();
      return await this.processRecordedAudio(audioBuffer);
    } catch (error) {
      return this.createFailedRecognitionResult(`错误: ${(error as Error).message}`, '处理失败', 'unknown', String((error as Error).message));
    }
  }

  async startRecording(): Promise<void> {
    await this.speechRecognizer.startRecording();
    this.updateFlowState(AssistantFlowState.RECORDING);
  }

  async stopAndProcessRecording(): Promise<RecognitionResult> {
    try {
      const audioBuffer: ArrayBuffer = await this.speechRecognizer.stopRecording();
      return await this.processRecordedAudio(audioBuffer);
    } catch (error) {
      const errorMessage: string = (error as Error).message || String(error);
      return this.createFailedRecognitionResult(`错误: ${errorMessage}`, '处理失败', 'unknown', errorMessage);
    }
  }

  async testWithDataset(): Promise<TestResult> {
    this.updateFlowState(AssistantFlowState.EVALUATING);
    if (!this.datasetLoader) {
      this.updateFlowState(AssistantFlowState.FAILED);
      return {
        wordAccuracy: 0,
        sampleCount: 0,
        evaluatedCount: 0,
        avgResponseTime: 0,
        successRate: 0,
        accuracyTargetMet: false,
        responseTimeTargetMet: false,
        reportText: '',
        details: []
      };
    }

    try {
      const evaluator: LibriSpeechEvaluator = new LibriSpeechEvaluator(
        this.datasetLoader,
        new IFlytekAsrService(createEnglishIFlytekBusiness()),
        {
          maxSamples: 50,
          recognizerProfile: 'english_librispeech_eval'
        }
      );
      const summary: EvaluationSummary = await evaluator.evaluate();
      this.updateFlowState(AssistantFlowState.COMPLETED);

      return {
        wordAccuracy: Number((summary.averageWordAccuracy * 100).toFixed(2)),
        sampleCount: summary.totalSampleCount,
        evaluatedCount: summary.evaluatedCount,
        avgResponseTime: Number(summary.averageResponseTime.toFixed(0)),
        successRate: Number((summary.successRate * 100).toFixed(2)),
        accuracyTargetMet: summary.accuracyTargetMet,
        responseTimeTargetMet: summary.responseTimeTargetMet,
        reportText: summary.reportText,
        details: this.mapEvaluationDetails(summary.details)
      };
    } catch (error) {
      this.updateFlowState(AssistantFlowState.FAILED);
      const errMsg: string = (error as Error).message || String(error);
      throw new Error(errMsg);
    }
  }

  private async processRecordedAudio(audioBuffer: ArrayBuffer): Promise<RecognitionResult> {
    const startTime: number = Date.now();

    if (audioBuffer.byteLength === 0) {
      return this.createFailedRecognitionResult('未检测到音频数据', '请检查麦克风权限', 'empty_audio', '录音数据为空');
    }

    this.updateFlowState(AssistantFlowState.RECOGNIZING);
    const recognizedText: string = await this.speechRecognizer.recognize(audioBuffer);
    if (!recognizedText) {
      const failureKind: RecognitionFailureKind = this.speechRecognizer.getLastFailureKind();
      const errorDetail: string = this.speechRecognizer.getLastErrorMessage() || '识别失败，未返回文字';
      const feedback: string = failureKind === 'api_or_network' ? '请检查网络或接口配置后重试' : '请重试';
      return this.createFailedRecognitionResult('识别失败，未返回文字', feedback, failureKind, errorDetail);
    }

    const command: VoiceCommand = this.semanticUnderstanding.understand(recognizedText);
    this.updateFlowState(AssistantFlowState.EXECUTING);
    const executionResult: CommandExecutionResult = await this.commandExecutor.execute(command);
    const feedback: string = this.textFeedback.createFeedback(executionResult.message);
    const responseTime: number = Date.now() - startTime;

    this.performanceMonitor.recordResponseTime(responseTime);
    this.updateFlowState(AssistantFlowState.COMPLETED);

    return {
      recognizedText,
      commandResult: executionResult.message,
      feedback,
      semanticConfidence: this.toPercent(command.confidence),
      responseTime,
      failureKind: 'none',
      errorDetail: '',
      recognitionProfile: this.speechRecognizer.getRecognitionProfileInfo(),
      recordingDiagnostics: this.speechRecognizer.getLastRecordingDiagnostics()
    };
  }

  private createFailedRecognitionResult(
    recognizedText: string,
    feedback: string,
    failureKind: RecognitionFailureKind,
    errorDetail: string
  ): RecognitionResult {
    this.updateFlowState(AssistantFlowState.FAILED);
    return {
      recognizedText,
      commandResult: '',
      feedback,
      semanticConfidence: 0,
      responseTime: 0,
      failureKind,
      errorDetail,
      recognitionProfile: this.speechRecognizer.getRecognitionProfileInfo(),
      recordingDiagnostics: this.speechRecognizer.getLastRecordingDiagnostics() || this.createDefaultRecordingDiagnostics()
    };
  }

  private mapEvaluationDetails(details: EvaluationDetail[]): TestDetail[] {
    return details.map((detail: EvaluationDetail): TestDetail => {
      return {
        sampleId: detail.sampleId,
        recognizedText: detail.recognizedText,
        groundTruth: detail.groundTruth,
        wordAccuracy: detail.wordAccuracy,
        wordErrorRate: detail.wordErrorRate,
        responseTime: detail.responseTime,
        meetsAccuracyTarget: detail.meetsAccuracyTarget,
        meetsResponseTimeTarget: detail.meetsResponseTimeTarget,
        success: detail.success,
        audioFormat: detail.audioFormat,
        audioPreparation: detail.audioPreparation,
        failureCategory: detail.failureCategory,
        reason: detail.reason
      };
    });
  }

  private toPercent(value: number): number {
    return Number((value * 100).toFixed(2));
  }

  private updateFlowState(state: AssistantFlowState): void {
    if (this.flowStateCallback) {
      this.flowStateCallback(state);
    }
  }
}

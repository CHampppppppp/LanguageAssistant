import { RecognitionFailureKind, RecognitionProfileInfo, SpeechRecognizer } from '../core/SpeechRecognizer';
import { SemanticUnderstanding } from '../core/SemanticUnderstanding';
import { VoiceCommand } from '../model/VoiceCommand';
import { DatasetLoader } from '../utils/DatasetLoader';
import { PerformanceMonitor } from '../utils/PerformanceMonitor';
import { MockCommandExecutor } from '../core/command/CommandExecutor';
import { CommandExecutionResult } from '../core/command/CommandResult';
import { SystemVolumeController } from '../core/command/SystemVolumeController';
import { SystemAppLauncher } from '../core/command/AppLauncher';
import { common } from '@kit.AbilityKit';
import { TextFeedback } from '../core/feedback/TextFeedback';
import { IFlytekAsrService } from '../core/asr/IFlytekAsrService';
import { createEnglishIFlytekBusiness } from '../core/asr/IFlytekTypes';
import { LibriSpeechEvaluator } from '../core/evaluation/LibriSpeechEvaluator';
import { EvaluationDetail, EvaluationSummary } from '../core/evaluation/EvaluationTypes';
import { VoiceIntent } from '../core/nlu/VoiceIntent';
import { AssistantFlowState } from './AssistantFlowState';
import { RecordingDiagnostics } from '../core/audio/AudioRecorder';

export enum AssistantUiAction {
  NONE = 'none',
  OPEN_EVALUATION_PANEL = 'open_evaluation_panel'
}

export interface RecognitionResult {
  recognizedText: string;
  commandResult: string;
  feedback: string;
  commandIntent: string;
  semanticConfidence: number;
  responseTime: number;
  uiAction: AssistantUiAction;
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
  private commandExecutor: MockCommandExecutor = new MockCommandExecutor(undefined, new SystemVolumeController());
  private textFeedback: TextFeedback = new TextFeedback();
  private datasetLoader: DatasetLoader | null = null;
  private performanceMonitor: PerformanceMonitor = new PerformanceMonitor();
  private context: Context | undefined = undefined;
  private flowStateCallback: ((state: AssistantFlowState) => void) | null = null;
  private recognitionResultCallback: ((result: RecognitionResult) => void) | null = null;
  private conversationActive: boolean = false;

  setAudioLevelCallback(callback: (level: number) => void): void {
    this.speechRecognizer.setAudioLevelCallback(callback);
  }

  setFlowStateCallback(callback: (state: AssistantFlowState) => void): void {
    this.flowStateCallback = callback;
  }

  setRecognitionResultCallback(callback: (result: RecognitionResult) => void): void {
    this.recognitionResultCallback = callback;
  }

  setContext(context: Context): void {
    this.context = context;
    this.commandExecutor = new MockCommandExecutor(
      undefined,
      new SystemVolumeController(),
      new SystemAppLauncher(context as common.UIAbilityContext)
    );
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
    this.recognitionResultCallback = null;
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
      const errorMessage: string = this.formatErrorMessage(error as Error);
      return this.createFailedRecognitionResult(`错误: ${errorMessage}`, '处理失败', 'unknown', errorMessage);
    }
  }

  async startRecording(): Promise<void> {
    await this.speechRecognizer.startRecording();
    this.updateFlowState(AssistantFlowState.RECORDING);
  }

  async startConversation(): Promise<void> {
    this.conversationActive = true;
    try {
      await this.speechRecognizer.startConversation(async (audioBuffer: ArrayBuffer): Promise<void> => {
        const result: RecognitionResult = await this.processRecordedAudio(audioBuffer);
        if (this.recognitionResultCallback) {
          this.recognitionResultCallback(result);
        }
        if (this.conversationActive) {
          this.updateFlowState(AssistantFlowState.RECORDING);
        }
      });
      this.updateFlowState(AssistantFlowState.RECORDING);
    } catch (error) {
      this.conversationActive = false;
      throw error as Error;
    }
  }

  async stopConversation(): Promise<void> {
    this.conversationActive = false;
    await this.speechRecognizer.stopConversation();
    this.updateFlowState(AssistantFlowState.IDLE);
  }

  async stopAndProcessRecording(): Promise<RecognitionResult> {
    try {
      const audioBuffer: ArrayBuffer = await this.speechRecognizer.stopRecording();
      return await this.processRecordedAudio(audioBuffer);
    } catch (error) {
      const errorMessage: string = this.formatErrorMessage(error as Error);
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
          maxSamples: 20,
          recognizerProfile: 'english_librispeech_eval'
        }
      );
      const summary: EvaluationSummary = await evaluator.evaluate();
      console.info(`[ViewModel] 评测完成，平均词准确率：${(summary.averageWordAccuracy * 100).toFixed(2)}%，平均响应时间：${summary.averageResponseTime.toFixed(0)}ms，成功：${summary.successCount}，失败：${summary.failureCount}`);
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
      return this.createFailedRecognitionResult(
        '未检测到音频输入',
        '请确认模拟器麦克风输入源、宿主机麦克风权限和录音时长',
        'empty_audio',
        '录音结果为空，未采集到可识别的 PCM 音频数据'
      );
    }

    this.updateFlowState(AssistantFlowState.RECOGNIZING);
    const recognizedText: string = await this.speechRecognizer.recognize(audioBuffer);
    if (!recognizedText) {
      const failureKind: RecognitionFailureKind = this.speechRecognizer.getLastFailureKind();
      const errorDetail: string = this.speechRecognizer.getLastErrorMessage() || 'ASR 服务返回空识别文本';
      const feedback: string = failureKind === 'api_or_network' ? '请检查网络或接口配置后重试' : '请重试';
      return this.createFailedRecognitionResult('识别失败，未返回文字', feedback, failureKind, errorDetail);
    }

    const command: VoiceCommand = await this.semanticUnderstanding.understand(recognizedText);
    this.updateFlowState(AssistantFlowState.EXECUTING);
    const executionResult: CommandExecutionResult = await this.commandExecutor.execute(command);
    const feedback: string = this.textFeedback.createFeedback(executionResult.message);
    const responseTime: number = Date.now() - startTime;
    const uiAction: AssistantUiAction = command.intent === VoiceIntent.ACCURACY_EVALUATION ?
      AssistantUiAction.OPEN_EVALUATION_PANEL :
      AssistantUiAction.NONE;

    this.performanceMonitor.recordResponseTime(responseTime);
    this.updateFlowState(AssistantFlowState.COMPLETED);

    return {
      recognizedText,
      commandResult: executionResult.message,
      feedback,
      commandIntent: command.intent,
      semanticConfidence: this.toPercent(command.confidence),
      responseTime,
      uiAction,
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
      commandIntent: VoiceIntent.UNKNOWN,
      semanticConfidence: 0,
      responseTime: 0,
      uiAction: AssistantUiAction.NONE,
      failureKind,
      errorDetail,
      recognitionProfile: this.speechRecognizer.getRecognitionProfileInfo(),
      recordingDiagnostics: this.speechRecognizer.getLastRecordingDiagnostics()
    };
  }

  private formatErrorMessage(error: Error): string {
    if (error.message) {
      return error.message;
    }
    return String(error);
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

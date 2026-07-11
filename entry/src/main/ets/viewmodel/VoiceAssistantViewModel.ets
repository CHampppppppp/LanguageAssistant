import { SpeechRecognizer } from '../core/SpeechRecognizer';
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

export interface RecognitionResult {
  recognizedText: string;
  commandResult: string;
  feedback: string;
  semanticConfidence: number;
  responseTime: number;
}

export interface TestResult {
  wordAccuracy: number;
  sampleCount: number;
  evaluatedCount: number;
  avgResponseTime: number;
  details: TestDetail[];
}

export interface TestDetail {
  sampleId: string;
  recognizedText: string;
  groundTruth: string;
  wordAccuracy: number;
  wordErrorRate: number;
  responseTime: number;
  success: boolean;
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
      return this.createFailedRecognitionResult(`错误: ${(error as Error).message}`, '处理失败');
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
      return this.createFailedRecognitionResult(`错误: ${(error as Error).message}`, '处理失败');
    }
  }

  async testWithDataset(): Promise<TestResult> {
    this.updateFlowState(AssistantFlowState.EVALUATING);
    if (!this.datasetLoader) {
      this.updateFlowState(AssistantFlowState.FAILED);
      return { wordAccuracy: 0, sampleCount: 0, evaluatedCount: 0, avgResponseTime: 0, details: [] };
    }

    try {
      const evaluator: LibriSpeechEvaluator = new LibriSpeechEvaluator(
        this.datasetLoader,
        new IFlytekAsrService(createEnglishIFlytekBusiness()),
        10
      );
      const summary: EvaluationSummary = await evaluator.evaluate();
      this.updateFlowState(AssistantFlowState.COMPLETED);

      return {
        wordAccuracy: Number((summary.averageWordAccuracy * 100).toFixed(2)),
        sampleCount: summary.totalSampleCount,
        evaluatedCount: summary.evaluatedCount,
        avgResponseTime: Number(summary.averageResponseTime.toFixed(0)),
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
        '请确认模拟器麦克风输入源、宿主机麦克风权限和录音时长'
      );
    }

    this.updateFlowState(AssistantFlowState.RECOGNIZING);
    const recognizedText: string = await this.speechRecognizer.recognize(audioBuffer);
    if (!recognizedText) {
      return this.createFailedRecognitionResult('识别失败，未返回文字', '请重试');
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
      responseTime
    };
  }

  private createFailedRecognitionResult(recognizedText: string, feedback: string): RecognitionResult {
    this.updateFlowState(AssistantFlowState.FAILED);
    return {
      recognizedText,
      commandResult: '',
      feedback,
      semanticConfidence: 0,
      responseTime: 0
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
        success: detail.success,
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

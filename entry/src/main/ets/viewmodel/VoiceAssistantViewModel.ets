// C:/Users/pzl/PycharmProjects/语音助手/entry/src/main/ets/viewmodel/VoiceAssistantViewModel.ets
import { SpeechRecognizer } from '../core/SpeechRecognizer';
import { SemanticUnderstanding } from '../core/SemanticUnderstanding';
import { CommandExecutor } from '../core/CommandExecutor';
import { VoiceFeedback } from '../core/VoiceFeedback';
import { VoiceCommand } from '../model/VoiceCommand';
import { DatasetLoader, DatasetSample } from '../utils/DatasetLoader';
import { PerformanceMonitor } from '../utils/PerformanceMonitor';

export interface RecognitionResult {
  recognizedText: string;
  commandResult: string;
  feedback: string;
  accuracy: number;
}

export interface TestResult {
  accuracy: number;
  sampleCount: number;
  avgResponseTime: number;
  details: TestDetail[];
}

export interface TestDetail {
  sampleId: string;
  recognizedText: string;
  groundTruth: string;
  similarity: number;
  responseTime: number;
}

export class VoiceAssistantViewModel {
  private speechRecognizer: SpeechRecognizer = new SpeechRecognizer();
  private semanticUnderstanding: SemanticUnderstanding = new SemanticUnderstanding();
  private commandExecutor: CommandExecutor = new CommandExecutor();
  private voiceFeedback: VoiceFeedback = new VoiceFeedback();
  private datasetLoader: DatasetLoader | null = null;
  private performanceMonitor: PerformanceMonitor = new PerformanceMonitor();
  private onAudioLevelChanged: ((level: number) => void) | null = null;
  private context: Context | undefined = undefined;

  setAudioLevelCallback(callback: (level: number) => void): void {
    this.onAudioLevelChanged = callback;
    this.speechRecognizer.setAudioLevelCallback(callback);
  }

  setContext(context: Context): void {
    this.context = context;
    console.info(`[ViewModel] Context 已设置：${this.context ? '是' : '否'}`);
  }

  init(): void {
    console.info('语音助手 ViewModel 初始化');
    console.info(`[ViewModel] 当前 Context: ${this.context ? '已设置' : '未设置'}`);

    const datasetPath: string = 'rawfile/dev-clean/LibriSpeech/dev-clean';
    this.datasetLoader = new DatasetLoader(datasetPath, this.context);
  }

  destroy(): void {
    this.voiceFeedback.release();
    console.info('语音助手 ViewModel 销毁');
  }

  async processVoiceCommand(): Promise<RecognitionResult> {
    const startTime: number = Date.now();
    let recognizedText: string = '';
    let commandResult: string = '';
    let feedback: string = '';
    let accuracy: number = 0;

    try {
      await this.speechRecognizer.startRecording();

      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 3000);
      });

      const audioBuffer: ArrayBuffer = await this.speechRecognizer.stopRecording();

      if (audioBuffer.byteLength === 0) {
        recognizedText = '未检测到音频数据';
        feedback = '请检查麦克风权限';
        return { recognizedText, commandResult, feedback, accuracy };
      }

      recognizedText = await this.speechRecognizer.recognize(audioBuffer);

      if (!recognizedText) {
        recognizedText = '识别失败，未返回文字';
        feedback = '请重试';
        return { recognizedText, commandResult, feedback, accuracy };
      }

      const command: VoiceCommand = this.semanticUnderstanding.understand(recognizedText);
      commandResult = await this.commandExecutor.execute(command);
      feedback = commandResult;
      accuracy = command.confidence * 100;

      const responseTime: number = Date.now() - startTime;
      this.performanceMonitor.recordResponseTime(responseTime);
      this.performanceMonitor.recordRecognition(command.isValid());
    } catch (error) {
      const err: Error = error as Error;
      recognizedText = `错误: ${err.message}`;
      feedback = '处理失败';
      console.error('语音处理错误:', err);
    }

    return { recognizedText, commandResult, feedback, accuracy };
  }

  async stopAndProcessRecording(): Promise<RecognitionResult> {
    const startTime: number = Date.now();
    let recognizedText: string = '';
    let commandResult: string = '';
    let feedback: string = '';
    let accuracy: number = 0;

    try {
      const audioBuffer: ArrayBuffer = await this.speechRecognizer.stopRecording();
      console.info(`获取到音频数据: ${audioBuffer.byteLength} 字节`);

      if (audioBuffer.byteLength === 0) {
        recognizedText = '未检测到音频数据';
        feedback = '请检查麦克风权限';
        return { recognizedText, commandResult, feedback, accuracy };
      }

      recognizedText = await this.speechRecognizer.recognize(audioBuffer);
      console.info(`识别结果: ${recognizedText}`);

      if (!recognizedText) {
        recognizedText = '识别失败，未返回文字';
        feedback = '请重试';
        return { recognizedText, commandResult, feedback, accuracy };
      }

      const command: VoiceCommand = this.semanticUnderstanding.understand(recognizedText);
      commandResult = await this.commandExecutor.execute(command);
      feedback = commandResult;
      accuracy = command.confidence * 100;

      const responseTime: number = Date.now() - startTime;
      this.performanceMonitor.recordResponseTime(responseTime);
      this.performanceMonitor.recordRecognition(command.isValid());
    } catch (error) {
      const err: Error = error as Error;
      recognizedText = `错误: ${err.message}`;
      feedback = '处理失败';
      console.error('语音处理错误:', err);
    }

    return { recognizedText, commandResult, feedback, accuracy };
  }

  async testWithDataset(): Promise<TestResult> {
    let accuracy: number = 0;
    let sampleCount: number = 0;
    let avgResponseTime: number = 0;
    const details: TestDetail[] = [];

    try {
      if (!this.datasetLoader) {
        return { accuracy: 0, sampleCount: 0, avgResponseTime: 0, details: [] };
      }

      const samples: DatasetSample[] = await this.datasetLoader.loadDataset();
      sampleCount = samples.length;

      if (sampleCount === 0) {
        return { accuracy: 0, sampleCount: 0, avgResponseTime: 0, details: [] };
      }

      let correctCount: number = 0;
      let totalResponseTime: number = 0;

      const testCount: number = Math.min(samples.length, 10);

      for (let i: number = 0; i < testCount; i++) {
        const sample: DatasetSample = samples[i];
        const startTime: number = Date.now();

        const audioData: Float32Array = await this.datasetLoader.loadAudioData(sample);

        if (audioData.length > 0) {
          const audioBuffer: ArrayBuffer = this.float32ToArrayBuffer(audioData);
          const recognizedText: string = await this.speechRecognizer.recognize(audioBuffer);

          const responseTime: number = Date.now() - startTime;
          totalResponseTime += responseTime;

          const similarity: number = this.calculateSimilarity(recognizedText, sample.transcript);
          if (similarity >= 0.93) {
            correctCount++;
            this.performanceMonitor.recordRecognition(true);
          } else {
            this.performanceMonitor.recordRecognition(false);
          }
          this.performanceMonitor.recordResponseTime(responseTime);

          details.push({
            sampleId: `${sample.speakerId}-${sample.chapterId}-${sample.utteranceId}`,
            recognizedText,
            groundTruth: sample.transcript,
            similarity,
            responseTime
          });

          console.info(`样本 ${i + 1}: 识别="${recognizedText}", 原文="${sample.transcript}", 相似度=${similarity}`);
        }
      }

      accuracy = testCount > 0 ? (correctCount / testCount) * 100 : 0;
      avgResponseTime = testCount > 0 ? totalResponseTime / testCount : 0;
    } catch (error) {
      const err: Error = error as Error;
      console.error('数据集测试错误:', err);
    }

    return { accuracy, sampleCount, avgResponseTime, details };
  }

  private float32ToArrayBuffer(float32: Float32Array): ArrayBuffer {
    const int16Array: Int16Array = new Int16Array(float32.length);
    for (let i: number = 0; i < float32.length; i++) {
      int16Array[i] = Math.max(-32768, Math.min(32767, Math.floor(float32[i] * 32768)));
    }
    return int16Array.buffer;
  }

  private calculateSimilarity(text1: string, text2: string): number {
    if (!text1 || !text2) {
      return 0;
    }

    const t1: string = text1.toLowerCase().trim();
    const t2: string = text2.toLowerCase().trim();

    if (t1 === t2) {
      return 1.0;
    }

    const words1: string[] = t1.split(new RegExp('\\s+'));
    const words2: string[] = t2.split(new RegExp('\\s+'));

    let matchCount: number = 0;
    const totalWords: number = Math.max(words1.length, words2.length);

    for (const word1 of words1) {
      for (const word2 of words2) {
        if (word1 === word2) {
          matchCount++;
          break;
        }
      }
    }

    return totalWords > 0 ? matchCount / totalWords : 0;
  }

  getPerformanceReport(): string {
    return this.performanceMonitor.getPerformanceReport();
  }

  resetPerformance(): void {
    this.performanceMonitor.reset();
  }
}
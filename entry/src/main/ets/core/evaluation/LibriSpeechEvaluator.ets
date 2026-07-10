import { AsrService } from '../asr/AsrService';
import { DatasetLoader, DatasetSample } from '../../utils/DatasetLoader';
import { PerformanceMonitor } from '../../utils/PerformanceMonitor';
import { AccuracyMetric, WordAccuracyResult } from './AccuracyMetric';
import { EvaluationDetail, EvaluationSummary } from './EvaluationTypes';

export class LibriSpeechEvaluator {
  private datasetLoader: DatasetLoader;
  private asrService: AsrService;
  private maxSamples: number;

  constructor(datasetLoader: DatasetLoader, asrService: AsrService, maxSamples: number = 10) {
    this.datasetLoader = datasetLoader;
    this.asrService = asrService;
    this.maxSamples = maxSamples;
  }

  async evaluate(): Promise<EvaluationSummary> {
    const samples: DatasetSample[] = await this.datasetLoader.loadDataset();
    const testCount: number = Math.min(samples.length, Math.max(0, this.maxSamples));
    const details: EvaluationDetail[] = [];
    const performanceMonitor: PerformanceMonitor = new PerformanceMonitor();

    for (let i: number = 0; i < testCount; i++) {
      const sample: DatasetSample = samples[i];
      const startedAt: number = Date.now();
      let recognizedText: string = '';
      let reason: string = '';
      let success: boolean = false;
      let metric: WordAccuracyResult = AccuracyMetric.calculateWordAccuracy('', sample.transcript);

      try {
        if (!sample.transcript) {
          throw new Error('缺少标准转录文本');
        }

        const audioData: Float32Array = await this.datasetLoader.loadAudioData(sample);
        if (audioData.length === 0) {
          throw new Error('音频数据为空或未完成解码');
        }

        const audioBuffer: ArrayBuffer = this.float32ToArrayBuffer(audioData);
        recognizedText = await this.asrService.recognize(audioBuffer);
        if (!recognizedText) {
          throw new Error('ASR 未返回识别文本');
        }

        metric = AccuracyMetric.calculateWordAccuracy(recognizedText, sample.transcript);
        success = metric.wordAccuracy >= 0.93;
        reason = success ? 'word accuracy >= 93%' : 'word accuracy < 93%';
      } catch (error) {
        reason = `评测失败: ${error}`;
      }

      const responseTime: number = Date.now() - startedAt;
      performanceMonitor.recordEvaluationResult(metric.wordAccuracy, responseTime, success);

      details.push({
        sampleId: sample.sampleId,
        recognizedText,
        groundTruth: sample.transcript,
        wordAccuracy: metric.wordAccuracy,
        wordErrorRate: metric.wordErrorRate,
        responseTime,
        success,
        reason
      });
    }

    const metrics = performanceMonitor.getMetrics();

    return {
      averageWordAccuracy: metrics.recognitionAccuracy / 100,
      averageResponseTime: metrics.avgResponseTime,
      evaluatedCount: testCount,
      totalSampleCount: samples.length,
      successCount: metrics.successCount,
      failureCount: metrics.failureCount,
      successRate: metrics.successRate / 100,
      accuracyTargetMet: performanceMonitor.isAccuracyTargetMet(),
      responseTimeTargetMet: performanceMonitor.isResponseTimeTargetMet(),
      details
    };
  }

  private float32ToArrayBuffer(float32: Float32Array): ArrayBuffer {
    const int16Array: Int16Array = new Int16Array(float32.length);
    for (let i: number = 0; i < float32.length; i++) {
      int16Array[i] = Math.max(-32768, Math.min(32767, Math.floor(float32[i] * 32768)));
    }
    return int16Array.buffer;
  }
}

import { AsrService } from '../asr/AsrService';
import { DatasetLoader, DatasetSample, DatasetLoadSummary } from '../../utils/DatasetLoader';
import { PerformanceMonitor } from '../../utils/PerformanceMonitor';
import { AccuracyMetric, WordAccuracyResult } from './AccuracyMetric';
import { EvaluationDetail, EvaluationSummary, EvaluationThresholds } from './EvaluationTypes';

export interface LibriSpeechEvaluationOptions {
  maxSamples?: number;
  accuracyTarget?: number;
  responseTimeTargetMs?: number;
  recognizerProfile?: string;
  audioPreparationPolicy?: string;
  profileBoundaryNote?: string;
}

interface ResolvedLibriSpeechEvaluationOptions {
  maxSamples: number;
  accuracyTarget: number;
  responseTimeTargetMs: number;
  recognizerProfile: string;
  audioPreparationPolicy: string;
  profileBoundaryNote: string;
}

const DEFAULT_MAX_SAMPLES: number = 50;
const DEFAULT_ACCURACY_TARGET: number = 0.93;
const DEFAULT_RESPONSE_TIME_TARGET_MS: number = 2000;
const DEFAULT_RECOGNIZER_PROFILE: string = 'english_librispeech_eval';
const DEFAULT_AUDIO_PREPARATION_POLICY: string = '优先评测预先转换的16k/mono/PCM WAV子集，原始FLAC样本需离线转换后再纳入验收统计';
const DEFAULT_PROFILE_BOUNDARY_NOTE: string = '实时录音默认使用中文识别配置；LibriSpeech 评测单独使用英文识别配置，二者指标需分开说明。';

export class LibriSpeechEvaluator {
  private datasetLoader: DatasetLoader;
  private asrService: AsrService;
  private options: ResolvedLibriSpeechEvaluationOptions;

  constructor(
    datasetLoader: DatasetLoader,
    asrService: AsrService,
    maxSamplesOrOptions: number | LibriSpeechEvaluationOptions = DEFAULT_MAX_SAMPLES
  ) {
    this.datasetLoader = datasetLoader;
    this.asrService = asrService;
    this.options = this.resolveOptions(maxSamplesOrOptions);
  }

  async evaluate(): Promise<EvaluationSummary> {
    const samples: DatasetSample[] = await this.datasetLoader.loadDataset();
    const datasetLoadSummary: DatasetLoadSummary = this.datasetLoader.getLastLoadSummary();
    const testCount: number = Math.min(samples.length, Math.max(0, this.options.maxSamples));
    const details: EvaluationDetail[] = [];
    const performanceMonitor: PerformanceMonitor = new PerformanceMonitor();
    const thresholds: EvaluationThresholds = {
      accuracyPercent: this.options.accuracyTarget * 100,
      responseTimeMs: this.options.responseTimeTargetMs
    };

    for (let i: number = 0; i < testCount; i++) {
      const sample: DatasetSample = samples[i];
      const startedAt: number = Date.now();
      let recognizedText: string = '';
      let reason: string = '';
      let success: boolean = false;
      let failureCategory: string = 'none';
      let metric: WordAccuracyResult = AccuracyMetric.calculateWordAccuracy('', sample.transcript);

      try {
        if (!sample.transcript) {
          failureCategory = 'missing_transcript';
          throw new Error('缺少标准转录文本');
        }

        const audioData: Float32Array = await this.datasetLoader.loadAudioData(sample);
        if (audioData.length === 0) {
          failureCategory = 'audio_unavailable';
          throw new Error('音频数据为空或未完成解码');
        }

        const audioBuffer: ArrayBuffer = this.float32ToArrayBuffer(audioData);
        recognizedText = await this.asrService.recognize(audioBuffer);
        if (!recognizedText) {
          failureCategory = 'no_recognition_text';
          throw new Error('ASR 未返回识别文本');
        }

        metric = AccuracyMetric.calculateWordAccuracy(recognizedText, sample.transcript);
        const responseTime: number = Date.now() - startedAt;
        const meetsAccuracyTarget: boolean = metric.wordAccuracy >= this.options.accuracyTarget;
        const meetsResponseTimeTarget: boolean = responseTime <= this.options.responseTimeTargetMs;
        success = meetsAccuracyTarget && meetsResponseTimeTarget;
        reason = success
          ? 'word accuracy >= target and response time <= target'
          : '未同时满足准确率和响应时间阈值';

        performanceMonitor.recordEvaluationResult(metric.wordAccuracy, responseTime, success);
        details.push({
          sampleId: sample.sampleId,
          recognizedText,
          groundTruth: sample.transcript,
          wordAccuracy: metric.wordAccuracy,
          wordErrorRate: metric.wordErrorRate,
          responseTime,
          meetsAccuracyTarget,
          meetsResponseTimeTarget,
          success,
          audioFormat: sample.audioFormat,
          audioPreparation: sample.audioPreparation,
          failureCategory,
          reason
        });
        continue;
      } catch (error) {
        if (failureCategory === 'none') {
          failureCategory = this.classifyEvaluationFailure(error);
        }
        reason = `评测失败: ${error}`;
      }

      const responseTime: number = Date.now() - startedAt;
      const meetsAccuracyTarget: boolean = metric.wordAccuracy >= this.options.accuracyTarget;
      const meetsResponseTimeTarget: boolean = responseTime <= this.options.responseTimeTargetMs;
      performanceMonitor.recordEvaluationResult(metric.wordAccuracy, responseTime, success);

      details.push({
        sampleId: sample.sampleId,
        recognizedText,
        groundTruth: sample.transcript,
        wordAccuracy: metric.wordAccuracy,
        wordErrorRate: metric.wordErrorRate,
        responseTime,
        meetsAccuracyTarget,
        meetsResponseTimeTarget,
        success,
        audioFormat: sample.audioFormat,
        audioPreparation: sample.audioPreparation,
        failureCategory,
        reason
      });
    }

    const metrics = performanceMonitor.getMetrics();
    const averageWordAccuracy: number = metrics.recognitionAccuracy / 100;
    const averageResponseTime: number = metrics.avgResponseTime;
    const accuracyTargetMet: boolean = averageWordAccuracy >= this.options.accuracyTarget;
    const responseTimeTargetMet: boolean = averageResponseTime <= this.options.responseTimeTargetMs;

    const summary: EvaluationSummary = {
      averageWordAccuracy,
      averageResponseTime,
      evaluatedCount: testCount,
      totalSampleCount: samples.length,
      sampleLimit: this.options.maxSamples,
      successCount: metrics.successCount,
      failureCount: metrics.failureCount,
      successRate: metrics.successRate / 100,
      accuracyTargetMet,
      responseTimeTargetMet,
      thresholds,
      datasetLoadSummary,
      recognizerProfile: this.options.recognizerProfile,
      audioPreparationPolicy: this.options.audioPreparationPolicy,
      profileBoundaryNote: this.options.profileBoundaryNote,
      reportText: '',
      details
    };
    summary.reportText = this.buildReportText(summary);

    return summary;
  }

  private float32ToArrayBuffer(float32: Float32Array): ArrayBuffer {
    const int16Array: Int16Array = new Int16Array(float32.length);
    for (let i: number = 0; i < float32.length; i++) {
      int16Array[i] = Math.max(-32768, Math.min(32767, Math.floor(float32[i] * 32768)));
    }
    return int16Array.buffer;
  }

  private resolveOptions(maxSamplesOrOptions: number | LibriSpeechEvaluationOptions): ResolvedLibriSpeechEvaluationOptions {
    if (typeof maxSamplesOrOptions === 'number') {
      return {
        maxSamples: maxSamplesOrOptions,
        accuracyTarget: DEFAULT_ACCURACY_TARGET,
        responseTimeTargetMs: DEFAULT_RESPONSE_TIME_TARGET_MS,
        recognizerProfile: DEFAULT_RECOGNIZER_PROFILE,
        audioPreparationPolicy: DEFAULT_AUDIO_PREPARATION_POLICY,
        profileBoundaryNote: DEFAULT_PROFILE_BOUNDARY_NOTE
      };
    }

    return {
      maxSamples: maxSamplesOrOptions.maxSamples ?? DEFAULT_MAX_SAMPLES,
      accuracyTarget: maxSamplesOrOptions.accuracyTarget ?? DEFAULT_ACCURACY_TARGET,
      responseTimeTargetMs: maxSamplesOrOptions.responseTimeTargetMs ?? DEFAULT_RESPONSE_TIME_TARGET_MS,
      recognizerProfile: maxSamplesOrOptions.recognizerProfile ?? DEFAULT_RECOGNIZER_PROFILE,
      audioPreparationPolicy: maxSamplesOrOptions.audioPreparationPolicy ?? DEFAULT_AUDIO_PREPARATION_POLICY,
      profileBoundaryNote: maxSamplesOrOptions.profileBoundaryNote ?? DEFAULT_PROFILE_BOUNDARY_NOTE
    };
  }

  private classifyEvaluationFailure(error: unknown): string {
    const errorMessage: string = String(error).toLowerCase();
    if (errorMessage.includes('flac') || errorMessage.includes('wav')) {
      return 'audio_format_not_ready';
    }
    if (errorMessage.includes('asr')) {
      return 'asr_failure';
    }
    if (errorMessage.includes('network') || errorMessage.includes('http') || errorMessage.includes('timeout')) {
      return 'network_or_api_failure';
    }
    return 'unknown_failure';
  }

  private buildReportText(summary: EvaluationSummary): string {
    const detailLines: string[] = summary.details.map((detail: EvaluationDetail, index: number): string => {
      return `${index + 1}. ${detail.sampleId} | truth="${detail.groundTruth}" | hypo="${detail.recognizedText}" | ` +
        `accuracy=${(detail.wordAccuracy * 100).toFixed(2)}% | wer=${detail.wordErrorRate.toFixed(4)} | ` +
        `rt=${detail.responseTime}ms | accTarget=${detail.meetsAccuracyTarget ? 'Y' : 'N'} | ` +
        `rtTarget=${detail.meetsResponseTimeTarget ? 'Y' : 'N'} | reason=${detail.reason}`;
    });

    return [
      'LibriSpeech 评测报告',
      `样本评测数: ${summary.evaluatedCount}/${summary.totalSampleCount} (sampleLimit=${summary.sampleLimit})`,
      `准确率阈值: ${summary.thresholds.accuracyPercent.toFixed(2)}%`,
      `响应时间阈值: ${summary.thresholds.responseTimeMs}ms`,
      `平均词准确率: ${(summary.averageWordAccuracy * 100).toFixed(2)}%`,
      `平均响应时间: ${summary.averageResponseTime.toFixed(2)}ms`,
      `成功样本: ${summary.successCount}, 失败样本: ${summary.failureCount}, 成功率: ${(summary.successRate * 100).toFixed(2)}%`,
      `整体是否达到${summary.thresholds.accuracyPercent.toFixed(2)}%: ${summary.accuracyTargetMet ? '是' : '否'}`,
      `整体是否达到${summary.thresholds.responseTimeMs}ms: ${summary.responseTimeTargetMet ? '是' : '否'}`,
      `音频准备策略: ${summary.audioPreparationPolicy}`,
      `数据集摘要: selectedAudioFormat=${summary.datasetLoadSummary.selectedAudioFormat}, wav优先样本=${summary.datasetLoadSummary.wavPreferredSampleCount}, flac仅原始样本=${summary.datasetLoadSummary.flacOnlySampleCount}, 缺少转录=${summary.datasetLoadSummary.skippedWithoutTranscriptCount}`,
      `识别配置边界: ${summary.profileBoundaryNote}`,
      detailLines.length > 0 ? `样本明细:\n${detailLines.join('\n')}` : '样本明细: 无'
    ].join('\n');
  }
}

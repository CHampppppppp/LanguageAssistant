import { describe, it, expect } from '@ohos/hypium';
import { LibriSpeechEvaluator } from '../main/ets/core/evaluation/LibriSpeechEvaluator';
import { DatasetLoader, DatasetSample } from '../main/ets/utils/DatasetLoader';
import { AsrService } from '../main/ets/core/asr/AsrService';

class FakeDatasetLoader extends DatasetLoader {
  private readonly samplesToReturn: DatasetSample[];
  private readonly audioDataBySampleId: Map<string, Float32Array>;

  constructor(samplesToReturn: DatasetSample[], audioDataBySampleId: Map<string, Float32Array>) {
    super('rawfile/dev-clean');
    this.samplesToReturn = samplesToReturn;
    this.audioDataBySampleId = audioDataBySampleId;
  }

  async loadDataset(): Promise<DatasetSample[]> {
    return this.samplesToReturn;
  }

  async loadAudioData(sample: DatasetSample): Promise<Float32Array> {
    return this.audioDataBySampleId.get(sample.sampleId) || new Float32Array(0);
  }
}

class FakeDatasetAsrService implements AsrService {
  private readonly results: Map<string, string>;
  private callIndex: number = 0;

  constructor(results: Map<string, string>) {
    this.results = results;
  }

  async recognize(_: ArrayBuffer): Promise<string> {
    const result: string = this.results.get(String(this.callIndex)) || '';
    this.callIndex++;
    return result;
  }
}

function createSample(sampleId: string, transcript: string): DatasetSample {
  const parts: string[] = sampleId.split('-');
  return {
    sampleId,
    audioPath: `rawfile/dev-clean/${sampleId}.wav`,
    transcript,
    speakerId: parts[0],
    chapterId: parts[1],
    utteranceId: parts[2]
  };
}

export default function libriSpeechEvaluatorTest() {
  describe('libriSpeechEvaluatorTest', () => {
    it('summarizes success and failure counts for evaluation', 0, async () => {
      const samples: DatasetSample[] = [
        createSample('1-2-3', 'hello world'),
        createSample('1-2-4', 'turn on light')
      ];
      const audioData: Map<string, Float32Array> = new Map([
        ['1-2-3', new Float32Array([0.1, -0.1])],
        ['1-2-4', new Float32Array([0.2, -0.2])]
      ]);
      const evaluator: LibriSpeechEvaluator = new LibriSpeechEvaluator(
        new FakeDatasetLoader(samples, audioData),
        new FakeDatasetAsrService(new Map([
          ['0', 'hello world'],
          ['1', 'turn off light']
        ])),
        10
      );

      const summary = await evaluator.evaluate();

      expect(summary.evaluatedCount).assertEqual(2);
      expect(summary.totalSampleCount).assertEqual(2);
      expect(summary.successCount).assertEqual(1);
      expect(summary.failureCount).assertEqual(1);
      expect(summary.successRate).assertEqual(0.5);
      expect(summary.averageWordAccuracy > 0).assertTrue();
      expect(summary.details.length).assertEqual(2);
    });

    it('marks missing audio data as failure', 0, async () => {
      const samples: DatasetSample[] = [createSample('3-4-5', 'sample text')];
      const evaluator: LibriSpeechEvaluator = new LibriSpeechEvaluator(
        new FakeDatasetLoader(samples, new Map()),
        new FakeDatasetAsrService(new Map()),
        10
      );

      const summary = await evaluator.evaluate();

      expect(summary.successCount).assertEqual(0);
      expect(summary.failureCount).assertEqual(1);
      expect(summary.details[0].success).assertFalse();
      expect(summary.details[0].reason).assertContain('音频数据为空');
    });
  });
}

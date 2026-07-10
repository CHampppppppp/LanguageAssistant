import { VoiceIntent } from '../core/nlu/VoiceIntent';

const WHITESPACE_PATTERN: RegExp = new RegExp('\\s+', 'g');
const UNKNOWN_THRESHOLD: number = 0.52;
const MAX_CANDIDATE_COUNT: number = 3;

export interface TransformerIntentCandidate {
  intent: VoiceIntent;
  score: number;
}

export interface TransformerPrediction {
  intent: VoiceIntent;
  confidence: number;
  candidates: TransformerIntentCandidate[];
  inferenceTimeMs: number;
  featureDimension: number;
  modelInfo: string;
  isExperimental: boolean;
}

interface IntentPrototypeSpec {
  intent: VoiceIntent;
  utterances: string[];
  hints: string[];
}

interface IntentPrototype {
  intent: VoiceIntent;
  vector: number[];
  hints: string[];
}

const INTENT_PROTOTYPE_SPECS: IntentPrototypeSpec[] = [
  {
    intent: VoiceIntent.TIME_QUERY,
    utterances: ['现在几点了', '当前时间', '查询时间', '麻烦看下时间', '告诉我现在时间'],
    hints: ['时间', '几点', '时刻', '现在', '当前', '看下时间']
  },
  {
    intent: VoiceIntent.WEATHER_QUERY,
    utterances: ['今天天气怎么样', '查询天气', '明天天气', '今天会不会下雨', '现在温度多少'],
    hints: ['天气', '温度', '下雨', '气温', '今天', '明天']
  },
  {
    intent: VoiceIntent.PLAY_MUSIC,
    utterances: ['播放音乐', '播放周杰伦的歌', '听歌', '放一首歌', '播放歌曲'],
    hints: ['播放', '音乐', '歌曲', '听歌', '放歌']
  },
  {
    intent: VoiceIntent.STOP_MUSIC,
    utterances: ['停止播放', '暂停音乐', '停止音乐', '先别放了', '暂停歌曲'],
    hints: ['停止', '暂停', '别放', '停下', '音乐']
  },
  {
    intent: VoiceIntent.NEXT_MUSIC,
    utterances: ['下一首', '切歌', '下一曲', '换一首歌', '播放下一首'],
    hints: ['下一首', '切歌', '下一曲', '换一首']
  },
  {
    intent: VoiceIntent.VOLUME_UP,
    utterances: ['音量调大', '增大音量', '声音大点', '把声音开大', '请把声音调大一点'],
    hints: ['音量', '声音', '调大', '增大', '大点', '开大']
  },
  {
    intent: VoiceIntent.VOLUME_DOWN,
    utterances: ['音量调小', '减小音量', '声音小点', '把声音关小', '请把声音调小一点'],
    hints: ['音量', '声音', '调小', '减小', '小点', '关小']
  },
  {
    intent: VoiceIntent.SET_ALARM,
    utterances: ['设置8点30分闹钟', '定个闹钟', '提醒我明天起床', '设置提醒', '八点叫我'],
    hints: ['设置', '闹钟', '提醒', '叫我', '点']
  },
  {
    intent: VoiceIntent.OPEN_APP,
    utterances: ['打开微信', '启动支付宝', '打开应用', '帮我打开软件', '打开浏览器'],
    hints: ['打开', '启动', '应用', '软件']
  },
  {
    intent: VoiceIntent.CLOSE_APP,
    utterances: ['关闭微信', '退出应用', '关闭软件', '退出支付宝', '帮我关闭浏览器'],
    hints: ['关闭', '退出', '应用', '软件']
  }
];

export class TransformerModel {
  private modelPath: string = '';
  private isLoaded: boolean = false;
  private vocabSize: number = 128;
  private dModel: number = 24;
  private nHead: number = 4;
  private nLayer: number = 2;
  private prototypes: IntentPrototype[] = [];

  constructor(modelPath?: string) {
    if (modelPath) {
      this.modelPath = modelPath;
    }
  }

  async loadModel(): Promise<void> {
    this.loadModelSync();
  }

  loadModelSync(): void {
    this.prototypes = [];
    for (let i: number = 0; i < INTENT_PROTOTYPE_SPECS.length; i++) {
      const spec: IntentPrototypeSpec = INTENT_PROTOTYPE_SPECS[i];
      this.prototypes.push({
        intent: spec.intent,
        vector: this.buildPrototypeVector(spec.utterances),
        hints: spec.hints
      });
    }
    this.isLoaded = true;
    console.info(`Transformer 语义实验模块已加载: ${this.getModelInfo()}`);
  }

  predictIntent(text: string): TransformerPrediction {
    if (!this.isLoaded) {
      throw new Error('模型未加载');
    }

    const startTime: number = Date.now();
    const normalizedText: string = this.normalize(text);
    const featureVector: number[] = this.encodeText(normalizedText);

    if (normalizedText.length === 0) {
      return this.createUnknownPrediction(startTime, []);
    }

    const candidates: TransformerIntentCandidate[] = [];
    for (let i: number = 0; i < this.prototypes.length; i++) {
      const prototype: IntentPrototype = this.prototypes[i];
      const score: number = this.calculateIntentScore(normalizedText, featureVector, prototype);
      candidates.push({
        intent: prototype.intent,
        score: this.round(score)
      });
    }

    candidates.sort((a: TransformerIntentCandidate, b: TransformerIntentCandidate): number => b.score - a.score);
    const topCandidates: TransformerIntentCandidate[] = candidates.slice(0, MAX_CANDIDATE_COUNT);

    if (topCandidates.length === 0 || topCandidates[0].score < UNKNOWN_THRESHOLD) {
      return this.createUnknownPrediction(startTime, topCandidates);
    }

    const bestCandidate: TransformerIntentCandidate = topCandidates[0];
    return {
      intent: bestCandidate.intent,
      confidence: this.toConfidence(bestCandidate.score),
      candidates: topCandidates,
      inferenceTimeMs: Date.now() - startTime,
      featureDimension: this.dModel,
      modelInfo: this.getModelInfo(),
      isExperimental: true
    };
  }

  async predict(input: Float32Array): Promise<Float32Array> {
    if (!this.isLoaded) {
      throw new Error('模型未加载');
    }

    const output: Float32Array = new Float32Array(input.length);
    for (let i: number = 0; i < input.length; i++) {
      output[i] = 1 / (1 + Math.exp(-input[i]));
    }
    return output;
  }

  async fineTune(dataset: Float32Array[], labels: number[], epochs: number = 10): Promise<void> {
    console.info(`Transformer 语义实验模块不支持端侧训练，样本数: ${dataset.length}, 标签数: ${labels.length}, epochs: ${epochs}`);
    throw new Error('当前 Transformer 语义实验模块不支持端侧训练');
  }

  unloadModel(): void {
    this.isLoaded = false;
    this.prototypes = [];
    console.info('Transformer 语义实验模块已卸载');
  }

  isModelLoaded(): boolean {
    return this.isLoaded;
  }

  getModelInfo(): string {
    return `Transformer ASR text semantic experiment - Vocab: ${this.vocabSize}, dModel: ${this.dModel}, Heads: ${this.nHead}, Layers: ${this.nLayer}`;
  }

  private normalize(text: string): string {
    return text.toLowerCase().replace(WHITESPACE_PATTERN, '').trim();
  }

  private buildPrototypeVector(utterances: string[]): number[] {
    const vector: number[] = this.createZeroVector();
    if (utterances.length === 0) {
      return vector;
    }

    for (let i: number = 0; i < utterances.length; i++) {
      const utteranceVector: number[] = this.encodeText(this.normalize(utterances[i]));
      for (let j: number = 0; j < this.dModel; j++) {
        vector[j] += utteranceVector[j];
      }
    }

    for (let i: number = 0; i < this.dModel; i++) {
      vector[i] = vector[i] / utterances.length;
    }
    return this.normalizeVector(vector);
  }

  private encodeText(text: string): number[] {
    const vector: number[] = this.createZeroVector();
    if (text.length === 0) {
      return vector;
    }

    for (let i: number = 0; i < text.length; i++) {
      const code: number = text.charCodeAt(i);
      const tokenBucket: number = Math.abs(code + i * 31) % this.dModel;
      const positionBucket: number = Math.abs(i * this.nHead + code) % this.dModel;
      const value: number = ((code % this.vocabSize) + 1) / this.vocabSize;

      vector[tokenBucket] += value;
      vector[(tokenBucket + this.nHead) % this.dModel] += Math.sin((i + 1) / this.dModel);
      vector[positionBucket] += Math.cos((code % 97) / 97);
    }

    return this.normalizeVector(vector);
  }

  private calculateIntentScore(text: string, featureVector: number[], prototype: IntentPrototype): number {
    const attentionScore: number = this.scaledDotProduct(featureVector, prototype.vector);
    const hintScore: number = this.calculateHintScore(text, prototype.hints);
    return this.clamp(attentionScore * 0.45 + hintScore * 0.55, 0, 1);
  }

  private scaledDotProduct(left: number[], right: number[]): number {
    let dot: number = 0;
    for (let i: number = 0; i < this.dModel; i++) {
      dot += left[i] * right[i];
    }
    return this.clamp((dot / Math.sqrt(this.dModel)) * this.nHead, 0, 1);
  }

  private calculateHintScore(text: string, hints: string[]): number {
    let matchedCount: number = 0;
    for (let i: number = 0; i < hints.length; i++) {
      if (text.includes(hints[i])) {
        matchedCount++;
      }
    }
    return this.clamp(matchedCount / 2, 0, 1);
  }

  private createUnknownPrediction(startTime: number, candidates: TransformerIntentCandidate[]): TransformerPrediction {
    const bestScore: number = candidates.length > 0 ? candidates[0].score : 0;
    const unknownCandidate: TransformerIntentCandidate = {
      intent: VoiceIntent.UNKNOWN,
      score: this.round(Math.min(bestScore, 0.4))
    };
    const mergedCandidates: TransformerIntentCandidate[] = [unknownCandidate];

    for (let i: number = 0; i < candidates.length && mergedCandidates.length < MAX_CANDIDATE_COUNT; i++) {
      mergedCandidates.push(candidates[i]);
    }

    return {
      intent: VoiceIntent.UNKNOWN,
      confidence: unknownCandidate.score,
      candidates: mergedCandidates,
      inferenceTimeMs: Date.now() - startTime,
      featureDimension: this.dModel,
      modelInfo: this.getModelInfo(),
      isExperimental: true
    };
  }

  private createZeroVector(): number[] {
    const vector: number[] = [];
    for (let i: number = 0; i < this.dModel; i++) {
      vector.push(0);
    }
    return vector;
  }

  private normalizeVector(vector: number[]): number[] {
    let sumSquares: number = 0;
    for (let i: number = 0; i < vector.length; i++) {
      sumSquares += vector[i] * vector[i];
    }

    if (sumSquares === 0) {
      return vector;
    }

    const length: number = Math.sqrt(sumSquares);
    for (let i: number = 0; i < vector.length; i++) {
      vector[i] = vector[i] / length;
    }
    return vector;
  }

  private toConfidence(score: number): number {
    return this.round(this.clamp(0.45 + score * 0.5, 0, 0.95));
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.min(Math.max(value, min), max);
  }

  private round(value: number): number {
    return Number(value.toFixed(4));
  }
}

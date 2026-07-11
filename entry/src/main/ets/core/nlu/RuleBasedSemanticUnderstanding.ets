import { VoiceCommand } from '../../model/VoiceCommand';
import { TransformerModel, TransformerPrediction } from '../../model/TransformerModel';
import { IntentRule, INTENT_RULES } from './IntentRule';
import { VoiceIntent } from './VoiceIntent';

const WHITESPACE_PATTERN: RegExp = new RegExp('\\s+', 'g');
const APP_NAME_PATTERN: RegExp = new RegExp('(?:打开|启动|关闭|退出)(.+?)(?:应用|软件)?$');
const ALARM_TIME_PATTERN: RegExp = new RegExp('(\\d{1,2})[点:时](?:(\\d{1,2})分?)?');
const MUSIC_NAME_PATTERN: RegExp = new RegExp('播放(?:音乐|歌曲)?(.+)$');
const VOLUME_PERCENT_SUFFIX_PATTERN: RegExp = new RegExp('(\\d{1,3})(?:%|％)');
const VOLUME_PERCENT_PREFIX_PATTERN: RegExp = new RegExp('百分之(\\d{1,3})');
const VOLUME_LEVEL_PATTERN: RegExp = new RegExp('(\\d+)(?:格|档)');
const COMMAND_OBJECT_PREFIX_PATTERN: RegExp = new RegExp('^(一下|下|请|帮我)');
const COMMAND_OBJECT_SUFFIX_PATTERN: RegExp = new RegExp('(应用|软件)$');
const SUPPORTED_APP_NAMES: string[] = ['图库', '设置', '日历', '电话'];
const RULE_HIGH_CONFIDENCE_THRESHOLD: number = 0.75;
const TRANSFORMER_ASSIST_THRESHOLD: number = 0.6;

interface IntentDetection {
  intent: VoiceIntent;
  confidence: number;
  source: string;
}

export class RuleBasedSemanticUnderstanding {
  private transformerModel: TransformerModel = new TransformerModel();

  constructor(transformerModel?: TransformerModel) {
    if (transformerModel) {
      this.transformerModel = transformerModel;
    }
    if (!this.transformerModel.isModelLoaded()) {
      this.transformerModel.loadModelSync();
    }
  }

  understand(text: string): VoiceCommand {
    const command: VoiceCommand = new VoiceCommand();
    const normalizedText: string = this.normalize(text);
    const ruleDetection: IntentDetection = this.detectRuleIntent(normalizedText);
    const detection: IntentDetection = this.mergeWithTransformer(normalizedText, ruleDetection);

    command.originalText = text;
    command.timestamp = Date.now();
    command.intent = detection.intent;
    command.entities = this.extractEntities(normalizedText, detection.intent);
    command.entities.set('semantic_source', detection.source);
    command.confidence = detection.confidence;

    console.info(`语义理解结果 - 意图: ${command.intent}, 置信度: ${command.confidence}, 来源: ${detection.source}`);
    return command;
  }

  private normalize(text: string): string {
    return text.toLowerCase().replace(WHITESPACE_PATTERN, '').trim();
  }

  private detectRuleIntent(text: string): IntentDetection {
    for (let i: number = 0; i < INTENT_RULES.length; i++) {
      const rule: IntentRule = INTENT_RULES[i];
      if (this.matchesPattern(text, rule.patterns)) {
        return {
          intent: rule.intent,
          confidence: rule.patternConfidence,
          source: 'rule'
        };
      }
    }

    let bestIntent: VoiceIntent = VoiceIntent.UNKNOWN;
    let bestScore: number = 0;
    let bestKeywordCount: number = 0;

    for (let i: number = 0; i < INTENT_RULES.length; i++) {
      const rule: IntentRule = INTENT_RULES[i];
      const keywordCount: number = this.countKeywordMatches(text, rule.keywords);
      const score: number = keywordCount / Math.max(rule.keywords.length, 1);

      if (keywordCount > 0 && score > bestScore) {
        bestScore = score;
        bestIntent = rule.intent;
        bestKeywordCount = keywordCount;
      }
    }

    if (bestIntent === VoiceIntent.UNKNOWN) {
      return {
        intent: VoiceIntent.UNKNOWN,
        confidence: 0.2,
        source: 'unknown'
      };
    }

    return {
      intent: bestIntent,
      confidence: this.calculateKeywordConfidence(bestKeywordCount),
      source: 'rule_low'
    };
  }

  private mergeWithTransformer(text: string, ruleDetection: IntentDetection): IntentDetection {
    if (ruleDetection.intent !== VoiceIntent.UNKNOWN && ruleDetection.confidence >= RULE_HIGH_CONFIDENCE_THRESHOLD) {
      return {
        intent: ruleDetection.intent,
        confidence: ruleDetection.confidence,
        source: 'rule'
      };
    }

    const prediction: TransformerPrediction = this.transformerModel.predictIntent(text);
    if (prediction.intent !== VoiceIntent.UNKNOWN &&
      prediction.confidence >= TRANSFORMER_ASSIST_THRESHOLD &&
      prediction.confidence > ruleDetection.confidence) {
      return {
        intent: prediction.intent,
        confidence: prediction.confidence,
        source: 'transformer_aux'
      };
    }

    if (ruleDetection.intent !== VoiceIntent.UNKNOWN) {
      return ruleDetection;
    }

    return {
      intent: VoiceIntent.UNKNOWN,
      confidence: Math.min(ruleDetection.confidence, prediction.confidence),
      source: 'unknown'
    };
  }

  private matchesPattern(text: string, patterns: RegExp[]): boolean {
    for (let i: number = 0; i < patterns.length; i++) {
      if (patterns[i].test(text)) {
        return true;
      }
    }
    return false;
  }

  private countKeywordMatches(text: string, keywords: string[]): number {
    let matchCount: number = 0;
    for (let i: number = 0; i < keywords.length; i++) {
      if (text.includes(keywords[i])) {
        matchCount++;
      }
    }
    return matchCount;
  }

  private calculateKeywordConfidence(matchCount: number): number {
    if (matchCount >= 2) {
      return Math.min(0.75 + (matchCount - 2) * 0.05, 0.9);
    }
    return 0.6;
  }

  private extractEntities(text: string, intent: VoiceIntent): Map<string, string> {
    const entities: Map<string, string> = new Map();

    switch (intent) {
      case VoiceIntent.OPEN_APP:
        this.extractSupportedAppName(text, entities);
        break;
      case VoiceIntent.CLOSE_APP:
        this.extractAppName(text, entities);
        break;
      case VoiceIntent.SET_ALARM:
        this.extractAlarmTime(text, entities);
        break;
      case VoiceIntent.PLAY_MUSIC:
        this.extractMusicName(text, entities);
        break;
      case VoiceIntent.VOLUME_SET:
        this.extractVolumeTarget(text, entities);
        break;
      default:
        break;
    }

    return entities;
  }

  private extractAppName(text: string, entities: Map<string, string>): void {
    const appMatch: RegExpMatchArray | null = text.match(APP_NAME_PATTERN);
    if (appMatch && appMatch[1]) {
      entities.set('app_name', this.trimCommandObject(appMatch[1]));
    }
  }

  private extractSupportedAppName(text: string, entities: Map<string, string>): void {
    const appMatch: RegExpMatchArray | null = text.match(APP_NAME_PATTERN);
    if (appMatch && appMatch[1]) {
      const appName: string = this.normalizeAppName(this.trimCommandObject(appMatch[1]));
      if (appName) {
        entities.set('app_name', appName);
      }
    }
  }

  private extractAlarmTime(text: string, entities: Map<string, string>): void {
    const timeMatch: RegExpMatchArray | null = text.match(ALARM_TIME_PATTERN);
    if (timeMatch && timeMatch[1]) {
      entities.set('hour', timeMatch[1]);
      entities.set('minute', timeMatch[2] || '0');
    }
  }

  private extractMusicName(text: string, entities: Map<string, string>): void {
    const musicMatch: RegExpMatchArray | null = text.match(MUSIC_NAME_PATTERN);
    if (musicMatch && musicMatch[1]) {
      const musicName: string = this.trimCommandObject(musicMatch[1]);
      // 回溯场景下 "播放音乐" 可能捕获 "音乐"，此处过滤泛称
      if (musicName !== '音乐' && musicName !== '歌曲') {
        entities.set('music_name', musicName);
      }
    }
  }

  private normalizeAppName(value: string): string {
    const normalized: string = value === '相册' ? '图库' : value;
    for (let i: number = 0; i < SUPPORTED_APP_NAMES.length; i++) {
      if (normalized === SUPPORTED_APP_NAMES[i]) {
        return normalized;
      }
    }
    return '';
  }

  private extractVolumeTarget(text: string, entities: Map<string, string>): void {
    const percentMatch: RegExpMatchArray | null = text.match(VOLUME_PERCENT_SUFFIX_PATTERN) ||
      text.match(VOLUME_PERCENT_PREFIX_PATTERN);
    if (percentMatch && percentMatch[1]) {
      entities.set('volume_target', percentMatch[1]);
      entities.set('volume_unit', 'percent');
      return;
    }

    const levelMatch: RegExpMatchArray | null = text.match(VOLUME_LEVEL_PATTERN);
    if (levelMatch && levelMatch[1]) {
      entities.set('volume_target', levelMatch[1]);
      entities.set('volume_unit', 'level');
    }
  }

  private trimCommandObject(value: string): string {
    return value.replace(COMMAND_OBJECT_PREFIX_PATTERN, '').replace(COMMAND_OBJECT_SUFFIX_PATTERN, '').trim();
  }
}

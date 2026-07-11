import { IFlytekConfig } from '../../config/IFlytekConfig';
import { VoiceCommand } from '../../model/VoiceCommand';
import { VoiceIntent } from './VoiceIntent';
import { SemanticUnderstandingService } from './SemanticUnderstandingService';
import { IFlytekSparkChatClient, SparkChatClient } from './SparkChatClient';
import { SparkChatRequest, SparkChatResponse, SparkIntentEntities, SparkIntentResult } from './SparkIntentTypes';

const MIN_CONFIDENCE: number = 0.6;
const SUPPORTED_APPS: string[] = ['图库', '设置', '日历', '电话'];
const SYSTEM_PROMPT: string = '你是语音助手意图分类器。只输出JSON，不要解释。' +
  'intent只能是time_query,weather_query,play_music,stop_music,next_music,volume_up,volume_down,volume_set,' +
  'set_alarm,open_app,close_app,accuracy_evaluation,unknown。' +
  '输出格式为{"intent":"unknown","confidence":0.0,"entities":{}}。' +
  'open_app仅支持图库、设置、日历、电话，相册归一化为图库。' +
  'volume_set实体使用volume_target和volume_unit，unit只能是percent或level；裸整数如调到3表示level。' +
  'set_alarm实体使用hour和minute；play_music使用music_name；打开或关闭应用使用app_name。' +
  '不确定时必须返回unknown，禁止猜测。';

export class SparkIntentClassifier implements SemanticUnderstandingService {
  private client: SparkChatClient;

  constructor(client: SparkChatClient = new IFlytekSparkChatClient()) {
    this.client = client;
  }

  async understand(text: string): Promise<VoiceCommand> {
    try {
      const response: SparkChatResponse = await this.client.complete(this.createRequest(text));
      return this.parseResponse(text, response);
    } catch (error) {
      console.error(`Spark 意图识别失败: ${(error as Error).message}`);
      return this.createUnknownCommand(text);
    }
  }

  private createRequest(text: string): SparkChatRequest {
    return {
      model: IFlytekConfig.sparkModel,
      messages: [
        { role: 'user', content: `${SYSTEM_PROMPT}\n待识别语音：${text}` }
      ],
      temperature: 0,
      max_tokens: 160,
      stream: false,
      response_format: { type: 'json_object' }
    };
  }

  private parseResponse(text: string, response: SparkChatResponse): VoiceCommand {
    if (!response.choices || response.choices.length === 0) {
      throw new Error(response.message || 'Spark 未返回候选结果');
    }
    const result: SparkIntentResult = JSON.parse(response.choices[0].message.content) as SparkIntentResult;
    const intent: VoiceIntent = this.parseIntent(result.intent);
    if (intent === VoiceIntent.UNKNOWN || !Number.isFinite(result.confidence) || result.confidence < MIN_CONFIDENCE) {
      return this.createUnknownCommand(text);
    }

    const command: VoiceCommand = new VoiceCommand(intent, text);
    command.confidence = Math.min(result.confidence, 1);
    command.setEntity('semantic_source', 'spark_lite');
    this.copyValidatedEntities(command, intent, result.entities);
    if (!this.hasRequiredEntities(command, intent)) {
      return this.createUnknownCommand(text);
    }
    return command;
  }

  private parseIntent(value: string): VoiceIntent {
    const intents: VoiceIntent[] = [VoiceIntent.TIME_QUERY, VoiceIntent.WEATHER_QUERY, VoiceIntent.PLAY_MUSIC,
      VoiceIntent.STOP_MUSIC, VoiceIntent.NEXT_MUSIC, VoiceIntent.VOLUME_UP, VoiceIntent.VOLUME_DOWN,
      VoiceIntent.VOLUME_SET, VoiceIntent.SET_ALARM, VoiceIntent.OPEN_APP, VoiceIntent.CLOSE_APP,
      VoiceIntent.ACCURACY_EVALUATION];
    for (let i: number = 0; i < intents.length; i++) {
      if (value === intents[i]) {
        return intents[i];
      }
    }
    return VoiceIntent.UNKNOWN;
  }

  private copyValidatedEntities(command: VoiceCommand, intent: VoiceIntent, entities?: SparkIntentEntities): void {
    if (!entities) {
      return;
    }
    if (intent === VoiceIntent.OPEN_APP && entities.app_name) {
      const appName: string = entities.app_name === '相册' ? '图库' : entities.app_name;
      if (this.includes(SUPPORTED_APPS, appName)) {
        command.setEntity('app_name', appName);
      }
    } else if (intent === VoiceIntent.CLOSE_APP && entities.app_name) {
      command.setEntity('app_name', entities.app_name);
    } else if (intent === VoiceIntent.PLAY_MUSIC && entities.music_name) {
      command.setEntity('music_name', entities.music_name);
    } else if (intent === VoiceIntent.SET_ALARM && entities.hour) {
      const hour: number = Number(entities.hour);
      const minute: number = Number(entities.minute || '0');
      if (Number.isInteger(hour) && hour >= 0 && hour <= 23 &&
        Number.isInteger(minute) && minute >= 0 && minute <= 59) {
        command.setEntity('hour', entities.hour);
        command.setEntity('minute', entities.minute || '0');
      }
    } else if (intent === VoiceIntent.VOLUME_SET && entities.volume_target &&
      (entities.volume_unit === 'percent' || entities.volume_unit === 'level')) {
      const target: number = Number(entities.volume_target);
      const isValidPercent: boolean = entities.volume_unit === 'percent' && target >= 0 && target <= 100;
      const isValidLevel: boolean = entities.volume_unit === 'level' && target >= 0;
      if (Number.isInteger(target) && (isValidPercent || isValidLevel)) {
        command.setEntity('volume_target', entities.volume_target);
        command.setEntity('volume_unit', entities.volume_unit);
      }
    }
  }

  private hasRequiredEntities(command: VoiceCommand, intent: VoiceIntent): boolean {
    if (intent === VoiceIntent.OPEN_APP || intent === VoiceIntent.CLOSE_APP) {
      return command.hasEntity('app_name');
    }
    if (intent === VoiceIntent.SET_ALARM) {
      return command.hasEntity('hour');
    }
    if (intent === VoiceIntent.VOLUME_SET) {
      return command.hasEntity('volume_target') && command.hasEntity('volume_unit');
    }
    return true;
  }

  private includes(values: string[], target: string): boolean {
    for (let i: number = 0; i < values.length; i++) {
      if (values[i] === target) {
        return true;
      }
    }
    return false;
  }

  private createUnknownCommand(text: string): VoiceCommand {
    const command: VoiceCommand = new VoiceCommand(VoiceIntent.UNKNOWN, text);
    command.confidence = 0;
    command.setEntity('semantic_source', 'spark_lite_failed');
    return command;
  }
}

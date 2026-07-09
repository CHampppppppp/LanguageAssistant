import { VoiceCommand } from '../model/VoiceCommand';

export class SemanticUnderstanding {
  private commandPatterns: Map<string, RegExp> = new Map();
  private intentKeywords: Map<string, string[]> = new Map();

  constructor() {
    this.initPatterns();
    this.initKeywords();
  }

  private initPatterns(): void {
    this.commandPatterns.set('play_music', new RegExp('播放音乐|播放歌曲|听歌'));
    this.commandPatterns.set('stop_music', new RegExp('停止播放|暂停音乐|停止音乐'));
    this.commandPatterns.set('next_music', new RegExp('下一首|切歌|下一曲'));
    this.commandPatterns.set('volume_up', new RegExp('音量调大|增大音量|声音大点'));
    this.commandPatterns.set('volume_down', new RegExp('音量调小|减小音量|声音小点'));
    this.commandPatterns.set('open_app', new RegExp('打开.*应用|启动.*软件'));
    this.commandPatterns.set('close_app', new RegExp('关闭.*应用|退出.*软件'));
    this.commandPatterns.set('set_alarm', new RegExp('设置闹钟|定个闹钟'));
    this.commandPatterns.set('weather_query', new RegExp('天气怎么样|查询天气|今天天气'));
    this.commandPatterns.set('time_query', new RegExp('现在几点|当前时间|几点了'));
  }

  private initKeywords(): void {
    this.intentKeywords.set('play_music', ['播放', '音乐', '歌曲', '听歌']);
    this.intentKeywords.set('stop_music', ['停止', '暂停', '结束']);
    this.intentKeywords.set('volume_up', ['音量', '大', '调高', '增加']);
    this.intentKeywords.set('volume_down', ['音量', '小', '调低', '减少']);
    this.intentKeywords.set('weather_query', ['天气', '温度', '下雨']);
    this.intentKeywords.set('time_query', ['时间', '几点', '时刻']);
  }

  understand(text: string): VoiceCommand {
    const command = new VoiceCommand();
    command.originalText = text;
    command.timestamp = Date.now();

    const normalizedText = text.toLowerCase().trim();

    const intent = this.detectIntent(normalizedText);
    command.intent = intent;

    const entities = this.extractEntities(normalizedText, intent);
    command.entities = entities;

    command.confidence = this.calculateConfidence(normalizedText, intent);

    console.info(`语义理解结果 - 意图: ${intent}, 置信度: ${command.confidence}`);
    return command;
  }

  private detectIntent(text: string): string {
    const patternKeys = Array.from(this.commandPatterns.keys());
    for (let i = 0; i < patternKeys.length; i++) {
      const intent = patternKeys[i];
      const pattern = this.commandPatterns.get(intent);
      if (pattern && pattern.test(text)) {
        return intent;
      }
    }

    let maxScore = 0;
    let bestIntent = 'unknown';

    const keywordKeys = Array.from(this.intentKeywords.keys());
    for (let i = 0; i < keywordKeys.length; i++) {
      const intent = keywordKeys[i];
      const keywords = this.intentKeywords.get(intent);
      if (!keywords) continue;

      let score = 0;
      for (let j = 0; j < keywords.length; j++) {
        if (text.includes(keywords[j])) {
          score += 1;
        }
      }
      if (score > maxScore) {
        maxScore = score;
        bestIntent = intent;
      }
    }

    return bestIntent;
  }



  private extractEntities(text: string, intent: string): Map<string, string> {
    const entities = new Map<string, string>();

    switch (intent) {
      case 'open_app':
      case 'close_app':
        const appMatch = text.match(new RegExp('(打开|启动|关闭|退出)(.+?)(应用|软件)?'));
        if (appMatch && appMatch[2]) {
          entities.set('app_name', appMatch[2].trim());
        }
        break;
      case 'set_alarm':
        const timeMatch = text.match(new RegExp('(\\d{1,2})[点:](\\d{2})?'));
        if (timeMatch) {
          entities.set('hour', timeMatch[1]);
          if (timeMatch[2]) {
            entities.set('minute', timeMatch[2]);
          }
        }
        break;
      case 'play_music':
        const musicMatch = text.match(new RegExp('播放(?:音乐|歌曲)?(.+)?'));
        if (musicMatch && musicMatch[1]) {
          entities.set('music_name', musicMatch[1].trim());
        }
        break;
    }

    return entities;
  }

  private calculateConfidence(text: string, intent: string): number {
    if (intent === 'unknown') {
      return 0.3;
    }

    const pattern = this.commandPatterns.get(intent);
    if (pattern && pattern.test(text)) {
      return 0.95;
    }

    const keywords = this.intentKeywords.get(intent) || [];
    let matchCount = 0;
    keywords.forEach(keyword => {
      if (text.includes(keyword)) {
        matchCount++;
      }
    });

    return Math.min(0.5 + matchCount * 0.15, 0.9);
  }
}
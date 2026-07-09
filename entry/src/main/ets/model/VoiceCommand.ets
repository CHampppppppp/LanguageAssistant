interface VoiceCommandData {
  intent: string;
  originalText: string;
  entities: Record<string, string>;
  confidence: number;
  timestamp: number;
  priority: number;
}

export class VoiceCommand {
  intent: string = '';
  originalText: string = '';
  entities: Map<string, string> = new Map();
  confidence: number = 0;
  timestamp: number = 0;
  priority: number = 1;

  constructor(intent?: string, text?: string) {
    if (intent) {
      this.intent = intent;
    }
    if (text) {
      this.originalText = text;
    }
    this.timestamp = Date.now();
  }

  getEntity(key: string): string {
    return this.entities.get(key) || '';
  }

  setEntity(key: string, value: string): void {
    this.entities.set(key, value);
  }

  hasEntity(key: string): boolean {
    return this.entities.has(key);
  }

  toJSON(): string {
    const entitiesObj: Record<string, string> = {};
    const keys: Array<string> = Array.from(this.entities.keys());
    for (let i: number = 0; i < keys.length; i++) {
      const key: string = keys[i];
      const value: string = this.entities.get(key) || '';
      entitiesObj[key] = value;
    }

    return JSON.stringify({
      intent: this.intent,
      originalText: this.originalText,
      entities: entitiesObj,
      confidence: this.confidence,
      timestamp: this.timestamp,
      priority: this.priority
    });
  }

  static fromJSON(json: string): VoiceCommand {
    const data: VoiceCommandData = JSON.parse(json) as VoiceCommandData;
    const command: VoiceCommand = new VoiceCommand(data.intent, data.originalText);
    command.confidence = data.confidence || 0;
    command.timestamp = data.timestamp || Date.now();
    command.priority = data.priority || 1;

    if (data.entities) {
      const entityKeys: Array<string> = Object.keys(data.entities);
      for (let i: number = 0; i < entityKeys.length; i++) {
        const key: string = entityKeys[i];
        command.entities.set(key, data.entities[key]);
      }
    }

    return command;
  }

  isValid(): boolean {
    return this.intent !== '' && this.intent !== 'unknown' && this.confidence >= 0.5;
  }
}
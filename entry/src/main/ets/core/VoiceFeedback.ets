import { BusinessError } from '@kit.BasicServicesKit';

export class VoiceFeedback {
  constructor() {
  }

  async speak(text: string): Promise<void> {
    console.info(`语音反馈文本: ${text}`);
  }

  async playSystemSound(soundType: string): Promise<void> {
    console.info(`播放系统提示音: ${soundType}`);
  }

  release(): void {
  }
}
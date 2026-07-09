export class VoiceFeedback {
  constructor() {
  }

  async speak(text: string): Promise<void> {
    console.info(`模拟语音反馈文本: ${text}`);
  }

  async playSystemSound(soundType: string): Promise<void> {
    console.info(`模拟播放系统提示音: ${soundType}`);
  }

  release(): void {
  }
}

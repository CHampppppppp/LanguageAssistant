import { VoiceCommand } from '../model/VoiceCommand';

export class CommandExecutor {
  private executionResults: Map<string, string> = new Map();

  async execute(command: VoiceCommand): Promise<string> {
    console.info(`执行指令: ${command.intent}`);
    const startTime = Date.now();

    let result = '';
    switch (command.intent) {
      case 'play_music':
        result = await this.playMusic(command);
        break;
      case 'stop_music':
        result = await this.stopMusic();
        break;
      case 'next_music':
        result = await this.nextMusic();
        break;
      case 'volume_up':
        result = await this.volumeUp(command);
        break;
      case 'volume_down':
        result = await this.volumeDown(command);
        break;
      case 'open_app':
        result = await this.openApp(command);
        break;
      case 'close_app':
        result = await this.closeApp(command);
        break;
      case 'set_alarm':
        result = await this.setAlarm(command);
        break;
      case 'weather_query':
        result = await this.queryWeather();
        break;
      case 'time_query':
        result = await this.queryTime();
        break;
      default:
        result = '抱歉，我不理解您的指令';
        break;
    }

    const duration = Date.now() - startTime;
    console.info(`指令执行耗时: ${duration}ms`);
    this.executionResults.set(command.intent, result);
    return result;
  }

  private async playMusic(command: VoiceCommand): Promise<string> {
    const musicName = command.entities.get('music_name') || '随机音乐';
    return `正在播放${musicName}`;
  }

  private async stopMusic(): Promise<string> {
    return '音乐已停止播放';
  }

  private async nextMusic(): Promise<string> {
    return '已切换到下一首歌曲';
  }

  private async volumeUp(command: VoiceCommand): Promise<string> {
    return '音量已调大';
  }

  private async volumeDown(command: VoiceCommand): Promise<string> {
    return '音量已调小';
  }

  private async openApp(command: VoiceCommand): Promise<string> {
    const appName = command.entities.get('app_name') || '';
    if (appName) {
      return `正在打开${appName}`;
    }
    return '请指定要打开的应用名称';
  }

  private async closeApp(command: VoiceCommand): Promise<string> {
    const appName = command.entities.get('app_name') || '';
    if (appName) {
      return `正在关闭${appName}`;
    }
    return '请指定要关闭的应用名称';
  }

  private async setAlarm(command: VoiceCommand): Promise<string> {
    const hour = command.entities.get('hour') || '0';
    const minute = command.entities.get('minute') || '0';
    return `闹钟已设置为${hour}点${minute}分`;
  }

  private async queryWeather(): Promise<string> {
    return '今天天气晴朗，温度 25 度';
  }

  private async queryTime(): Promise<string> {
    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    return `现在是${hours}点${minutes}分`;
  }

  getExecutionResult(intent: string): string {
    return this.executionResults.get(intent) || '';
  }

  clearResults(): void {
    this.executionResults.clear();
  }
}
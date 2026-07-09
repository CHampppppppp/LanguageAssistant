import { VoiceCommand } from '../../model/VoiceCommand';
import { CommandExecutionResult, CommandExecutionStatus } from './CommandResult';

export class MockCommandExecutor {
  async execute(command: VoiceCommand): Promise<CommandExecutionResult> {
    switch (command.intent) {
      case 'time_query':
        return this.queryTime(command.intent);
      case 'play_music':
        return this.simulate(command.intent, `模拟播放${command.entities.get('music_name') || '随机音乐'}`);
      case 'stop_music':
        return this.simulate(command.intent, '模拟停止音乐播放');
      case 'next_music':
        return this.simulate(command.intent, '模拟切换到下一首歌曲');
      case 'volume_up':
        return this.simulate(command.intent, '模拟调大系统音量');
      case 'volume_down':
        return this.simulate(command.intent, '模拟调小系统音量');
      case 'open_app':
        return this.simulate(command.intent, command.entities.get('app_name') ? `模拟打开${command.entities.get('app_name')}` : '请指定要打开的应用名称');
      case 'close_app':
        return this.simulate(command.intent, command.entities.get('app_name') ? `模拟关闭${command.entities.get('app_name')}` : '请指定要关闭的应用名称');
      case 'set_alarm':
        return this.simulate(command.intent, `模拟设置闹钟为${command.entities.get('hour') || '0'}点${command.entities.get('minute') || '0'}分`);
      case 'weather_query':
        return this.simulate(command.intent, '模拟天气：晴，25 度');
      default:
        return {
          status: CommandExecutionStatus.UNSUPPORTED,
          message: '抱歉，我不理解您的指令',
          intent: command.intent,
          isSimulated: false
        };
    }
  }

  private queryTime(intent: string): CommandExecutionResult {
    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');

    return {
      status: CommandExecutionStatus.SUCCESS,
      message: `现在是${hours}点${minutes}分`,
      intent,
      isSimulated: false
    };
  }

  private simulate(intent: string, message: string): CommandExecutionResult {
    return {
      status: CommandExecutionStatus.SIMULATED,
      message,
      intent,
      isSimulated: true
    };
  }
}

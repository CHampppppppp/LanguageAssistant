import { VoiceCommand } from '../../model/VoiceCommand';
import { CommandExecutionResult, CommandExecutionStatus } from './CommandResult';
import { TimeProvider, TimeQueryService } from './TimeQuery';
import { VolumeControlService, VolumeController, VolumeDirection } from './VolumeControl';

export class MockCommandExecutor {
  private timeQueryService: TimeQueryService;
  private volumeControlService: VolumeControlService;

  constructor(timeProvider?: TimeProvider, volumeController?: VolumeController) {
    this.timeQueryService = timeProvider ? new TimeQueryService(timeProvider) : new TimeQueryService();
    this.volumeControlService = volumeController ? new VolumeControlService(volumeController) : new VolumeControlService();
  }

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
        return this.adjustVolume(command.intent, VolumeDirection.UP);
      case 'volume_down':
        return this.adjustVolume(command.intent, VolumeDirection.DOWN);
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
    return {
      status: CommandExecutionStatus.SUCCESS,
      message: this.timeQueryService.getCurrentTimeMessage(),
      intent,
      isSimulated: false
    };
  }

  private async adjustVolume(intent: string, direction: VolumeDirection): Promise<CommandExecutionResult> {
    return this.volumeControlService.adjust(direction, intent);
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

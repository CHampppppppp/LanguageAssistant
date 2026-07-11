import { VoiceCommand } from '../../model/VoiceCommand';
import { VoiceIntent } from '../nlu/VoiceIntent';
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
        return this.playMusic(command);
      case 'stop_music':
        return this.simulate(command.intent, '模拟停止音乐播放');
      case 'next_music':
        return this.simulate(command.intent, '模拟切换到下一首歌曲');
      case 'volume_up':
        return this.adjustVolume(command.intent, VolumeDirection.UP);
      case 'volume_down':
        return this.adjustVolume(command.intent, VolumeDirection.DOWN);
      case 'open_app':
        return this.openApp(command);
      case 'close_app':
        return this.closeApp(command);
      case 'set_alarm':
        return this.setAlarm(command);
      case 'weather_query':
        return this.queryWeather(command.intent);
      case VoiceIntent.ACCURACY_EVALUATION:
        return this.openEvaluationPanel(command.intent);
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

  private playMusic(command: VoiceCommand): CommandExecutionResult {
    const musicName: string = command.getEntity('music_name') || '随机音乐';
    return this.simulate(command.intent, `模拟播放${musicName}`);
  }

  private openApp(command: VoiceCommand): CommandExecutionResult {
    const appName: string = command.getEntity('app_name');
    if (!appName) {
      return this.fail(command.intent, '请指定要打开的应用名称');
    }
    return this.simulate(command.intent, `模拟打开${appName}`);
  }

  private closeApp(command: VoiceCommand): CommandExecutionResult {
    const appName: string = command.getEntity('app_name');
    if (!appName) {
      return this.fail(command.intent, '请指定要关闭的应用名称');
    }
    return this.simulate(command.intent, `模拟关闭${appName}`);
  }

  private setAlarm(command: VoiceCommand): CommandExecutionResult {
    const hour: string = command.getEntity('hour');
    if (!hour) {
      return this.fail(command.intent, '请指定闹钟时间');
    }

    const minute: string = command.getEntity('minute') || '0';
    return this.simulate(command.intent, `模拟设置闹钟为${hour}点${minute}分`);
  }

  private queryWeather(intent: string): CommandExecutionResult {
    return this.simulate(intent, '模拟天气：晴，25 度');
  }

  private openEvaluationPanel(intent: string): CommandExecutionResult {
    return {
      status: CommandExecutionStatus.SUCCESS,
      message: '已打开 LibriSpeech 英文评测模块',
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

  private fail(intent: string, message: string): CommandExecutionResult {
    return {
      status: CommandExecutionStatus.FAILED,
      message,
      intent,
      isSimulated: false
    };
  }
}

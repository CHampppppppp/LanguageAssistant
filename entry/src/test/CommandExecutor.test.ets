import { describe, it, expect } from '@ohos/hypium';
import { MockCommandExecutor } from '../main/ets/core/command/CommandExecutor';
import { CommandExecutionStatus } from '../main/ets/core/command/CommandResult';
import { TimeProvider } from '../main/ets/core/command/TimeQuery';
import { VolumeController, VolumeState } from '../main/ets/core/command/VolumeControl';
import { VoiceIntent } from '../main/ets/core/nlu/VoiceIntent';
import { VoiceCommand } from '../main/ets/model/VoiceCommand';

class FixedTimeProvider implements TimeProvider {
  now(): Date {
    return new Date(2026, 6, 9, 8, 5, 0);
  }
}

class FakeVolumeController implements VolumeController {
  private current: number;
  private shouldFail: boolean;
  lastSetVolume: number = -1;

  constructor(current: number, shouldFail: boolean = false) {
    this.current = current;
    this.shouldFail = shouldFail;
  }

  async getVolumeState(): Promise<VolumeState> {
    if (this.shouldFail) {
      throw new Error('volume api unavailable');
    }
    return {
      current: this.current,
      min: 0,
      max: 10
    };
  }

  async setVolume(volume: number): Promise<void> {
    if (this.shouldFail) {
      throw new Error('volume api unavailable');
    }
    this.current = volume;
    this.lastSetVolume = volume;
  }

  isSystemBacked(): boolean {
    return true;
  }
}

export default function commandExecutorTest() {
  describe('commandExecutorTest', () => {
    it('returns real local time for time query', 0, async () => {
      const executor = new MockCommandExecutor(new FixedTimeProvider());
      const command = new VoiceCommand('time_query', '现在几点了');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SUCCESS);
      expect(result.intent).assertEqual('time_query');
      expect(result.isSimulated).assertFalse();
      expect(result.message).assertEqual('现在是08点05分');
    });

    it('raises system volume through injected volume controller', 0, async () => {
      const volumeController = new FakeVolumeController(5);
      const executor = new MockCommandExecutor(new FixedTimeProvider(), volumeController);
      const command = new VoiceCommand('volume_up', '音量调大');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SUCCESS);
      expect(result.intent).assertEqual('volume_up');
      expect(result.isSimulated).assertFalse();
      expect(volumeController.lastSetVolume).assertEqual(6);
      expect(result.message).assertEqual('音量已调大到 6/10');
    });

    it('marks default volume control as simulated when system adapter is not connected', 0, async () => {
      const executor = new MockCommandExecutor(new FixedTimeProvider());
      const command = new VoiceCommand('volume_down', '音量调小');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SIMULATED);
      expect(result.intent).assertEqual('volume_down');
      expect(result.isSimulated).assertTrue();
      expect(result.message).assertContain('模拟');
    });

    it('returns failed result when system volume control throws', 0, async () => {
      const volumeController = new FakeVolumeController(5, true);
      const executor = new MockCommandExecutor(new FixedTimeProvider(), volumeController);
      const command = new VoiceCommand('volume_up', '音量调大');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.FAILED);
      expect(result.intent).assertEqual('volume_up');
      expect(result.isSimulated).assertFalse();
      expect(result.message).assertContain('音量控制失败');
    });

    it('marks weather query as simulated with clear source boundary', 0, async () => {
      const executor = new MockCommandExecutor(new FixedTimeProvider());
      const command = new VoiceCommand('weather_query', '今天天气怎么样');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SIMULATED);
      expect(result.intent).assertEqual('weather_query');
      expect(result.isSimulated).assertTrue();
      expect(result.message).assertContain('模拟天气');
    });

    it('sets volume from percentage using system range', 0, async () => {
      const volumeController = new FakeVolumeController(5);
      const executor = new MockCommandExecutor(new FixedTimeProvider(), volumeController);
      const command = new VoiceCommand(VoiceIntent.VOLUME_SET, '把音量调到30%');
      command.setEntity('volume_target', '30');
      command.setEntity('volume_unit', 'percent');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SUCCESS);
      expect(volumeController.lastSetVolume).assertEqual(3);
      expect(result.message).assertEqual('音量已设置为 3/10');
    });

    it('sets volume from absolute level', 0, async () => {
      const volumeController = new FakeVolumeController(5);
      const executor = new MockCommandExecutor(new FixedTimeProvider(), volumeController);
      const command = new VoiceCommand(VoiceIntent.VOLUME_SET, '声音设置为8档');
      command.setEntity('volume_target', '8');
      command.setEntity('volume_unit', 'level');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SUCCESS);
      expect(volumeController.lastSetVolume).assertEqual(8);
    });

    it('rejects out of range volume percentage', 0, async () => {
      const volumeController = new FakeVolumeController(5);
      const executor = new MockCommandExecutor(new FixedTimeProvider(), volumeController);
      const command = new VoiceCommand(VoiceIntent.VOLUME_SET, '把音量调到120%');
      command.setEntity('volume_target', '120');
      command.setEntity('volume_unit', 'percent');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.FAILED);
      expect(volumeController.lastSetVolume).assertEqual(-1);
      expect(result.message).assertContain('0 到 100');
    });

    it('opens evaluation panel for accuracy evaluation command', 0, async () => {
      const executor = new MockCommandExecutor(new FixedTimeProvider());
      const command = new VoiceCommand(VoiceIntent.ACCURACY_EVALUATION, '准确率评测');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SUCCESS);
      expect(result.intent).assertEqual(VoiceIntent.ACCURACY_EVALUATION);
      expect(result.isSimulated).assertFalse();
      expect(result.message).assertContain('评测模块');
    });

    it('marks music commands as simulated', 0, async () => {
      const executor = new MockCommandExecutor(new FixedTimeProvider());
      const command = new VoiceCommand('play_music', '播放周杰伦的歌');
      command.setEntity('music_name', '周杰伦的歌');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SIMULATED);
      expect(result.intent).assertEqual('play_music');
      expect(result.isSimulated).assertTrue();
      expect(result.message).assertEqual('模拟播放周杰伦的歌');
    });

    it('marks alarm command as simulated and uses extracted time', 0, async () => {
      const executor = new MockCommandExecutor(new FixedTimeProvider());
      const command = new VoiceCommand('set_alarm', '设置8点30分闹钟');
      command.setEntity('hour', '8');
      command.setEntity('minute', '30');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SIMULATED);
      expect(result.intent).assertEqual('set_alarm');
      expect(result.isSimulated).assertTrue();
      expect(result.message).assertEqual('模拟设置闹钟为8点30分');
    });

    it('marks open app command as simulated when app name exists', 0, async () => {
      const executor = new MockCommandExecutor(new FixedTimeProvider());
      const command = new VoiceCommand('open_app', '打开微信');
      command.setEntity('app_name', '微信');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SIMULATED);
      expect(result.intent).assertEqual('open_app');
      expect(result.isSimulated).assertTrue();
      expect(result.message).assertEqual('模拟打开微信');
    });

    it('fails open app command when app name is missing', 0, async () => {
      const executor = new MockCommandExecutor(new FixedTimeProvider());
      const command = new VoiceCommand('open_app', '打开应用');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.FAILED);
      expect(result.intent).assertEqual('open_app');
      expect(result.isSimulated).assertFalse();
      expect(result.message).assertEqual('请指定要打开的应用名称');
    });

    it('returns unsupported for unknown command intent', 0, async () => {
      const executor = new MockCommandExecutor(new FixedTimeProvider());
      const command = new VoiceCommand('unknown', '随便说一句没意义的话');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.UNSUPPORTED);
      expect(result.intent).assertEqual('unknown');
      expect(result.isSimulated).assertFalse();
    });
  });
}

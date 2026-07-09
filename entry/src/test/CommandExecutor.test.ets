import { describe, it, expect } from '@ohos/hypium';
import { MockCommandExecutor } from '../main/ets/core/command/CommandExecutor';
import { CommandExecutionStatus } from '../main/ets/core/command/CommandResult';
import { TimeProvider } from '../main/ets/core/command/TimeQuery';
import { VolumeController, VolumeState } from '../main/ets/core/command/VolumeControl';
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
  });
}

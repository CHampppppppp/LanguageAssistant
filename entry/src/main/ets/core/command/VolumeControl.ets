import { CommandExecutionResult, CommandExecutionStatus } from './CommandResult';

export enum VolumeDirection {
  UP = 'up',
  DOWN = 'down'
}

export enum VolumeTargetUnit {
  PERCENT = 'percent',
  LEVEL = 'level'
}

export interface VolumeState {
  current: number;
  min: number;
  max: number;
}

export interface VolumeController {
  getVolumeState(): Promise<VolumeState>;
  setVolume(volume: number): Promise<void>;
  isSystemBacked(): boolean;
}

export class SimulatedVolumeController implements VolumeController {
  private current: number = 5;
  private min: number = 0;
  private max: number = 10;

  async getVolumeState(): Promise<VolumeState> {
    return {
      current: this.current,
      min: this.min,
      max: this.max
    };
  }

  async setVolume(volume: number): Promise<void> {
    this.current = this.clamp(volume, this.min, this.max);
  }

  isSystemBacked(): boolean {
    return false;
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }
}

export class VolumeControlService {
  private volumeController: VolumeController;
  private step: number;

  constructor(volumeController: VolumeController = new SimulatedVolumeController(), step: number = 1) {
    this.volumeController = volumeController;
    this.step = step;
  }

  async adjust(direction: VolumeDirection, intent: string): Promise<CommandExecutionResult> {
    try {
      const state: VolumeState = await this.volumeController.getVolumeState();
      const nextVolume: number = this.calculateNextVolume(state, direction);
      await this.volumeController.setVolume(nextVolume);

      return {
        status: this.volumeController.isSystemBacked() ? CommandExecutionStatus.SUCCESS : CommandExecutionStatus.SIMULATED,
        message: this.createSuccessMessage(direction, nextVolume, state.max),
        intent,
        isSimulated: !this.volumeController.isSystemBacked()
      };
    } catch (error) {
      return {
        status: CommandExecutionStatus.FAILED,
        message: `音量控制失败：${(error as Error).message}`,
        intent,
        isSimulated: false
      };
    }
  }

  async setTarget(target: number, unit: VolumeTargetUnit, intent: string): Promise<CommandExecutionResult> {
    try {
      const state: VolumeState = await this.volumeController.getVolumeState();
      const targetVolume: number = this.calculateTargetVolume(target, unit, state);
      await this.volumeController.setVolume(targetVolume);

      return {
        status: this.volumeController.isSystemBacked() ? CommandExecutionStatus.SUCCESS : CommandExecutionStatus.SIMULATED,
        message: this.createTargetSuccessMessage(targetVolume, state.max),
        intent,
        isSimulated: !this.volumeController.isSystemBacked()
      };
    } catch (error) {
      return {
        status: CommandExecutionStatus.FAILED,
        message: `音量控制失败：${(error as Error).message}`,
        intent,
        isSimulated: false
      };
    }
  }

  private calculateNextVolume(state: VolumeState, direction: VolumeDirection): number {
    const delta: number = direction === VolumeDirection.UP ? this.step : -this.step;
    return this.clamp(state.current + delta, state.min, state.max);
  }

  private createSuccessMessage(direction: VolumeDirection, volume: number, max: number): string {
    const action: string = direction === VolumeDirection.UP ? '调大' : '调小';
    const simulatedPrefix: string = this.volumeController.isSystemBacked() ? '' : '模拟';
    return `${simulatedPrefix}音量已${action}到 ${volume}/${max}`;
  }

  private calculateTargetVolume(target: number, unit: VolumeTargetUnit, state: VolumeState): number {
    if (!Number.isInteger(target)) {
      throw new Error('目标音量必须是整数');
    }
    if (unit === VolumeTargetUnit.PERCENT) {
      if (target < 0 || target > 100) {
        throw new Error('音量百分比必须在 0 到 100 之间');
      }
      return Math.round(state.min + (state.max - state.min) * target / 100);
    }
    if (target < state.min || target > state.max) {
      throw new Error(`音量档位必须在 ${state.min} 到 ${state.max} 之间`);
    }
    return target;
  }

  private createTargetSuccessMessage(volume: number, max: number): string {
    const simulatedPrefix: string = this.volumeController.isSystemBacked() ? '' : '模拟';
    return `${simulatedPrefix}音量已设置为 ${volume}/${max}`;
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }
}

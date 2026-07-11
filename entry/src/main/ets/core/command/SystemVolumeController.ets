import { audio } from '@kit.AudioKit';
import { VolumeController, VolumeState } from './VolumeControl';

export class SystemVolumeController implements VolumeController {
  private audioManager: audio.AudioManager = audio.getAudioManager();
  private volumeType: audio.AudioVolumeType = audio.AudioVolumeType.MEDIA;

  async getVolumeState(): Promise<VolumeState> {
    const current: number = await this.audioManager.getVolume(this.volumeType);
    const min: number = await this.audioManager.getMinVolume(this.volumeType);
    const max: number = await this.audioManager.getMaxVolume(this.volumeType);
    return { current, min, max };
  }

  async setVolume(volume: number): Promise<void> {
    await this.audioManager.setVolume(this.volumeType, volume);
  }

  isSystemBacked(): boolean {
    return true;
  }
}

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export default class EntryAbility extends UIAbility {
  private TAG: string = 'EntryAbility';
  private domain: number = 0x0000;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(this.domain, this.TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(this.domain, this.TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(this.domain, this.TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        hilog.error(this.domain, this.TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(this.domain, this.TAG, 'Succeeded in loading content. Data: %{public}s', JSON.stringify(data) ?? '');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(this.domain, this.TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(this.domain, this.TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(this.domain, this.TAG, 'Ability onBackground');
  }
}
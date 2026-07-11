import { common, Want } from '@kit.AbilityKit';

export interface AppLauncher {
  launch(appName: string): Promise<void>;
}

interface AppLaunchTarget {
  bundleName: string;
  abilityName: string;
}

const GALLERY_TARGETS: AppLaunchTarget[] = [
  { bundleName: 'com.huawei.hmos.photos', abilityName: 'com.huawei.hmos.photos.MainAbility' },
  { bundleName: 'com.ohos.photos', abilityName: 'com.ohos.photos.MainAbility' }
];
const SETTINGS_TARGETS: AppLaunchTarget[] = [
  { bundleName: 'com.huawei.hmos.settings', abilityName: 'com.huawei.hmos.settings.MainAbility' },
  { bundleName: 'com.ohos.settings', abilityName: 'com.ohos.settings.MainAbility' }
];
const CALENDAR_TARGETS: AppLaunchTarget[] = [
  { bundleName: 'com.huawei.hmos.calendar', abilityName: 'com.huawei.hmos.calendar.MainAbility' },
  { bundleName: 'com.ohos.calendar', abilityName: 'com.ohos.calendar.MainAbility' }
];
const PHONE_TARGETS: AppLaunchTarget[] = [
  { bundleName: 'com.huawei.hmos.contacts', abilityName: 'com.huawei.hmos.contacts.MainAbility' },
  { bundleName: 'com.ohos.contacts', abilityName: 'com.ohos.contacts.MainAbility' }
];
const BROWSER_TARGETS: AppLaunchTarget[] = [
  { bundleName: 'com.huawei.hmos.browser', abilityName: 'com.huawei.hmos.browser.MainAbility' },
  { bundleName: 'com.ohos.browser', abilityName: 'com.ohos.browser.MainAbility' }
];
const DIAL_ACTION: string = 'ohos.want.action.dial';

export class SystemAppLauncher implements AppLauncher {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async launch(appName: string): Promise<void> {
    if (appName === '电话') {
      try {
        await this.context.startAbility({ action: DIAL_ACTION });
        return;
      } catch (error) {
        await this.launchTargets(PHONE_TARGETS);
        return;
      }
    }

    const targets: AppLaunchTarget[] = this.getTargets(appName);
    await this.launchTargets(targets);
  }

  private getTargets(appName: string): AppLaunchTarget[] {
    switch (appName) {
      case '图库':
        return GALLERY_TARGETS;
      case '设置':
        return SETTINGS_TARGETS;
      case '日历':
        return CALENDAR_TARGETS;
      case '浏览器':
      case '网页':
      case '上网':
        return BROWSER_TARGETS;
      default:
        throw new Error(`未找到可启动的应用：${appName}`);
    }
  }

  private async launchTargets(targets: AppLaunchTarget[]): Promise<void> {
    let lastErrorMessage: string = '系统中未找到对应应用';
    for (let i: number = 0; i < targets.length; i++) {
      const target: AppLaunchTarget = targets[i];
      const want: Want = {
        bundleName: target.bundleName,
        abilityName: target.abilityName
      };
      try {
        await this.context.startAbility(want);
        return;
      } catch (error) {
        lastErrorMessage = (error as Error).message || lastErrorMessage;
      }
    }
    throw new Error(lastErrorMessage);
  }
}

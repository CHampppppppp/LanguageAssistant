interface IFlytekConfigType {
  appId: string;
  apiKey: string;
  apiSecret: string;
  apiUrl: string;
  apiHost: string;
}

export const IFlytekConfig: IFlytekConfigType = {
  appId: 'a431b2e9',
  apiKey: 'd523cac453342e4503b9007c2748bc8d',
  apiSecret: 'ZWVkMDNkODExYTY1YzZhOWNkZjkwZWY1',
  apiUrl: 'wss://iat-api.xfyun.cn/v2/iat',
  apiHost: 'iat-api.xfyun.cn'
};

export function validateIFlytekConfig(): void {
  const missingKeys: string[] = [];

  if (!IFlytekConfig.appId) {
    missingKeys.push('IFLYTEK_APP_ID');
  }
  if (!IFlytekConfig.apiKey) {
    missingKeys.push('IFLYTEK_API_KEY');
  }
  if (!IFlytekConfig.apiSecret) {
    missingKeys.push('IFLYTEK_API_SECRET');
  }

  if (missingKeys.length > 0) {
    throw new Error(`科大讯飞 API 配置缺失: ${missingKeys.join(', ')}`);
  }
}

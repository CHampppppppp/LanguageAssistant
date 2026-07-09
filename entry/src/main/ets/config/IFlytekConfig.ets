interface IFlytekConfigType {
  appId: string;
  apiKey: string;
  apiSecret: string;
  apiUrl: string;
  apiHost: string;
}

export const IFlytekConfig: IFlytekConfigType = {
  appId: '35f91fdb',
  apiKey: 'f538f41284b6541860033277be894285',
  apiSecret: 'YTdmNjVlOGZiN2FjNDNhYjA4MzJhMTVm',
  apiUrl: 'https://api.xf-yun.com/v1/private/sf8e6aca1',
  apiHost: 'api.xf-yun.com'
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

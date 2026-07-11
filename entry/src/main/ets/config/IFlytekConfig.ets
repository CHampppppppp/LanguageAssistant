interface IFlytekConfigType {
  appId: string;
  apiKey: string;
  apiSecret: string;
  apiUrl: string;
  apiHost: string;
  sparkApiUrl: string;
  sparkModel: string;
  sparkApiPassword: string;
}

export const IFlytekConfig: IFlytekConfigType = {
  appId: '1',
  apiKey: '1',
  apiSecret: '1',
  apiUrl: 'wss://iat-api.xfyun.cn/v2/iat',
  apiHost: 'iat-api.xfyun.cn',
  sparkApiUrl: 'https://spark-api-open.xf-yun.com/v1/chat/completions',
  sparkModel: 'lite',
  sparkApiPassword: 'SylKtsRlBKwfmEmytBVN:XlCPOaUvfgwuVejKpYRC'
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

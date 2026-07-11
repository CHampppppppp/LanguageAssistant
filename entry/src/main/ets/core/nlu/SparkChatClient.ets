import { http } from '@kit.NetworkKit';
import { IFlytekConfig } from '../../config/IFlytekConfig';
import { SparkChatRequest, SparkChatResponse } from './SparkIntentTypes';

const SPARK_CONNECT_TIMEOUT_MS: number = 2000;
const SPARK_READ_TIMEOUT_MS: number = 8000;

export interface SparkChatClient {
  complete(request: SparkChatRequest): Promise<SparkChatResponse>;
}

export class IFlytekSparkChatClient implements SparkChatClient {
  async complete(request: SparkChatRequest): Promise<SparkChatResponse> {
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await httpRequest.request(IFlytekConfig.sparkApiUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${IFlytekConfig.sparkApiPassword}`
        },
        extraData: JSON.stringify(request),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: SPARK_CONNECT_TIMEOUT_MS,
        readTimeout: SPARK_READ_TIMEOUT_MS
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`Spark HTTP 状态码 ${response.responseCode}`);
      }
      return JSON.parse(response.result as string) as SparkChatResponse;
    } finally {
      httpRequest.destroy();
    }
  }
}

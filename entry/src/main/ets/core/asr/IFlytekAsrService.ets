import { http } from '@kit.NetworkKit';
import { IFlytekConfig, validateIFlytekConfig } from '../../config/IFlytekConfig';
import { AsrService } from './AsrService';
import { IFlytekResponseParser } from './IFlytekResponseParser';
import { IFlytekSigner } from './IFlytekSigner';
import {
  createChineseIFlytekBusiness,
  IFlytekBusiness,
  IFlytekCommon,
  IFlytekRequestBody,
  IFlytekRequestData,
  IFlytekRequestHeader,
  IFlytekResponse
} from './IFlytekTypes';

export class IFlytekAsrService implements AsrService {
  private business: IFlytekBusiness;
  private signer: IFlytekSigner;

  constructor(business: IFlytekBusiness = createChineseIFlytekBusiness(), signer: IFlytekSigner = new IFlytekSigner()) {
    this.business = business;
    this.signer = signer;
  }

  async recognize(audioBuffer: ArrayBuffer): Promise<string> {
    if (audioBuffer.byteLength === 0) {
      return '';
    }

    validateIFlytekConfig();

    const url: string = IFlytekConfig.apiUrl;
    const host: string = IFlytekConfig.apiHost;
    const date: string = new Date().toUTCString();
    const requestLine: string = 'POST /v1/private/sf8e6aca1 HTTP/1.1';
    const signature: string = await this.signer.generateSignature(IFlytekConfig.apiSecret, host, date, requestLine);
    const authorization: string =
      `api_key="${IFlytekConfig.apiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="${signature}"`;

    const common: IFlytekCommon = { app_id: IFlytekConfig.appId };
    const requestData: IFlytekRequestData = {
      audio: this.arrayBufferToBase64(audioBuffer),
      status: 2
    };
    const requestBody: IFlytekRequestBody = {
      common,
      business: this.business,
      data: requestData
    };
    const header: IFlytekRequestHeader = {
      contentType: 'application/json',
      authorization,
      host,
      date
    };

    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header,
        extraData: JSON.stringify(requestBody)
      });
      const data: IFlytekResponse = JSON.parse(response.result as string) as IFlytekResponse;
      return IFlytekResponseParser.parse(data);
    } finally {
      httpRequest.destroy();
    }
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes: Uint8Array = new Uint8Array(buffer);
    const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result: string = '';
    let i: number = 0;

    while (i < bytes.length) {
      const byte1: number = bytes[i++];
      const hasByte2: boolean = i < bytes.length;
      const byte2: number = hasByte2 ? bytes[i++] : 0;
      const hasByte3: boolean = i < bytes.length;
      const byte3: number = hasByte3 ? bytes[i++] : 0;

      result += chars.charAt(byte1 >> 2);
      result += chars.charAt(((byte1 & 3) << 4) | (byte2 >> 4));
      result += hasByte2 ? chars.charAt(((byte2 & 15) << 2) | (byte3 >> 6)) : '=';
      result += hasByte3 ? chars.charAt(byte3 & 63) : '=';
    }

    return result;
  }
}

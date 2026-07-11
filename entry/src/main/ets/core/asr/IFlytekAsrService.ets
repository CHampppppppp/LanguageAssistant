import { util } from '@kit.ArkTS';
import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { IFlytekConfig, validateIFlytekConfig } from '../../config/IFlytekConfig';
import { AsrService } from './AsrService';
import { IFlytekResponseParser } from './IFlytekResponseParser';
import { IFlytekSigner } from './IFlytekSigner';
import {
  createChineseIFlytekBusiness,
  IFlytekBusiness,
  IFlytekCommon,
  IFlytekRequestData,
  IFlytekResponse,
  IFlytekWebSocketRequest
} from './IFlytekTypes';

const AUDIO_FRAME_SIZE: number = 1280;
const FIRST_FRAME_STATUS: number = 0;
const CONTINUED_FRAME_STATUS: number = 1;
const LAST_FRAME_STATUS: number = 2;
const PCM_FORMAT: string = 'audio/L16;rate=16000';
const PCM_ENCODING: string = 'raw';

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
    const socket: webSocket.WebSocket = webSocket.createWebSocket();
    const resultText: string[] = [];
    let completed: boolean = false;

    return new Promise<string>((resolve: (value: string) => void, reject: (reason: Error) => void) => {
      const finish = (error: Error | null): void => {
        if (completed) {
          return;
        }
        completed = true;
        this.closeSocket(socket);
        if (error) {
          reject(error);
          return;
        }
        resolve(resultText.join(''));
      };

      socket.on('message', (error: BusinessError, message: string | ArrayBuffer) => {
        if (error) {
          finish(new Error(`科大讯飞 WebSocket 接收失败: ${error.message}`));
          return;
        }
        try {
          const response: IFlytekResponse = this.parseResponse(message);
          const fragment: string = IFlytekResponseParser.parse(response);
          resultText.push(fragment);
          if (response.data && response.data.status === LAST_FRAME_STATUS) {
            finish(null);
          }
        } catch (parseError) {
          finish(new Error(`科大讯飞响应解析失败: ${this.formatError(parseError as Error)}`));
        }
      });

      socket.on('error', (error: BusinessError) => {
        finish(new Error(`科大讯飞 WebSocket 连接失败: ${this.formatBusinessError(error)}`));
      });

      socket.on('close', (error: BusinessError) => {
        if (!completed) {
          finish(new Error(`科大讯飞 WebSocket 已关闭: ${error.message}`));
        }
      });

      this.connectSocket(socket, audioBuffer, finish);
    });
  }

  private async connectSocket(socket: webSocket.WebSocket, audioBuffer: ArrayBuffer,
    finish: (error: Error | null) => void): Promise<void> {
    try {
      socket.on('open', (error: BusinessError) => {
        if (error) {
          finish(new Error(`科大讯飞 WebSocket 打开失败: ${this.formatBusinessError(error)}`));
          return;
        }
        this.sendFramesAfterOpen(socket, audioBuffer, finish);
      });
      await socket.connect(await this.createAuthenticatedUrl());
    } catch (error) {
      finish(new Error(`科大讯飞 WebSocket 请求失败: ${this.formatError(error as Error)}`));
    }
  }

  private async sendFramesAfterOpen(socket: webSocket.WebSocket, audioBuffer: ArrayBuffer,
    finish: (error: Error | null) => void): Promise<void> {
    try {
      await this.sendAudioFrames(socket, audioBuffer);
    } catch (error) {
      finish(new Error(`科大讯飞音频发送失败: ${this.formatError(error as Error)}`));
    }
  }

  private async createAuthenticatedUrl(): Promise<string> {
    const host: string = IFlytekConfig.apiHost;
    const date: string = new Date().toUTCString();
    const signature: string = await this.signer.generateSignature(
      IFlytekConfig.apiSecret,
      host,
      date,
      'GET /v2/iat HTTP/1.1'
    );
    const authorizationOrigin: string =
      `api_key="${IFlytekConfig.apiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="${signature}"`;
    const authorization: string = this.stringToBase64(authorizationOrigin);
    return `${IFlytekConfig.apiUrl}?authorization=${encodeURIComponent(authorization)}&date=${encodeURIComponent(date)}&host=${host}`;
  }

  private async sendAudioFrames(socket: webSocket.WebSocket, audioBuffer: ArrayBuffer): Promise<void> {
    const frameCount: number = Math.ceil(audioBuffer.byteLength / AUDIO_FRAME_SIZE);
    for (let index: number = 0; index < frameCount; index++) {
      const start: number = index * AUDIO_FRAME_SIZE;
      const end: number = Math.min(start + AUDIO_FRAME_SIZE, audioBuffer.byteLength);
      const status: number = index === 0 ? FIRST_FRAME_STATUS : CONTINUED_FRAME_STATUS;
      const request: IFlytekWebSocketRequest = this.createAudioRequest(audioBuffer.slice(start, end), status, index === 0);
      await socket.send(JSON.stringify(request));
    }

    const lastRequest: IFlytekWebSocketRequest = this.createAudioRequest(new ArrayBuffer(0), LAST_FRAME_STATUS, false);
    await socket.send(JSON.stringify(lastRequest));
  }

  private createAudioRequest(audioBuffer: ArrayBuffer, status: number, includeRequestMetadata: boolean): IFlytekWebSocketRequest {
    const data: IFlytekRequestData = {
      audio: this.arrayBufferToBase64(audioBuffer),
      status,
      format: PCM_FORMAT,
      encoding: PCM_ENCODING
    };
    if (includeRequestMetadata) {
      const common: IFlytekCommon = { app_id: IFlytekConfig.appId };
      return { common, business: this.business, data };
    }
    return { data };
  }

  private parseResponse(message: string | ArrayBuffer): IFlytekResponse {
    if (typeof message !== 'string') {
      throw new Error('服务端返回了非文本识别结果');
    }
    return JSON.parse(message) as IFlytekResponse;
  }

  private async closeSocket(socket: webSocket.WebSocket): Promise<void> {
    try {
      await socket.close();
    } catch (error) {
      console.warn('[IFlytekAsrService] 关闭 WebSocket 失败', this.formatError(error as Error));
    }
  }

  private formatError(error: Error): string {
    return error.message && error.message !== '' ? error.message : String(error);
  }

  private formatBusinessError(error: BusinessError): string {
    if (error.message && error.message !== '') {
      return error.message;
    }
    return typeof error.code === 'number' ? `错误码 ${error.code}` : String(error);
  }

  private stringToBase64(value: string): string {
    const encoder: util.TextEncoder = new util.TextEncoder();
    return this.bytesToBase64(encoder.encode(value));
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    return this.bytesToBase64(new Uint8Array(buffer));
  }

  private bytesToBase64(bytes: Uint8Array): string {
    const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result: string = '';
    let index: number = 0;

    while (index < bytes.length) {
      const byte1: number = bytes[index++];
      const hasByte2: boolean = index < bytes.length;
      const byte2: number = hasByte2 ? bytes[index++] : 0;
      const hasByte3: boolean = index < bytes.length;
      const byte3: number = hasByte3 ? bytes[index++] : 0;

      result += chars.charAt(byte1 >> 2);
      result += chars.charAt(((byte1 & 3) << 4) | (byte2 >> 4));
      result += hasByte2 ? chars.charAt(((byte2 & 15) << 2) | (byte3 >> 6)) : '=';
      result += hasByte3 ? chars.charAt(byte3 & 63) : '=';
    }

    return result;
  }
}

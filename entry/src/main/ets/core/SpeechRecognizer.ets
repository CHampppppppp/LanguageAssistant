// C:/Users/pzl/PycharmProjects/语音助手/entry/src/main/ets/core/SpeechRecognizer.ets
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { IFlytekConfig, validateIFlytekConfig } from '../config/IFlytekConfig';

interface IFlytekResponse {
  code: number;
  message: string;
  data?: IFlytekData;
}

interface IFlytekData {
  result?: IFlytekResult;
}

interface IFlytekResult {
  ws: IFlytekWs[];
}

interface IFlytekWs {
  cw: IFlytekCw[];
}

interface IFlytekCw {
  w: string;
}

interface IFlytekRequestData {
  audio: string;
  status: number;
}

interface IFlytekBusiness {
  language: string;
  domain: string;
  accent: string;
}

interface IFlytekCommon {
  app_id: string;
}

interface IFlytekRequestBody {
  common: IFlytekCommon;
  business: IFlytekBusiness;
  data: IFlytekRequestData;
}

interface HttpRequestHeader {
  contentType: string;
  authorization: string;
  host: string;
  date: string;
}

export class SpeechRecognizer {
  private audioCapturer: audio.AudioCapturer | null = null;
  private isRecording: boolean = false;
  private audioData: ArrayBuffer = new ArrayBuffer(0);
  private onAudioLevelChanged: ((level: number) => void) | null = null;

  setAudioLevelCallback(callback: (level: number) => void): void {
    this.onAudioLevelChanged = callback;
  }

  async startRecording(): Promise<void> {
    try {
      this.audioData = new ArrayBuffer(0);

      const streamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };

      const capturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      };

      const capturerOptions: audio.AudioCapturerOptions = {
        streamInfo: streamInfo,
        capturerInfo: capturerInfo
      };

      const capturer: audio.AudioCapturer = await audio.createAudioCapturer(capturerOptions);
      this.audioCapturer = capturer;
      await this.audioCapturer.start();
      this.isRecording = true;
      console.info('语音录制已开始');
    } catch (error) {
      const err = error as BusinessError;
      console.error(`录制失败: ${err.code}, ${err.message}`);
      throw new Error(`录制失败: ${err.code}, ${err.message}`);
    }
  }

  async stopRecording(): Promise<ArrayBuffer> {
    if (!this.audioCapturer) {
      throw new Error('录音设备未初始化');
    }
    try {
      const capturer: audio.AudioCapturer = this.audioCapturer;
      const bufferSize: number = 4096;
      let totalBytes: number = 0;
      const chunks: ArrayBuffer[] = [];
      let readLen: number = 0;

      do {
        const readResult: ArrayBuffer = await capturer.read(bufferSize, true);
        readLen = readResult.byteLength;
        if (readLen > 0) {
          chunks.push(readResult);
          totalBytes += readLen;
          console.info(`读取音频数据: ${readLen} 字节`);

          const audioLevel: number = this.calculateAudioLevel(readResult);
          console.info(`音频音量级别: ${audioLevel}`);

          if (this.onAudioLevelChanged) {
            this.onAudioLevelChanged(audioLevel);
          }
        }
      } while (readLen > 0 && this.isRecording);

      await capturer.stop();
      await capturer.release();
      this.audioCapturer = null;
      this.isRecording = false;

      const resultBuffer: ArrayBuffer = this.mergeArrayBuffers(chunks, totalBytes);
      console.info(`录制完成，总字节数: ${totalBytes}`);
      return resultBuffer;
    } catch (error) {
      const err = error as BusinessError;
      console.error(`停止录制失败: ${err.code}, ${err.message}`);
      throw new Error(`停止录制失败: ${err.code}, ${err.message}`);
    }
  }

  private calculateAudioLevel(buffer: ArrayBuffer): number {
    const int16Array: Int16Array = new Int16Array(buffer);
    let sum: number = 0;
    const length: number = int16Array.length;

    for (let i: number = 0; i < length; i++) {
      sum += Math.abs(int16Array[i]);
    }

    const average: number = length > 0 ? sum / length : 0;
    const maxAmplitude: number = 32768;
    const normalizedLevel: number = (average / maxAmplitude) * 100;

    return Math.min(normalizedLevel, 100);
  }

  private mergeArrayBuffers(chunks: ArrayBuffer[], totalBytes: number): ArrayBuffer {
    const result: ArrayBuffer = new ArrayBuffer(totalBytes);
    const resultView: Uint8Array = new Uint8Array(result);
    let offset: number = 0;

    for (let i: number = 0; i < chunks.length; i++) {
      const chunk: Uint8Array = new Uint8Array(chunks[i]);
      resultView.set(chunk, offset);
      offset += chunk.byteLength;
    }

    return result;
  }

  async recognize(audioBuffer: ArrayBuffer): Promise<string> {
    const startTime: number = Date.now();
    try {
      // 检查音频数据是否有效
      if (audioBuffer.byteLength === 0) {
        console.warn('[SpeechRecognizer] 音频数据为空');
        return '';
      }

      // 确保音频数据字节长度是 2 的倍数
      const validLength: number = Math.floor(audioBuffer.byteLength / 2) * 2;
      if (validLength === 0) {
        console.warn('[SpeechRecognizer] 音频数据长度无效');
        return '';
      }

      // 创建有效的音频缓冲区
      const validBuffer: ArrayBuffer = new ArrayBuffer(validLength);
      const validView: Uint8Array = new Uint8Array(validBuffer);
      const sourceView: Uint8Array = new Uint8Array(audioBuffer, 0, validLength);
      validView.set(sourceView);

      const result: string = await this.callIFlytekAPI(validBuffer);
      const duration: number = Date.now() - startTime;
      console.info(`识别耗时: ${duration}ms, 结果: ${result}`);
      return result;
    } catch (error) {
      console.error('语音识别失败:', error);
      return '';
    }
  }

  private async callIFlytekAPI(audioBuffer: ArrayBuffer): Promise<string> {
    validateIFlytekConfig();

    const base64Audio: string = this.arrayBufferToBase64(audioBuffer);
    const url: string = IFlytekConfig.apiUrl;
    const host: string = IFlytekConfig.apiHost;
    const date: string = new Date().toUTCString();
    const requestLine: string = `POST /v1/private/sf8e6aca1 HTTP/1.1`;

    const httpRequest: http.HttpRequest = http.createHttp();

    const common: IFlytekCommon = { app_id: IFlytekConfig.appId };
    const business: IFlytekBusiness = {
      language: 'zh_cn',
      domain: 'iat',
      accent: 'mandarin'
    };
    const requestData: IFlytekRequestData = {
      audio: base64Audio,
      status: 2
    };
    const requestBody: IFlytekRequestBody = {
      common: common,
      business: business,
      data: requestData
    };

    const signature: string = await this.generateSignature(host, date, requestLine);
    const authHeader: string = `api_key="${IFlytekConfig.apiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="${signature}"`;

    const header: HttpRequestHeader = {
      contentType: 'application/json',
      authorization: authHeader,
      host: host,
      date: date
    };

    const requestConfig: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: header,
      extraData: JSON.stringify(requestBody)
    };

    try {
      const response: http.HttpResponse = await httpRequest.request(url, requestConfig);
      const data: IFlytekResponse = JSON.parse(response.result as string) as IFlytekResponse;
      return this.parseIFlytekResponse(data);
    } finally {
      httpRequest.destroy();
    }
  }

  private async generateSignature(host: string, date: string, requestLine: string): Promise<string> {
    const signatureOrigin: string = `host: ${host}\ndate: ${date}\n${requestLine}`;
    const signatureSha: ArrayBuffer = await this.hmacSha256(IFlytekConfig.apiSecret, signatureOrigin);
    const signatureBase64: string = this.arrayBufferToBase64(signatureSha);
    return signatureBase64;
  }

  private async hmacSha256(key: string, data: string): Promise<ArrayBuffer> {
    try {
      const encoder: util.TextEncoder = new util.TextEncoder();
      const keyData: Uint8Array = encoder.encode(key);
      const messageData: Uint8Array = encoder.encode(data);

      const keyBlob: cryptoFramework.DataBlob = { data: keyData };
      const messageBlob: cryptoFramework.DataBlob = { data: messageData };

      const symKeyGenerator: cryptoFramework.SymKeyGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
      const symKey: cryptoFramework.SymKey = await symKeyGenerator.convertKey(keyBlob);

      const mac: cryptoFramework.Mac = cryptoFramework.createMac('HMAC_SHA256');
      await mac.init(symKey);
      await mac.update(messageBlob);
      const macResult: cryptoFramework.DataBlob = await mac.doFinal();

      return macResult.data;
    } catch (error) {
      console.error('HMAC_SHA256 签名失败，使用备用方法:', error);
      // 备用方法：使用 SHA256
      return await this.sha256Fallback(key, data);
    }
  }

  private async sha256Fallback(key: string, data: string): Promise<ArrayBuffer> {
    try {
      const encoder: util.TextEncoder = new util.TextEncoder();
      const keyData: Uint8Array = encoder.encode(key);
      const messageData: Uint8Array = encoder.encode(data);

      // 使用 SHA256
      const sha256: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
      await sha256.update({ data: messageData });
      const hashResult: cryptoFramework.DataBlob = await sha256.digest();

      return hashResult.data;
    } catch (error) {
      console.error('SHA256 备用方法也失败:', error);
      // 返回空缓冲区
      return new ArrayBuffer(0);
    }
  }

  private parseIFlytekResponse(data: IFlytekResponse): string {
    if (data.code !== 0) {
      throw new Error(`API 错误: ${data.message}`);
    }
    let text: string = '';
    if (data.data && data.data.result) {
      const ws: IFlytekWs[] = data.data.result.ws;
      for (let i: number = 0; i < ws.length; i++) {
        const item: IFlytekWs = ws[i];
        for (let j: number = 0; j < item.cw.length; j++) {
          const cw: IFlytekCw = item.cw[j];
          text += cw.w;
        }
      }
    }
    return text;
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes: Uint8Array = new Uint8Array(buffer);
    let binary: string = '';
    for (let i: number = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return this.encodeBase64(binary);
  }

  private encodeBase64(input: string): string {
    const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result: string = '';
    let i: number = 0;

    while (i < input.length) {
      const byte1: number = input.charCodeAt(i++);
      const byte2: number = i < input.length ? input.charCodeAt(i++) : 0;
      const byte3: number = i < input.length ? input.charCodeAt(i++) : 0;

      const enc1: number = byte1 >> 2;
      const enc2: number = ((byte1 & 3) << 4) | (byte2 >> 4);
      const enc3: number = ((byte2 & 15) << 2) | (byte3 >> 6);
      const enc4: number = byte3 & 63;

      result += chars.charAt(enc1);
      result += chars.charAt(enc2);
      result += i - 1 < input.length ? chars.charAt(enc3) : '=';
      result += i < input.length ? chars.charAt(enc4) : '=';
    }

    return result;
  }

  isRecordingActive(): boolean {
    return this.isRecording;
  }
}

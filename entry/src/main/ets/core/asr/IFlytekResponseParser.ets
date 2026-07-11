import { IFlytekCw, IFlytekResponse, IFlytekWs } from './IFlytekTypes';

export class IFlytekResponseParser {
  static parse(data: IFlytekResponse, httpStatus: number): string {
    if (data.code !== 0) {
      throw new Error(`科大讯飞 API 错误（HTTP ${httpStatus}，业务码 ${data.code}）：${this.getErrorMessage(data)}`);
    }

    let text: string = '';
    const ws: IFlytekWs[] = data.data && data.data.result ? data.data.result.ws : [];

    for (let i: number = 0; i < ws.length; i++) {
      const item: IFlytekWs = ws[i];
      for (let j: number = 0; j < item.cw.length; j++) {
        const cw: IFlytekCw = item.cw[j];
        text += cw.w;
      }
    }

    return text;
  }

  private static getErrorMessage(data: IFlytekResponse): string {
    if (data.message && data.message !== '') {
      return data.message;
    }
    if (data.desc && data.desc !== '') {
      return data.desc;
    }
    if (data.error && data.error !== '') {
      return data.error;
    }
    return '服务端未返回错误说明';
  }
}

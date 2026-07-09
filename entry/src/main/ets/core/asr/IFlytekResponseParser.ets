import { IFlytekCw, IFlytekResponse, IFlytekWs } from './IFlytekTypes';

export class IFlytekResponseParser {
  static parse(data: IFlytekResponse): string {
    if (data.code !== 0) {
      throw new Error(`科大讯飞 API 错误: ${data.message}`);
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
}

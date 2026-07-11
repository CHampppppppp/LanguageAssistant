export interface IFlytekResponse {
  code?: number;
  message?: string;
  desc?: string;
  error?: string;
  data?: IFlytekData;
}

export interface IFlytekData {
  status?: number;
  result?: IFlytekResult;
}

export interface IFlytekResult {
  ws: IFlytekWs[];
}

export interface IFlytekWs {
  cw: IFlytekCw[];
}

export interface IFlytekCw {
  w: string;
}

export interface IFlytekRequestData {
  audio: string;
  status: number;
  format: string;
  encoding: string;
}

export interface IFlytekBusiness {
  language: string;
  domain: string;
  accent: string;
}

export interface IFlytekCommon {
  app_id: string;
}

export interface IFlytekWebSocketRequest {
  common?: IFlytekCommon;
  business?: IFlytekBusiness;
  data: IFlytekRequestData;
}

export function createChineseIFlytekBusiness(): IFlytekBusiness {
  return {
    language: 'zh_cn',
    domain: 'iat',
    accent: 'mandarin'
  };
}

export function createEnglishIFlytekBusiness(): IFlytekBusiness {
  return {
    language: 'en_us',
    domain: 'iat',
    accent: 'general'
  };
}

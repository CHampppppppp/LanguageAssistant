export interface AsrService {
  recognize(audioBuffer: ArrayBuffer): Promise<string>;
}

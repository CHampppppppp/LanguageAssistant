import fs from '@ohos.file.fs';

export class AudioUtils {
  static async convertFlacToWav(flacPath: string, context?: Context, isRawfile: boolean = false): Promise<ArrayBuffer> {
    console.info(`转换 FLAC 文件: ${flacPath}`);
    try {
      const fileData: ArrayBuffer = await AudioUtils.readFile(flacPath, context, isRawfile);
      return AudioUtils.decodeFlac(fileData);
    } catch (error) {
      console.error('FLAC 转换失败:', error);
      throw new Error('FLAC 转换失败');
    }
  }

  static async readWavFile(wavPath: string, context?: Context, isRawfile: boolean = false): Promise<ArrayBuffer> {
    console.info(`读取 WAV 文件: ${wavPath}`);
    try {
      const fileData: ArrayBuffer = await AudioUtils.readFile(wavPath, context, isRawfile);
      return AudioUtils.extractWavPcmData(fileData);
    } catch (error) {
      console.error('WAV 读取失败:', error);
      throw new Error('WAV 读取失败');
    }
  }

  static async readFile(path: string, context?: Context, isRawfile: boolean = false): Promise<ArrayBuffer> {
    try {
      if (context && isRawfile) {
        const rawfilePath: string = path.replace('rawfile/', '');
        const rawFile: Uint8Array = await context.resourceManager.getRawFileContent(rawfilePath);
        return rawFile.buffer.slice(rawFile.byteOffset, rawFile.byteOffset + rawFile.byteLength);
      } else {
        const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
        const stat: fs.Stat = fs.statSync(path);
        const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buffer, { offset: 0, length: stat.size });
        fs.closeSync(file);
        return buffer;
      }
    } catch (error) {
      console.error(`读取文件失败: ${path}`, error);
      return new ArrayBuffer(0);
    }
  }

  static decodeFlac(data: ArrayBuffer): ArrayBuffer {
    console.info('校验 FLAC 音频数据');
    const view: DataView = new DataView(data);
    const size: number = data.byteLength;

    if (size < 4) {
      throw new Error('FLAC 文件太小');
    }

    const magic: string = String.fromCharCode(
      view.getUint8(0),
      view.getUint8(1),
      view.getUint8(2),
      view.getUint8(3)
    );

    if (magic !== 'fLaC') {
      throw new Error('不是有效的 FLAC 文件');
    }

    throw new Error('当前仓库未实现真实 FLAC 解码，请先将评测样本转换为 PCM/WAV');
  }

  static extractWavPcmData(data: ArrayBuffer): ArrayBuffer {
    const view: DataView = new DataView(data);
    if (data.byteLength < 44) {
      throw new Error('WAV 文件太小');
    }

    const riff: string = AudioUtils.readAscii(view, 0, 4);
    const wave: string = AudioUtils.readAscii(view, 8, 4);
    if (riff !== 'RIFF' || wave !== 'WAVE') {
      throw new Error('不是有效的 WAV 文件');
    }

    let offset: number = 12;
    while (offset + 8 <= data.byteLength) {
      const chunkId: string = AudioUtils.readAscii(view, offset, 4);
      const chunkSize: number = view.getUint32(offset + 4, true);
      const chunkDataStart: number = offset + 8;
      const chunkDataEnd: number = chunkDataStart + chunkSize;

      if (chunkDataEnd > data.byteLength) {
        throw new Error('WAV 数据块越界');
      }

      if (chunkId === 'data') {
        const pcmData: ArrayBuffer = new ArrayBuffer(chunkSize);
        const sourceView: Uint8Array = new Uint8Array(data, chunkDataStart, chunkSize);
        new Uint8Array(pcmData).set(sourceView);
        return pcmData;
      }

      offset = chunkDataEnd + (chunkSize % 2);
    }

    throw new Error('WAV 文件缺少 data 数据块');
  }

  private static readAscii(view: DataView, offset: number, length: number): string {
    let result: string = '';
    for (let index: number = 0; index < length; index++) {
      result += String.fromCharCode(view.getUint8(offset + index));
    }
    return result;
  }

  static normalizeAudio(audioData: Float32Array): Float32Array {
    const normalized: Float32Array = new Float32Array(audioData.length);
    let maxAmplitude: number = 0;

    for (let i: number = 0; i < audioData.length; i++) {
      const absValue: number = Math.abs(audioData[i]);
      if (absValue > maxAmplitude) {
        maxAmplitude = absValue;
      }
    }

    if (maxAmplitude > 0) {
      const scale: number = 1.0 / maxAmplitude;
      for (let i: number = 0; i < audioData.length; i++) {
        normalized[i] = audioData[i] * scale;
      }
    } else {
      normalized.set(audioData);
    }

    return normalized;
  }

  static extractFeatures(audioData: Float32Array, sampleRate: number = 16000): Float32Array {
    const frameLength: number = Math.floor(sampleRate * 0.025);
    const hopLength: number = Math.floor(sampleRate * 0.01);
    const numFrames: number = Math.floor((audioData.length - frameLength) / hopLength) + 1;

    const features: Float32Array = new Float32Array(numFrames * 40);

    for (let i: number = 0; i < numFrames; i++) {
      const start: number = i * hopLength;
      const frame: Float32Array = audioData.slice(start, start + frameLength);
      const mfcc: Float32Array = AudioUtils.computeMFCC(frame, sampleRate);
      features.set(mfcc, i * 40);
    }

    return features;
  }

  static computeMFCC(frame: Float32Array, sampleRate: number): Float32Array {
    const numCoefficients: number = 40;
    const mfcc: Float32Array = new Float32Array(numCoefficients);

    const spectrum: Float32Array = AudioUtils.computeSpectrum(frame);

    for (let i: number = 0; i < numCoefficients; i++) {
      mfcc[i] = AudioUtils.computeMelCoefficient(spectrum, i, sampleRate);
    }

    return mfcc;
  }

  static computeSpectrum(frame: Float32Array): Float32Array {
    const n: number = frame.length;
    const spectrum: Float32Array = new Float32Array(n / 2);

    for (let k: number = 0; k < n / 2; k++) {
      let real: number = 0;
      let imag: number = 0;
      for (let t: number = 0; t < n; t++) {
        const angle: number = (2 * Math.PI * k * t) / n;
        real += frame[t] * Math.cos(angle);
        imag -= frame[t] * Math.sin(angle);
      }
      spectrum[k] = Math.sqrt(real * real + imag * imag);
    }

    return spectrum;
  }

  static computeMelCoefficient(spectrum: Float32Array, coefficientIndex: number, sampleRate: number): number {
    return spectrum[coefficientIndex % spectrum.length] || 0;
  }

  static resampleAudio(audioData: Float32Array, fromRate: number, toRate: number): Float32Array {
    if (fromRate === toRate) {
      return audioData;
    }

    const ratio: number = fromRate / toRate;
    const newLength: number = Math.floor(audioData.length / ratio);
    const resampled: Float32Array = new Float32Array(newLength);

    for (let i: number = 0; i < newLength; i++) {
      const srcIndex: number = i * ratio;
      const index: number = Math.floor(srcIndex);
      const fraction: number = srcIndex - index;

      if (index + 1 < audioData.length) {
        resampled[i] = audioData[index] * (1 - fraction) + audioData[index + 1] * fraction;
      } else {
        resampled[i] = audioData[index] || 0;
      }
    }

    return resampled;
  }

  static calculateSNR(signal: Float32Array, noise: Float32Array): number {
    let signalPower: number = 0;
    let noisePower: number = 0;

    for (let i: number = 0; i < signal.length; i++) {
      signalPower += signal[i] * signal[i];
    }

    for (let i: number = 0; i < noise.length; i++) {
      noisePower += noise[i] * noise[i];
    }

    if (noisePower === 0) {
      return Infinity;
    }

    return 10 * Math.log10(signalPower / noisePower);
  }
}

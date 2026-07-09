// C:/Users/pzl/PycharmProjects/语音助手/entry/src/main/ets/utils/AudioUtils.ets
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';

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
      return await AudioUtils.readFile(wavPath, context, isRawfile);
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
        return rawFile.buffer;
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
    console.info('解码 FLAC 音频数据');
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
      console.warn('不是有效的 FLAC 文件，尝试直接返回原始数据');
      return data;
    }

    let offset: number = 4;
    let isLastBlock: boolean = false;

    while (!isLastBlock && offset < size) {
      const blockHeader: number = view.getUint8(offset);
      isLastBlock = (blockHeader & 0x80) !== 0;
      const blockType: number = blockHeader & 0x7F;
      const blockLength: number = (view.getUint8(offset + 1) << 16) |
        (view.getUint8(offset + 2) << 8) |
        view.getUint8(offset + 3);

      if (blockType === 0) {
        const sampleRate: number = (view.getUint8(offset + 10) << 12) |
          (view.getUint8(offset + 11) << 4) |
          (view.getUint8(offset + 12) >> 4);
        const channels: number = ((view.getUint8(offset + 12) >> 1) & 0x07) + 1;
        const bitsPerSample: number = ((view.getUint8(offset + 12) & 0x01) << 4) |
          ((view.getUint8(offset + 13) >> 4) & 0x0F) + 1;
        const totalSamples: number = ((view.getUint8(offset + 17) & 0x0F) << 28) |
          (view.getUint8(offset + 18) << 20) |
          (view.getUint8(offset + 19) << 12) |
          (view.getUint8(offset + 20) << 4) |
          (view.getUint8(offset + 21) >> 4);

        console.info(`FLAC 信息: 采样率=${sampleRate}, 声道=${channels}, 位深=${bitsPerSample}, 样本数=${totalSamples}`);

        const audioStartOffset: number = offset + blockLength + 4;
        const audioDataSize: number = size - audioStartOffset;

        if (audioDataSize > 0) {
          const audioData: ArrayBuffer = new ArrayBuffer(audioDataSize);
          const srcView: Uint8Array = new Uint8Array(data, audioStartOffset, audioDataSize);
          const dstView: Uint8Array = new Uint8Array(audioData);
          dstView.set(srcView);
          return audioData;
        }
      }

      offset += blockLength + 4;
    }

    return data;
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
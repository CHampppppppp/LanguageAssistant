import { AudioUtils, WavReadResult } from './AudioUtils';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';

export type DatasetAudioFormat = 'wav' | 'flac';

export interface DatasetSample {
  sampleId: string;
  audioPath: string;
  audioFormat: DatasetAudioFormat;
  audioPreparation: string;
  transcript: string;
  speakerId: string;
  chapterId: string;
  utteranceId: string;
}

export interface DatasetLoadSummary {
  transcriptCount: number;
  audioFileCount: number;
  matchedSampleCount: number;
  skippedWithoutTranscriptCount: number;
  hasFlacSamples: boolean;
  hasWavSamples: boolean;
  wavPreferredSampleCount: number;
  flacOnlySampleCount: number;
  selectedAudioFormat: string;
  audioPreparationPolicy: string;
  loadDurationMs: number;
}

const WINDOWS_PATH_SEPARATOR_PATTERN: RegExp = new RegExp('\\\\', 'g');
const WAV_EVALUATION_POLICY: string = '优先使用预先转换的16k/mono/PCM WAV；仅有FLAC的样本不纳入可信评测';
const WAV_PREPARED_AUDIO_PREPARATION: string = 'preconverted_16k_mono_pcm_wav';
const FLAC_ONLY_AUDIO_PREPARATION: string = 'raw_flac_requires_offline_conversion';

export class DatasetLoader {
  private datasetPath: string = '';
  private samples: DatasetSample[] = [];
  private transcripts: Map<string, string> = new Map();
  private context: Context | undefined = undefined;
  private isRawfile: boolean = false;
  private lastLoadSummary: DatasetLoadSummary = {
    transcriptCount: 0,
    audioFileCount: 0,
    matchedSampleCount: 0,
    skippedWithoutTranscriptCount: 0,
    hasFlacSamples: false,
    hasWavSamples: false,
    wavPreferredSampleCount: 0,
    flacOnlySampleCount: 0,
    selectedAudioFormat: 'wav_only',
    audioPreparationPolicy: WAV_EVALUATION_POLICY,
    loadDurationMs: 0
  };

  constructor(datasetPath: string, context?: Context) {
    this.datasetPath = datasetPath;
    this.context = context;
    this.isRawfile = datasetPath.startsWith('rawfile/');
    console.info(`[DatasetLoader] 初始化 - 路径：${datasetPath}, 使用 rawfile: ${this.isRawfile}`);
  }

  async loadDataset(): Promise<DatasetSample[]> {
    const startedAt: number = Date.now();
    console.info(`[DatasetLoader] 开始加载数据集: ${this.datasetPath}`);
    console.info(`[DatasetLoader] Context 是否存在: ${this.context ? '是' : '否'}`);

    this.samples = [];
    this.transcripts = new Map();
    this.lastLoadSummary = {
      transcriptCount: 0,
      audioFileCount: 0,
      matchedSampleCount: 0,
      skippedWithoutTranscriptCount: 0,
      hasFlacSamples: false,
      hasWavSamples: false,
      wavPreferredSampleCount: 0,
      flacOnlySampleCount: 0,
      selectedAudioFormat: 'wav_only',
      audioPreparationPolicy: WAV_EVALUATION_POLICY,
      loadDurationMs: 0
    };

    try {
      console.info('[DatasetLoader] 开始加载转录文件...');
      await this.loadTranscripts();
      console.info(`[DatasetLoader] 转录文件加载完成，找到 ${this.transcripts.size} 个转录`);
      this.lastLoadSummary.transcriptCount = this.transcripts.size;

      console.info('[DatasetLoader] 开始扫描音频文件...');
      await this.scanAudioFiles();
      console.info(`[DatasetLoader] 音频文件扫描完成，找到 ${this.samples.length} 个样本`);

      if (this.samples.length === 0) {
        console.error('[DatasetLoader] 警告：没有找到任何样本！');
        console.error('[DatasetLoader] 请检查：');
        console.error(`[DatasetLoader] 1. 路径是否正确：${this.datasetPath}`);
        console.error('[DatasetLoader] 2. rawfile 目录结构是否正确');
        console.error('[DatasetLoader] 3. 是否有 .flac 或 .wav 文件');
      }
    } catch (error) {
      console.error(`[DatasetLoader] 数据集加载失败: ${error}`);
    } finally {
      this.lastLoadSummary.matchedSampleCount = this.samples.length;
      this.lastLoadSummary.loadDurationMs = Date.now() - startedAt;
    }

    console.info(`[DatasetLoader] 最终结果：共 ${this.samples.length} 个样本`);
    return this.samples;
  }

  private async loadTranscripts(): Promise<void> {
    console.info('[DatasetLoader] 加载转录文本文件');
    const transcriptFiles: string[] = (await this.findTranscriptFiles()).sort((left: string, right: string) => left.localeCompare(right));
    console.info(`[DatasetLoader] 找到 ${transcriptFiles.length} 个转录文件`);

    if (transcriptFiles.length > 0) {
      console.info(`[DatasetLoader] 第一个转录文件：${transcriptFiles[0]}`);
    }

    for (const file of transcriptFiles) {
      try {
        console.info(`[DatasetLoader] 读取转录文件：${file}`);
        const content: string = await this.readTranscriptFile(file);
        console.info(`[DatasetLoader] 转录文件内容长度：${content.length} 字符`);
        this.parseTranscriptContent(content);
      } catch (error) {
        console.warn(`[DatasetLoader] 读取转录文件失败: ${file}`, error);
      }
    }
  }

  private async findTranscriptFiles(): Promise<string[]> {
    const transcriptFiles: string[] = [];

    if (this.isRawfile && this.context) {
      console.info(`[DatasetLoader] 使用 rawfile 模式查找转录文件`);
      await this.findFilesInRawfile(this.datasetPath, '.trans.txt', transcriptFiles);
    } else {
      console.info(`[DatasetLoader] 使用文件系统模式查找转录文件`);
      const basePath: string = this.datasetPath;
      try {
        const speakerDirs: string[] = await this.listDirectories(basePath);
        console.info(`[DatasetLoader] 找到 ${speakerDirs.length} 个说话人目录`);
        for (const speakerDir of speakerDirs) {
          const speakerPath: string = `${basePath}/${speakerDir}`;
          const chapterDirs: string[] = await this.listDirectories(speakerPath);
          for (const chapterDir of chapterDirs) {
            const chapterPath: string = `${speakerPath}/${chapterDir}`;
            const files: string[] = await this.listFiles(chapterPath);
            for (const file of files) {
              if (file.endsWith('.trans.txt')) {
                transcriptFiles.push(`${chapterPath}/${file}`);
              }
            }
          }
        }
      } catch (error) {
        console.error('[DatasetLoader] 查找转录文件失败:', error);
      }
    }

    return transcriptFiles;
  }

  private async findFilesInRawfile(dirPath: string, extension: string, result: string[]): Promise<void> {
    if (!this.context) {
      console.error('[DatasetLoader] Context 为空，无法查找 rawfile');
      return;
    }

    try {
      console.info(`[DatasetLoader] 查找 rawfile 目录：${dirPath}`);
      const files: string[] = await this.context.resourceManager.getRawFileList(dirPath);
      console.info(`[DatasetLoader] 目录 ${dirPath} 包含 ${files.length} 个项目`);

      for (const file of files) {
        const fullPath: string = `${dirPath}/${file}`;

        if (file.includes('.')) {
          if (file.endsWith(extension)) {
            console.info(`[DatasetLoader] 找到匹配文件：${fullPath}`);
            result.push(fullPath);
          }
        } else {
          console.info(`[DatasetLoader] 进入子目录：${fullPath}`);
          await this.findFilesInRawfile(fullPath, extension, result);
        }
      }
    } catch (error) {
      console.error(`[DatasetLoader] 查找 rawfile 失败: ${dirPath}`, error);
    }
  }

  private async readTranscriptFile(path: string): Promise<string> {
    try {
      if (this.isRawfile && this.context) {
        const rawfilePath: string = path.replace('rawfile/', '');
        console.info(`[DatasetLoader] 读取 rawfile：${rawfilePath}`);
        const rawFile: Uint8Array = await this.context.resourceManager.getRawFileContent(rawfilePath);
        console.info(`[DatasetLoader] rawfile 大小：${rawFile.length} 字节`);
        const decoder: util.TextDecoder = new util.TextDecoder('utf-8');
        return decoder.decode(rawFile);
      } else {
        const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
        const stat: fs.Stat = fs.statSync(path);
        const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buffer, { offset: 0, length: stat.size });
        fs.closeSync(file);
        const uint8Array: Uint8Array = new Uint8Array(buffer);
        const decoder: util.TextDecoder = new util.TextDecoder('utf-8');
        return decoder.decode(uint8Array);
      }
    } catch (error) {
      console.error(`[DatasetLoader] 读取转录文件失败: ${path}`, error);
      return '';
    }
  }

  private parseTranscriptContent(content: string): void {
    const lines: string[] = content.split('\n');
    console.info(`[DatasetLoader] 解析转录内容，共 ${lines.length} 行`);

    for (const line of lines) {
      const trimmed: string = line.trim();
      if (trimmed) {
        const parts: string[] = trimmed.split(' ');
        if (parts.length >= 2) {
          const utteranceId: string = parts[0];
          const transcript: string = parts.slice(1).join(' ');
          this.transcripts.set(utteranceId, transcript);
        }
      }
    }
  }

  private async scanAudioFiles(): Promise<void> {
    const audioFiles: string[] = (await this.findAudioFiles()).sort((left: string, right: string) => left.localeCompare(right));
    console.info(`[DatasetLoader] 找到 ${audioFiles.length} 个音频文件`);
    let skippedWithoutTranscript: number = 0;
    let wavPreferredSampleCount: number = 0;
    let flacOnlySampleCount: number = 0;
    this.lastLoadSummary.audioFileCount = audioFiles.length;
    this.lastLoadSummary.hasFlacSamples = audioFiles.some((audioPath: string) => audioPath.endsWith('.flac'));
    this.lastLoadSummary.hasWavSamples = audioFiles.some((audioPath: string) => audioPath.endsWith('.wav'));

    if (audioFiles.length > 0) {
      console.info(`[DatasetLoader] 第一个音频文件：${audioFiles[0]}`);
    }

    const selectedSamples: DatasetSample[] = this.selectPreferredEvaluationSamples(audioFiles);

    for (const sample of selectedSamples) {
      if (!sample.transcript) {
        skippedWithoutTranscript++;
        console.warn(`[DatasetLoader] 跳过缺少转录文本的样本：${sample.sampleId}`);
        continue;
      }

      if (sample.audioFormat === 'wav') {
        wavPreferredSampleCount++;
        this.samples.push(sample);
      } else {
        flacOnlySampleCount++;
        console.warn(`[DatasetLoader] 跳过仅有 FLAC 的样本：${sample.sampleId}`);
      }
    }

    if (skippedWithoutTranscript > 0) {
      console.warn(`[DatasetLoader] 共跳过 ${skippedWithoutTranscript} 个缺少转录文本的样本`);
    }
    if (flacOnlySampleCount > 0) {
      console.warn(`[DatasetLoader] 共跳过 ${flacOnlySampleCount} 个仅有 FLAC 的样本，需先离线转为 16k/mono/PCM WAV`);
    }
    this.lastLoadSummary.selectedAudioFormat = wavPreferredSampleCount > 0
      ? (flacOnlySampleCount > 0 ? 'wav_preferred_flac_skipped' : 'wav_only')
      : (flacOnlySampleCount > 0 ? 'flac_only_unavailable' : 'none');
    this.lastLoadSummary.skippedWithoutTranscriptCount = skippedWithoutTranscript;
    this.lastLoadSummary.wavPreferredSampleCount = wavPreferredSampleCount;
    this.lastLoadSummary.flacOnlySampleCount = flacOnlySampleCount;
  }

  private async findAudioFiles(): Promise<string[]> {
    const audioFiles: string[] = [];

    if (this.isRawfile && this.context) {
      console.info(`[DatasetLoader] 使用 rawfile 模式查找音频文件`);
      await this.findFilesInRawfile(this.datasetPath, '.flac', audioFiles);
      await this.findFilesInRawfile(this.datasetPath, '.wav', audioFiles);
    } else {
      console.info(`[DatasetLoader] 使用文件系统模式查找音频文件`);
      const basePath: string = this.datasetPath;
      try {
        const speakerDirs: string[] = await this.listDirectories(basePath);
        for (const speakerDir of speakerDirs) {
          const speakerPath: string = `${basePath}/${speakerDir}`;
          const chapterDirs: string[] = await this.listDirectories(speakerPath);
          for (const chapterDir of chapterDirs) {
            const chapterPath: string = `${speakerPath}/${chapterDir}`;
            const files: string[] = await this.listFiles(chapterPath);
            for (const file of files) {
              if (file.endsWith('.flac') || file.endsWith('.wav')) {
                audioFiles.push(`${chapterPath}/${file}`);
              }
            }
          }
        }
      } catch (error) {
        console.error('[DatasetLoader] 查找音频文件失败:', error);
      }
    }

    return audioFiles;
  }

  private async listDirectories(path: string): Promise<string[]> {
    try {
      if (this.context && !this.isRawfile) {
        const files: string[] = await this.context.resourceManager.getRawFileList(path);
        return files.filter((file: string) => !file.includes('.'));
      } else {
        const files: string[] = fs.listFileSync(path);
        return files.filter((file: string) => {
          try {
            const stat: fs.Stat = fs.statSync(`${path}/${file}`);
            return stat.isDirectory();
          } catch {
            return false;
          }
        });
      }
    } catch (error) {
      console.error(`[DatasetLoader] 列出目录失败: ${path}`, error);
      return [];
    }
  }

  private async listFiles(path: string): Promise<string[]> {
    try {
      if (this.context && !this.isRawfile) {
        return await this.context.resourceManager.getRawFileList(path);
      } else {
        return fs.listFileSync(path);
      }
    } catch (error) {
      console.error(`[DatasetLoader] 列出文件失败: ${path}`, error);
      return [];
    }
  }

  private selectPreferredEvaluationSamples(audioFiles: string[]): DatasetSample[] {
    const sampleMap: Map<string, DatasetSample> = new Map();

    for (const audioPath of audioFiles) {
      const sample: DatasetSample | null = this.parseAudioPath(audioPath);
      if (!sample) {
        continue;
      }

      const existingSample: DatasetSample | undefined = sampleMap.get(sample.sampleId);
      if (!existingSample) {
        sampleMap.set(sample.sampleId, sample);
        continue;
      }

      if (existingSample.audioFormat === 'flac' && sample.audioFormat === 'wav') {
        sampleMap.set(sample.sampleId, sample);
      }
    }

    return Array.from(sampleMap.values()).sort((left: DatasetSample, right: DatasetSample) => {
      return left.sampleId.localeCompare(right.sampleId);
    });
  }

  private parseAudioPath(audioPath: string): DatasetSample | null {
    const normalizedPath: string = audioPath.replace(WINDOWS_PATH_SEPARATOR_PATTERN, '/');
    const fileName: string = normalizedPath.split('/').pop() || '';
    const audioFormat: DatasetAudioFormat = normalizedPath.endsWith('.wav') ? 'wav' : 'flac';
    const parts: string[] = fileName.replace('.flac', '').replace('.wav', '').split('-');

    if (parts.length >= 3) {
      const speakerId: string = parts[0];
      const chapterId: string = parts[1];
      const utteranceId: string = parts[2];
      const sampleId: string = `${speakerId}-${chapterId}-${utteranceId}`;

      const transcript: string = this.transcripts.get(sampleId) || '';

      return {
        sampleId,
        audioPath: normalizedPath,
        audioFormat,
        audioPreparation: audioFormat === 'wav' ? WAV_PREPARED_AUDIO_PREPARATION : FLAC_ONLY_AUDIO_PREPARATION,
        transcript,
        speakerId,
        chapterId,
        utteranceId
      };
    }

    return null;
  }

  getSample(index: number): DatasetSample | null {
    if (index >= 0 && index < this.samples.length) {
      return this.samples[index];
    }
    return null;
  }

  getSampleById(sampleId: string): DatasetSample | null {
    for (let index: number = 0; index < this.samples.length; index++) {
      if (this.samples[index].sampleId === sampleId) {
        return this.samples[index];
      }
    }
    return null;
  }

  getRandomSample(): DatasetSample | null {
    if (this.samples.length === 0) {
      return null;
    }
    const index: number = Math.floor(Math.random() * this.samples.length);
    return this.samples[index];
  }

  getSamplesBySpeaker(speakerId: string): DatasetSample[] {
    return this.samples.filter((sample: DatasetSample) => sample.speakerId === speakerId);
  }

  getSamplesByChapter(chapterId: string): DatasetSample[] {
    return this.samples.filter((sample: DatasetSample) => sample.chapterId === chapterId);
  }

  getSampleCount(): number {
    return this.samples.length;
  }

  getLastLoadSummary(): DatasetLoadSummary {
    return {
      transcriptCount: this.lastLoadSummary.transcriptCount,
      audioFileCount: this.lastLoadSummary.audioFileCount,
      matchedSampleCount: this.lastLoadSummary.matchedSampleCount,
      skippedWithoutTranscriptCount: this.lastLoadSummary.skippedWithoutTranscriptCount,
      hasFlacSamples: this.lastLoadSummary.hasFlacSamples,
      hasWavSamples: this.lastLoadSummary.hasWavSamples,
      wavPreferredSampleCount: this.lastLoadSummary.wavPreferredSampleCount,
      flacOnlySampleCount: this.lastLoadSummary.flacOnlySampleCount,
      selectedAudioFormat: this.lastLoadSummary.selectedAudioFormat,
      audioPreparationPolicy: this.lastLoadSummary.audioPreparationPolicy,
      loadDurationMs: this.lastLoadSummary.loadDurationMs
    };
  }

  getTranscript(sampleIdOrUtteranceId: string): string {
    const transcript: string | undefined = this.transcripts.get(sampleIdOrUtteranceId);
    if (transcript) {
      return transcript;
    }

    if (!sampleIdOrUtteranceId.includes('-')) {
      for (const entry of this.transcripts.entries()) {
        const sampleId: string = entry[0];
        const text: string = entry[1];
        if (sampleId.endsWith(`-${sampleIdOrUtteranceId}`)) {
          return text;
        }
      }
    }

    return '';
  }

  async loadAudioData(sample: DatasetSample): Promise<Float32Array> {
    try {
      let audioBuffer: ArrayBuffer;
      if (sample.audioFormat === 'flac') {
        throw new Error('当前评测样本仍为 FLAC，请先离线转换为 16k/mono/PCM WAV');
      }
      const wavResult: WavReadResult = await AudioUtils.readEvaluationWavFile(
        sample.audioPath,
        this.context,
        this.isRawfile
      );
      audioBuffer = wavResult.pcmData;
      const audioData: Float32Array = this.bufferToFloat32Array(audioBuffer);
      return AudioUtils.normalizeAudio(audioData);
    } catch (error) {
      console.error(`[DatasetLoader] 加载音频数据失败: ${sample.audioPath}`, error);
      return new Float32Array(0);
    }
  }

  private bufferToFloat32Array(buffer: ArrayBuffer): Float32Array {
    try {
      // 确保字节长度是 2 的倍数
      const validLength: number = Math.floor(buffer.byteLength / 2) * 2;
      if (validLength === 0) {
        console.warn('[DatasetLoader] 音频数据为空');
        return new Float32Array(0);
      }

      // 创建视图，只使用有效长度
      const int16Array: Int16Array = new Int16Array(buffer, 0, validLength / 2);
      const float32Array: Float32Array = new Float32Array(int16Array.length);

      for (let i: number = 0; i < int16Array.length; i++) {
        float32Array[i] = int16Array[i] / 32768.0;
      }

      return float32Array;
    } catch (error) {
      console.error('[DatasetLoader] bufferToFloat32Array 转换失败:', error);
      return new Float32Array(0);
    }
  }
}

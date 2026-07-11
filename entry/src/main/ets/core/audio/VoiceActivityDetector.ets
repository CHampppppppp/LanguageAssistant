const PCM16_BYTES_PER_SECOND: number = 32000;
const DEFAULT_SPEECH_THRESHOLD_PERCENT: number = 35;

export interface VoiceActivityDetectorOptions {
  speechThresholdPercent: number;
  silenceTimeoutMs: number;
  minimumSpeechMs: number;
  maximumSpeechMs: number;
}

export const DEFAULT_VAD_OPTIONS: VoiceActivityDetectorOptions = {
  speechThresholdPercent: DEFAULT_SPEECH_THRESHOLD_PERCENT,
  silenceTimeoutMs: 800,
  minimumSpeechMs: 300,
  maximumSpeechMs: 12000
};

export class VoiceActivityDetector {
  private readonly options: VoiceActivityDetectorOptions;
  private chunks: ArrayBuffer[] = [];
  private totalBytes: number = 0;
  private voicedBytes: number = 0;
  private detectedSpeech: boolean = false;
  private silenceDurationMs: number = 0;

  constructor(options: VoiceActivityDetectorOptions = DEFAULT_VAD_OPTIONS) {
    this.options = options;
  }

  push(buffer: ArrayBuffer, levelPercent: number): ArrayBuffer | null {
    if (buffer.byteLength === 0) {
      return null;
    }
    if (!this.detectedSpeech) {
      if (levelPercent < this.options.speechThresholdPercent) {
        return null;
      }
      this.detectedSpeech = true;
    }
    this.chunks.push(buffer);
    this.totalBytes += buffer.byteLength;
    if (levelPercent >= this.options.speechThresholdPercent) {
      this.voicedBytes += buffer.byteLength;
      this.silenceDurationMs = 0;
    } else {
      this.silenceDurationMs += this.getDurationMs(buffer.byteLength);
    }
    const hasMinimumSpeech: boolean = this.voicedBytes >= this.getMinimumBytes();
    const endedForSilence: boolean = hasMinimumSpeech && this.silenceDurationMs >= this.options.silenceTimeoutMs;
    const endedForMaxDuration: boolean = this.totalBytes >= this.getMaximumBytes();
    if (!endedForSilence && !endedForMaxDuration) {
      return null;
    }
    return this.takeUtterance();
  }

  reset(): void {
    this.chunks = [];
    this.totalBytes = 0;
    this.voicedBytes = 0;
    this.detectedSpeech = false;
    this.silenceDurationMs = 0;
  }

  private takeUtterance(): ArrayBuffer {
    const result: ArrayBuffer = new ArrayBuffer(this.totalBytes);
    const resultView: Uint8Array = new Uint8Array(result);
    let offset: number = 0;
    for (let i: number = 0; i < this.chunks.length; i++) {
      const chunk: Uint8Array = new Uint8Array(this.chunks[i]);
      resultView.set(chunk, offset);
      offset += chunk.byteLength;
    }
    this.reset();
    return result;
  }

  private getDurationMs(byteLength: number): number {
    return (byteLength / PCM16_BYTES_PER_SECOND) * 1000;
  }

  private getMinimumBytes(): number {
    return Math.ceil((this.options.minimumSpeechMs / 1000) * PCM16_BYTES_PER_SECOND);
  }

  private getMaximumBytes(): number {
    return Math.ceil((this.options.maximumSpeechMs / 1000) * PCM16_BYTES_PER_SECOND);
  }
}

import { describe, it, expect } from '@ohos/hypium';
import { AudioRecorder } from '../main/ets/core/audio/AudioRecorder';
import { AudioUtils } from '../main/ets/utils/AudioUtils';

function createWavWithPcm(pcmSamples: Int16Array): ArrayBuffer {
  const pcmBytes: number = pcmSamples.byteLength;
  const totalBytes: number = 44 + pcmBytes;
  const buffer: ArrayBuffer = new ArrayBuffer(totalBytes);
  const view: DataView = new DataView(buffer);

  writeAscii(view, 0, 'RIFF');
  view.setUint32(4, totalBytes - 8, true);
  writeAscii(view, 8, 'WAVE');
  writeAscii(view, 12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, 16000, true);
  view.setUint32(28, 32000, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  writeAscii(view, 36, 'data');
  view.setUint32(40, pcmBytes, true);

  const pcmView: Int16Array = new Int16Array(buffer, 44, pcmSamples.length);
  pcmView.set(pcmSamples);
  return buffer;
}

function writeAscii(view: DataView, offset: number, text: string): void {
  for (let index: number = 0; index < text.length; index++) {
    view.setUint8(offset + index, text.charCodeAt(index));
  }
}

function createPcmBuffer(samples: number[]): ArrayBuffer {
  const buffer: ArrayBuffer = new ArrayBuffer(samples.length * 2);
  const view: Int16Array = new Int16Array(buffer);

  for (let index: number = 0; index < samples.length; index++) {
    view[index] = samples[index];
  }

  return buffer;
}

export default function audioUtilsTest() {
  describe('audioUtilsTest', () => {
    it('extracts pcm data from wav file', 0, () => {
      const wavBuffer: ArrayBuffer = createWavWithPcm(new Int16Array([1000, -1000, 2000]));

      const pcmBuffer: ArrayBuffer = AudioUtils.extractWavPcmData(wavBuffer);
      const pcmView: Int16Array = new Int16Array(pcmBuffer);

      expect(pcmView.length).assertEqual(3);
      expect(pcmView[0]).assertEqual(1000);
      expect(pcmView[1]).assertEqual(-1000);
      expect(pcmView[2]).assertEqual(2000);
    });

    it('normalizes audio to the largest absolute amplitude', 0, () => {
      const normalized: Float32Array = AudioUtils.normalizeAudio(new Float32Array([0.25, -0.5, 1]));

      expect(normalized[0]).assertEqual(0.25);
      expect(normalized[1]).assertEqual(-0.5);
      expect(normalized[2]).assertEqual(1);
    });

    it('maps PCM16 RMS volume to a speech-friendly display range', 0, () => {
      const silenceLevel: number = AudioRecorder.calculateAudioLevel(new ArrayBuffer(0));
      const normalSpeechLevel: number = AudioRecorder.calculateAudioLevel(createPcmBuffer([1000, -1000, 1000, -1000]));
      const loudLevel: number = AudioRecorder.calculateAudioLevel(createPcmBuffer([30000, -30000, 30000, -30000]));

      expect(silenceLevel).assertEqual(0);
      expect(normalSpeechLevel > 50).assertTrue();
      expect(normalSpeechLevel < 70).assertTrue();
      expect(loudLevel).assertEqual(100);
    });

    it('rejects invalid wav data', 0, () => {
      let errorMessage: string = '';

      try {
        AudioUtils.extractWavPcmData(new ArrayBuffer(8));
      } catch (error) {
        errorMessage = (error as Error).message;
      }

      expect(errorMessage).assertContain('WAV 文件太小');
    });
  });
}

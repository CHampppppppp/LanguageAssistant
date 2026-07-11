import { describe, expect, it } from '@ohos/hypium';
import { VoiceActivityDetector, VoiceActivityDetectorOptions } from '../main/ets/core/audio/VoiceActivityDetector';

const TEST_OPTIONS: VoiceActivityDetectorOptions = {
  speechThresholdPercent: 5,
  silenceTimeoutMs: 200,
  minimumSpeechMs: 100,
  maximumSpeechMs: 1000
};

export default function voiceActivityDetectorTest() {
  describe('voiceActivityDetectorTest', () => {
    it('does not create an utterance from silence alone', 0, () => {
      const detector: VoiceActivityDetector = new VoiceActivityDetector(TEST_OPTIONS);
      const result: ArrayBuffer | null = detector.push(new ArrayBuffer(4096), 0);

      expect(result === null).assertTrue();
    });

    it('returns an utterance after the configured silence timeout', 0, () => {
      const detector: VoiceActivityDetector = new VoiceActivityDetector(TEST_OPTIONS);
      const speech: ArrayBuffer | null = detector.push(new ArrayBuffer(4096), 10);
      const firstSilence: ArrayBuffer | null = detector.push(new ArrayBuffer(4096), 0);
      const finalSilence: ArrayBuffer | null = detector.push(new ArrayBuffer(4096), 0);

      expect(speech === null).assertTrue();
      expect(firstSilence === null).assertTrue();
      expect(finalSilence === null).assertFalse();
      if (finalSilence) {
        expect(finalSilence.byteLength).assertEqual(12288);
      }
    });

    it('does not count trailing silence as valid speech duration', 0, () => {
      const detector: VoiceActivityDetector = new VoiceActivityDetector({
        speechThresholdPercent: 5,
        silenceTimeoutMs: 200,
        minimumSpeechMs: 200,
        maximumSpeechMs: 1000
      });
      detector.push(new ArrayBuffer(4096), 10);
      detector.push(new ArrayBuffer(4096), 0);
      const result: ArrayBuffer | null = detector.push(new ArrayBuffer(4096), 0);

      expect(result === null).assertTrue();
    });

    it('resets after one utterance and detects the next utterance', 0, () => {
      const detector: VoiceActivityDetector = new VoiceActivityDetector(TEST_OPTIONS);
      detector.push(new ArrayBuffer(4096), 10);
      detector.push(new ArrayBuffer(4096), 0);
      const firstUtterance: ArrayBuffer | null = detector.push(new ArrayBuffer(4096), 0);

      const nextSpeech: ArrayBuffer | null = detector.push(new ArrayBuffer(4096), 10);
      detector.push(new ArrayBuffer(4096), 0);
      const secondUtterance: ArrayBuffer | null = detector.push(new ArrayBuffer(4096), 0);

      expect(firstUtterance === null).assertFalse();
      expect(nextSpeech === null).assertTrue();
      expect(secondUtterance === null).assertFalse();
    });
  });
}

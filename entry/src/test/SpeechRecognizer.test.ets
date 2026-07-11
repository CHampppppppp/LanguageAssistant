import { describe, it, expect } from '@ohos/hypium';
import { SpeechRecognizer } from '../main/ets/core/SpeechRecognizer';
import { AudioRecorder } from '../main/ets/core/audio/AudioRecorder';
import { RecordingState } from '../main/ets/core/audio/RecordingState';
import { AsrService } from '../main/ets/core/asr/AsrService';

class FakeAudioRecorder extends AudioRecorder {
  startCalled: boolean = false;
  stopCalled: boolean = false;
  lastMarkedState: RecordingState = RecordingState.IDLE;
  private nextBuffer: ArrayBuffer;

  constructor(nextBuffer: ArrayBuffer = new ArrayBuffer(0)) {
    super();
    this.nextBuffer = nextBuffer;
  }

  async startRecording(): Promise<void> {
    this.startCalled = true;
    this.lastMarkedState = RecordingState.RECORDING;
  }

  async stopRecording(): Promise<ArrayBuffer> {
    this.stopCalled = true;
    this.lastMarkedState = RecordingState.STOPPING;
    return this.nextBuffer;
  }

  isRecordingActive(): boolean {
    return this.lastMarkedState === RecordingState.RECORDING;
  }

  getState(): RecordingState {
    return this.lastMarkedState;
  }

  markRecognizing(): void {
    this.lastMarkedState = RecordingState.RECOGNIZING;
  }

  markCompleted(): void {
    this.lastMarkedState = RecordingState.COMPLETED;
  }

  markFailed(): void {
    this.lastMarkedState = RecordingState.FAILED;
  }
}

class FakeAsrService implements AsrService {
  lastBufferLength: number = 0;
  private readonly textToReturn: string;
  private readonly shouldThrow: boolean;

  constructor(textToReturn: string, shouldThrow: boolean = false) {
    this.textToReturn = textToReturn;
    this.shouldThrow = shouldThrow;
  }

  async recognize(audioBuffer: ArrayBuffer): Promise<string> {
    this.lastBufferLength = audioBuffer.byteLength;
    if (this.shouldThrow) {
      throw new Error('mock asr failure');
    }
    return this.textToReturn;
  }
}

export default function speechRecognizerTest() {
  describe('speechRecognizerTest', () => {
    it('trims odd pcm byte length before calling asr service', 0, async () => {
      const recorder: FakeAudioRecorder = new FakeAudioRecorder();
      const asrService: FakeAsrService = new FakeAsrService('hello');
      const recognizer: SpeechRecognizer = new SpeechRecognizer(recorder, asrService);

      const result: string = await recognizer.recognize(new Uint8Array([1, 2, 3]).buffer);

      expect(result).assertEqual('hello');
      expect(asrService.lastBufferLength).assertEqual(2);
      expect(recorder.getState()).assertEqual(RecordingState.COMPLETED);
      expect(recognizer.getLastErrorMessage()).assertEqual('');
      expect(recognizer.getLastFailureKind()).assertEqual('none');
    });

    it('marks failed state when audio buffer is empty', 0, async () => {
      const recorder: FakeAudioRecorder = new FakeAudioRecorder();
      const asrService: FakeAsrService = new FakeAsrService('ignored');
      const recognizer: SpeechRecognizer = new SpeechRecognizer(recorder, asrService);

      const result: string = await recognizer.recognize(new ArrayBuffer(0));

      expect(result).assertEqual('');
      expect(asrService.lastBufferLength).assertEqual(0);
      expect(recorder.getState()).assertEqual(RecordingState.FAILED);
      expect(recognizer.getLastErrorMessage()).assertEqual('音频数据为空或长度无效');
      expect(recognizer.getLastFailureKind()).assertEqual('empty_audio');
    });

    it('delegates recording start and stop to audio recorder', 0, async () => {
      const buffer: ArrayBuffer = new Uint8Array([1, 2, 3, 4]).buffer;
      const recorder: FakeAudioRecorder = new FakeAudioRecorder(buffer);
      const recognizer: SpeechRecognizer = new SpeechRecognizer(recorder, new FakeAsrService('ok'));

      await recognizer.startRecording();
      const recordedBuffer: ArrayBuffer = await recognizer.stopRecording();

      expect(recorder.startCalled).assertTrue();
      expect(recorder.stopCalled).assertTrue();
      expect(recordedBuffer.byteLength).assertEqual(4);
    });

    it('stores the latest asr error message on failure', 0, async () => {
      const recorder: FakeAudioRecorder = new FakeAudioRecorder();
      const recognizer: SpeechRecognizer = new SpeechRecognizer(recorder, new FakeAsrService('', true));

      const result: string = await recognizer.recognize(new Uint8Array([1, 2]).buffer);

      expect(result).assertEqual('');
      expect(recorder.getState()).assertEqual(RecordingState.FAILED);
      expect(recognizer.getLastErrorMessage()).assertContain('mock asr failure');
      expect(recognizer.getLastFailureKind()).assertEqual('unknown');
    });

    it('normalizes recognized text and exposes profile boundary note', 0, async () => {
      const recorder: FakeAudioRecorder = new FakeAudioRecorder();
      const recognizer: SpeechRecognizer = new SpeechRecognizer(recorder, new FakeAsrService(' hello   world \n'));

      const result: string = await recognizer.recognize(new Uint8Array([1, 2]).buffer);
      const profileInfo = recognizer.getRecognitionProfileInfo();

      expect(result).assertEqual('hello world');
      expect(recognizer.getLastRecognizedText()).assertEqual('hello world');
      expect(profileInfo.profileId).assertEqual('chinese_realtime');
      expect(profileInfo.boundaryNote).assertContain('LibriSpeech');
    });
  });
}

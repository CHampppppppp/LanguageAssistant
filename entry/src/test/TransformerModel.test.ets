import { describe, it, expect } from '@ohos/hypium';
import {
  TransformerIntentCandidate,
  TransformerModel,
  TransformerPrediction
} from '../main/ets/model/TransformerModel';
import { VoiceIntent } from '../main/ets/core/nlu/VoiceIntent';

export default function transformerModelTest() {
  describe('transformerModelTest', () => {
    it('fails prediction before model is loaded', 0, () => {
      const model: TransformerModel = new TransformerModel();
      let errorMessage: string = '';

      try {
        model.predictIntent('现在几点了');
      } catch (error) {
        errorMessage = (error as Error).message;
      }

      expect(errorMessage).assertContain('模型未加载');
    });

    it('recognizes time query intent after loading', 0, async () => {
      const model: TransformerModel = new TransformerModel();
      await model.loadModel();

      const prediction: TransformerPrediction = model.predictIntent('现在几点了');

      expect(prediction.intent).assertEqual(VoiceIntent.TIME_QUERY);
      expect(prediction.confidence).assertLarger(0.6);
      expect(prediction.isExperimental).assertTrue();
      expect(prediction.inferenceTimeMs >= 0).assertTrue();
      expect(prediction.featureDimension).assertLarger(0);
      expect(prediction.modelInfo).assertContain('ASR text semantic');
    });

    it('recognizes volume up intent after loading', 0, async () => {
      const model: TransformerModel = new TransformerModel();
      await model.loadModel();

      const prediction: TransformerPrediction = model.predictIntent('音量调大');

      expect(prediction.intent).assertEqual(VoiceIntent.VOLUME_UP);
      expect(prediction.confidence).assertLarger(0.6);
    });

    it('recognizes open app intent after loading', 0, async () => {
      const model: TransformerModel = new TransformerModel();
      await model.loadModel();

      const prediction: TransformerPrediction = model.predictIntent('打开微信');

      expect(prediction.intent).assertEqual(VoiceIntent.OPEN_APP);
      expect(prediction.confidence).assertLarger(0.6);
    });

    it('sorts intent candidates by score', 0, async () => {
      const model: TransformerModel = new TransformerModel();
      await model.loadModel();

      const prediction: TransformerPrediction = model.predictIntent('请把声音调大一点');

      expect(prediction.candidates.length).assertLarger(1);
      for (let i: number = 1; i < prediction.candidates.length; i++) {
        const previous: TransformerIntentCandidate = prediction.candidates[i - 1];
        const current: TransformerIntentCandidate = prediction.candidates[i];
        expect(previous.score >= current.score).assertTrue();
      }
    });

    it('keeps meaningless text unknown or low confidence', 0, async () => {
      const model: TransformerModel = new TransformerModel();
      await model.loadModel();

      const prediction: TransformerPrediction = model.predictIntent('随便说一句没意义的话');

      if (prediction.intent === VoiceIntent.UNKNOWN) {
        expect(prediction.confidence).assertLess(0.5);
      } else {
        expect(prediction.confidence).assertLess(0.6);
      }
    });
  });
}

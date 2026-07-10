import { describe, it, expect } from '@ohos/hypium';
import { SemanticUnderstanding } from '../main/ets/core/SemanticUnderstanding';
import { VoiceIntent } from '../main/ets/core/nlu/VoiceIntent';
import { VoiceCommand } from '../main/ets/model/VoiceCommand';

export default function semanticUnderstandingTest() {
  describe('semanticUnderstandingTest', () => {
    it('recognizes time query intent', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('现在几点了');

      expect(command.intent).assertEqual(VoiceIntent.TIME_QUERY);
      expect(command.confidence).assertLarger(0.9);
    });

    it('recognizes weather query intent', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('今天天气怎么样');

      expect(command.intent).assertEqual(VoiceIntent.WEATHER_QUERY);
      expect(command.confidence).assertLarger(0.9);
    });

    it('extracts music name from play music command', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('播放周杰伦的歌');

      expect(command.intent).assertEqual(VoiceIntent.PLAY_MUSIC);
      expect(command.getEntity('music_name')).assertEqual('周杰伦的歌');
      expect(command.confidence).assertLarger(0.9);
    });

    it('recognizes volume up and down intents', 0, () => {
      const upCommand: VoiceCommand = new SemanticUnderstanding().understand('音量调大');
      const downCommand: VoiceCommand = new SemanticUnderstanding().understand('声音小点');

      expect(upCommand.intent).assertEqual(VoiceIntent.VOLUME_UP);
      expect(downCommand.intent).assertEqual(VoiceIntent.VOLUME_DOWN);
    });

    it('extracts alarm time entities', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('设置8点30分闹钟');

      expect(command.intent).assertEqual(VoiceIntent.SET_ALARM);
      expect(command.getEntity('hour')).assertEqual('8');
      expect(command.getEntity('minute')).assertEqual('30');
    });

    it('extracts app name from open app command', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('打开微信');

      expect(command.intent).assertEqual(VoiceIntent.OPEN_APP);
      expect(command.getEntity('app_name')).assertEqual('微信');
    });

    it('extracts app name from close app command', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('关闭支付宝应用');

      expect(command.intent).assertEqual(VoiceIntent.CLOSE_APP);
      expect(command.getEntity('app_name')).assertEqual('支付宝');
    });

    it('keeps ambiguous open app command without app entity', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('打开应用');

      expect(command.intent).assertEqual(VoiceIntent.OPEN_APP);
      expect(command.getEntity('app_name')).assertEqual('');
    });

    it('does not extract a music name when only generic music command is provided', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('播放音乐');

      expect(command.intent).assertEqual(VoiceIntent.PLAY_MUSIC);
      expect(command.getEntity('music_name')).assertEqual('');
    });

    it('keeps unknown input low confidence', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('随便说一句没意义的话');

      expect(command.intent).assertEqual(VoiceIntent.UNKNOWN);
      expect(command.confidence).assertLess(0.5);
    });

    it('keeps high confidence rule result before transformer assist', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('现在几点了');

      expect(command.intent).assertEqual(VoiceIntent.TIME_QUERY);
      expect(command.confidence).assertLarger(0.9);
      expect(command.getEntity('semantic_source')).assertEqual('rule');
    });

    it('uses transformer assist when rule confidence is low', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('麻烦看下时间');

      expect(command.intent).assertEqual(VoiceIntent.TIME_QUERY);
      expect(command.confidence).assertLarger(0.6);
      expect(command.getEntity('semantic_source')).assertEqual('transformer_aux');
    });

    it('keeps unknown when transformer confidence is low', 0, () => {
      const command: VoiceCommand = new SemanticUnderstanding().understand('随便念一段没有指令含义的话');

      expect(command.intent).assertEqual(VoiceIntent.UNKNOWN);
      expect(command.confidence).assertLess(0.5);
      expect(command.getEntity('semantic_source')).assertEqual('unknown');
    });
  });
}

import { describe, it, expect } from '@ohos/hypium';
import { AccuracyMetric } from '../main/ets/core/evaluation/AccuracyMetric';
import { createChineseIFlytekBusiness, createEnglishIFlytekBusiness } from '../main/ets/core/asr/IFlytekTypes';
import { CommandExecutionStatus } from '../main/ets/core/command/CommandResult';
import { MockCommandExecutor } from '../main/ets/core/command/CommandExecutor';
import { VoiceCommand } from '../main/ets/model/VoiceCommand';

export default function architectureBoundaryTest() {
  describe('architectureBoundaryTest', () => {
    it('calculates word accuracy from transcript instead of semantic confidence', 0, () => {
      const result = AccuracyMetric.calculateWordAccuracy('hello brave world', 'hello world');

      expect(result.wordAccuracy).assertLarger(0);
      expect(result.wordAccuracy).assertLess(1);
      expect(result.totalWords).assertEqual(2);
    });

    it('keeps realtime Chinese ASR config separate from LibriSpeech English config', 0, () => {
      const chinese = createChineseIFlytekBusiness();
      const english = createEnglishIFlytekBusiness();

      expect(chinese.language).assertEqual('zh_cn');
      expect(chinese.accent).assertEqual('mandarin');
      expect(english.language).assertEqual('en_us');
      expect(english.accent).assertEqual('general');
    });

    it('marks simulated command execution explicitly', 0, async () => {
      const executor = new MockCommandExecutor();
      const command = new VoiceCommand('weather_query', '今天天气怎么样');

      const result = await executor.execute(command);

      expect(result.status).assertEqual(CommandExecutionStatus.SIMULATED);
      expect(result.isSimulated).assertTrue();
    });
  });
}

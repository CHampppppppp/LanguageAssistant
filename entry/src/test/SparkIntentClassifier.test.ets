import { describe, it, expect } from '@ohos/hypium';
import { SparkChatClient } from '../main/ets/core/nlu/SparkChatClient';
import { SparkIntentClassifier } from '../main/ets/core/nlu/SparkIntentClassifier';
import { SparkChatRequest, SparkChatResponse } from '../main/ets/core/nlu/SparkIntentTypes';
import { VoiceIntent } from '../main/ets/core/nlu/VoiceIntent';
import { VoiceCommand } from '../main/ets/model/VoiceCommand';

class FakeSparkChatClient implements SparkChatClient {
  private response: SparkChatResponse;
  lastRequest: SparkChatRequest | null = null;

  constructor(response: SparkChatResponse) {
    this.response = response;
  }

  async complete(request: SparkChatRequest): Promise<SparkChatResponse> {
    this.lastRequest = request;
    return this.response;
  }
}

class FailingSparkChatClient implements SparkChatClient {
  async complete(request: SparkChatRequest): Promise<SparkChatResponse> {
    throw new Error('network unavailable');
  }
}

export default function sparkIntentClassifierTest() {
  describe('sparkIntentClassifierTest', () => {
    it('parses supported app intent from Spark JSON', 0, async () => {
      const client = new FakeSparkChatClient({
        choices: [{ message: { content: '{"intent":"open_app","confidence":0.95,"entities":{"app_name":"相册"}}' } }]
      });
      const command: VoiceCommand = await new SparkIntentClassifier(client).understand('帮我看看照片');

      expect(command.intent).assertEqual(VoiceIntent.OPEN_APP);
      expect(command.getEntity('app_name')).assertEqual('图库');
      expect(command.getEntity('semantic_source')).assertEqual('spark_lite');
      expect(client.lastRequest?.response_format.type).assertEqual('json_object');
      expect(client.lastRequest?.messages.length).assertEqual(1);
    });

    it('rejects unsupported app returned by model', 0, async () => {
      const client = new FakeSparkChatClient({
        choices: [{ message: { content: '{"intent":"open_app","confidence":0.95,"entities":{"app_name":"微信"}}' } }]
      });
      const command: VoiceCommand = await new SparkIntentClassifier(client).understand('打开微信');

      expect(command.intent).assertEqual(VoiceIntent.UNKNOWN);
    });

    it('rejects low confidence model result', 0, async () => {
      const client = new FakeSparkChatClient({
        choices: [{ message: { content: '{"intent":"volume_up","confidence":0.3,"entities":{}}' } }]
      });
      const command: VoiceCommand = await new SparkIntentClassifier(client).understand('声音怎么样');

      expect(command.intent).assertEqual(VoiceIntent.UNKNOWN);
    });

    it('rejects out of range volume entity', 0, async () => {
      const client = new FakeSparkChatClient({
        choices: [{ message: { content: '{"intent":"volume_set","confidence":0.9,"entities":{"volume_target":"200","volume_unit":"percent"}}' } }]
      });
      const command: VoiceCommand = await new SparkIntentClassifier(client).understand('音量开到两百');

      expect(command.intent).assertEqual(VoiceIntent.UNKNOWN);
    });

    it('returns unknown on invalid response JSON', 0, async () => {
      const client = new FakeSparkChatClient({ choices: [{ message: { content: 'not-json' } }] });
      const command: VoiceCommand = await new SparkIntentClassifier(client).understand('打开设置');

      expect(command.intent).assertEqual(VoiceIntent.UNKNOWN);
    });

    it('returns unknown when Spark request fails', 0, async () => {
      const command: VoiceCommand = await new SparkIntentClassifier(new FailingSparkChatClient()).understand('几点了');

      expect(command.intent).assertEqual(VoiceIntent.UNKNOWN);
      expect(command.getEntity('semantic_source')).assertEqual('spark_lite_failed');
    });
  });
}

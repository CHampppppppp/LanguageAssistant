import { describe, it, expect } from '@ohos/hypium';
import { VoiceCommand } from '../main/ets/model/VoiceCommand';

export default function localUnitTest() {
  describe('localModelSmokeTest', () => {
    it('serializes and restores voice command entities', 0, () => {
      const command: VoiceCommand = new VoiceCommand('open_app', '打开微信');
      command.confidence = 0.95;
      command.setEntity('app_name', '微信');

      const restored: VoiceCommand = VoiceCommand.fromJSON(command.toJSON());

      expect(restored.intent).assertEqual('open_app');
      expect(restored.originalText).assertEqual('打开微信');
      expect(restored.confidence).assertEqual(0.95);
      expect(restored.getEntity('app_name')).assertEqual('微信');
      expect(restored.isValid()).assertTrue();
    });

    it('treats unknown command as invalid even when text exists', 0, () => {
      const command: VoiceCommand = new VoiceCommand('unknown', '随便说一句');
      command.confidence = 0.9;

      expect(command.isValid()).assertFalse();
    });
  });
}

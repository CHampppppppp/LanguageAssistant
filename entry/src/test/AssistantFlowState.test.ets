import { describe, it, expect } from '@ohos/hypium';
import {
  AssistantFlowState,
  getAssistantFlowLabel,
  isAssistantFlowBusy,
  isAssistantFlowFailure,
  isAssistantFlowTerminal
} from '../main/ets/viewmodel/AssistantFlowState';

export default function assistantFlowStateTest() {
  describe('assistantFlowStateTest', () => {
    it('marks recording, recognizing, executing and evaluating as busy states', 0, () => {
      expect(isAssistantFlowBusy(AssistantFlowState.RECORDING)).assertTrue();
      expect(isAssistantFlowBusy(AssistantFlowState.RECOGNIZING)).assertTrue();
      expect(isAssistantFlowBusy(AssistantFlowState.EXECUTING)).assertTrue();
      expect(isAssistantFlowBusy(AssistantFlowState.EVALUATING)).assertTrue();
      expect(isAssistantFlowBusy(AssistantFlowState.IDLE)).assertFalse();
      expect(isAssistantFlowBusy(AssistantFlowState.COMPLETED)).assertFalse();
    });

    it('separates terminal states from in-flight states', 0, () => {
      expect(isAssistantFlowTerminal(AssistantFlowState.COMPLETED)).assertTrue();
      expect(isAssistantFlowTerminal(AssistantFlowState.FAILED)).assertTrue();
      expect(isAssistantFlowTerminal(AssistantFlowState.RECOGNIZING)).assertFalse();
    });

    it('marks failed state as the only failure state', 0, () => {
      expect(isAssistantFlowFailure(AssistantFlowState.FAILED)).assertTrue();
      expect(isAssistantFlowFailure(AssistantFlowState.COMPLETED)).assertFalse();
      expect(isAssistantFlowFailure(AssistantFlowState.IDLE)).assertFalse();
    });

    it('provides stable user-facing labels for flow states', 0, () => {
      expect(getAssistantFlowLabel(AssistantFlowState.IDLE)).assertEqual('待命');
      expect(getAssistantFlowLabel(AssistantFlowState.RECORDING)).assertEqual('录音中');
      expect(getAssistantFlowLabel(AssistantFlowState.RECOGNIZING)).assertEqual('识别中');
      expect(getAssistantFlowLabel(AssistantFlowState.EXECUTING)).assertEqual('执行中');
      expect(getAssistantFlowLabel(AssistantFlowState.EVALUATING)).assertEqual('评测中');
      expect(getAssistantFlowLabel(AssistantFlowState.COMPLETED)).assertEqual('完成');
      expect(getAssistantFlowLabel(AssistantFlowState.FAILED)).assertEqual('失败');
    });
  });
}

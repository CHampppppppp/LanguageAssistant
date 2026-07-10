export enum AssistantFlowState {
  IDLE = 'idle',
  RECORDING = 'recording',
  RECOGNIZING = 'recognizing',
  EXECUTING = 'executing',
  EVALUATING = 'evaluating',
  COMPLETED = 'completed',
  FAILED = 'failed'
}

export function isAssistantFlowBusy(state: AssistantFlowState): boolean {
  return state === AssistantFlowState.RECORDING ||
    state === AssistantFlowState.RECOGNIZING ||
    state === AssistantFlowState.EXECUTING ||
    state === AssistantFlowState.EVALUATING;
}

export function isAssistantFlowTerminal(state: AssistantFlowState): boolean {
  return state === AssistantFlowState.COMPLETED || state === AssistantFlowState.FAILED;
}

export function isAssistantFlowFailure(state: AssistantFlowState): boolean {
  return state === AssistantFlowState.FAILED;
}

export function getAssistantFlowLabel(state: AssistantFlowState): string {
  switch (state) {
    case AssistantFlowState.IDLE:
      return '待命';
    case AssistantFlowState.RECORDING:
      return '录音中';
    case AssistantFlowState.RECOGNIZING:
      return '识别中';
    case AssistantFlowState.EXECUTING:
      return '执行中';
    case AssistantFlowState.EVALUATING:
      return '评测中';
    case AssistantFlowState.COMPLETED:
      return '完成';
    case AssistantFlowState.FAILED:
      return '失败';
    default:
      return '未知';
  }
}

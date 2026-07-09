export enum CommandExecutionStatus {
  SUCCESS = 'success',
  FAILED = 'failed',
  SIMULATED = 'simulated',
  UNSUPPORTED = 'unsupported'
}

export interface CommandExecutionResult {
  status: CommandExecutionStatus;
  message: string;
  intent: string;
  isSimulated: boolean;
}

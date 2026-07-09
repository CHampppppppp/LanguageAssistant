export class TextFeedback {
  createFeedback(commandMessage: string): string {
    if (!commandMessage) {
      return '暂无反馈';
    }

    return commandMessage;
  }

  release(): void {
  }
}

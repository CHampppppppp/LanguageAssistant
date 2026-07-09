export interface TimeProvider {
  now(): Date;
}

export class SystemTimeProvider implements TimeProvider {
  now(): Date {
    return new Date();
  }
}

export class TimeQueryService {
  private timeProvider: TimeProvider;

  constructor(timeProvider: TimeProvider = new SystemTimeProvider()) {
    this.timeProvider = timeProvider;
  }

  getCurrentTimeMessage(): string {
    const now: Date = this.timeProvider.now();
    const hours: string = this.toTwoDigits(now.getHours());
    const minutes: string = this.toTwoDigits(now.getMinutes());
    return `现在是${hours}点${minutes}分`;
  }

  private toTwoDigits(value: number): string {
    return value.toString().padStart(2, '0');
  }
}

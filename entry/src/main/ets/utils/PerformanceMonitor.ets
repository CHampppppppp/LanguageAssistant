const TARGET_ACCURACY_PERCENT: number = 93;
const TARGET_RESPONSE_TIME_MS: number = 2000;

export interface PerformanceMetrics {
  recognitionAccuracy: number;
  avgResponseTime: number;
  maxResponseTime: number;
  minResponseTime: number;
  totalRequests: number;
  successRate: number;
  timestamp: number;
}

export class PerformanceMonitor {
  private metrics: PerformanceMetrics = {
    recognitionAccuracy: 0,
    avgResponseTime: 0,
    maxResponseTime: 0,
    minResponseTime: Infinity,
    totalRequests: 0,
    successRate: 0,
    timestamp: Date.now()
  };

  private responseTimes: number[] = [];
  private wordAccuracySamples: number[] = [];
  private successfulRecognitions: number = 0;
  private totalRecognitions: number = 0;

  recordRecognition(correct: boolean): void {
    this.totalRecognitions++;
    if (correct) {
      this.successfulRecognitions++;
    }
    this.updateAccuracy();
  }

  recordResponseTime(time: number): void {
    this.responseTimes.push(time);
    this.metrics.totalRequests++;

    if (time > this.metrics.maxResponseTime) {
      this.metrics.maxResponseTime = time;
    }
    if (time < this.metrics.minResponseTime) {
      this.metrics.minResponseTime = time;
    }

    this.updateAvgResponseTime();
  }

  recordWordAccuracy(accuracy: number): void {
    const normalizedAccuracy: number = accuracy <= 1 ? accuracy * 100 : accuracy;
    const clampedAccuracy: number = Math.max(0, Math.min(100, normalizedAccuracy));
    this.wordAccuracySamples.push(clampedAccuracy);
    this.metrics.recognitionAccuracy = this.calculateAverage(this.wordAccuracySamples);
  }

  recordEvaluationResult(wordAccuracy: number, responseTime: number, success: boolean): void {
    this.recordWordAccuracy(wordAccuracy);
    this.recordResponseTime(responseTime);
    this.recordRecognition(success);
  }

  private updateAccuracy(): void {
    if (this.wordAccuracySamples.length > 0) {
      return;
    }

    if (this.totalRecognitions > 0) {
      this.metrics.recognitionAccuracy = (this.successfulRecognitions / this.totalRecognitions) * 100;
    }
  }

  private updateAvgResponseTime(): void {
    if (this.responseTimes.length > 0) {
      this.metrics.avgResponseTime = this.calculateAverage(this.responseTimes);
    }
  }

  getMetrics(): PerformanceMetrics {
    this.metrics.successRate = this.totalRecognitions > 0
      ? (this.successfulRecognitions / this.totalRecognitions) * 100
      : 0;
    this.metrics.timestamp = Date.now();

    const result: PerformanceMetrics = {
      recognitionAccuracy: this.metrics.recognitionAccuracy,
      avgResponseTime: this.metrics.avgResponseTime,
      maxResponseTime: this.metrics.maxResponseTime,
      minResponseTime: this.metrics.minResponseTime === Infinity ? 0 : this.metrics.minResponseTime,
      totalRequests: this.metrics.totalRequests,
      successRate: this.metrics.successRate,
      timestamp: this.metrics.timestamp
    };
    return result;
  }

  reset(): void {
    this.metrics = {
      recognitionAccuracy: 0,
      avgResponseTime: 0,
      maxResponseTime: 0,
      minResponseTime: Infinity,
      totalRequests: 0,
      successRate: 0,
      timestamp: Date.now()
    };
    this.responseTimes = [];
    this.wordAccuracySamples = [];
    this.successfulRecognitions = 0;
    this.totalRecognitions = 0;
  }

  isAccuracy达标(): boolean {
    return this.metrics.recognitionAccuracy >= TARGET_ACCURACY_PERCENT;
  }

  isResponseTime达标(): boolean {
    return this.metrics.avgResponseTime <= TARGET_RESPONSE_TIME_MS;
  }

  isAccuracyTargetMet(): boolean {
    return this.isAccuracy达标();
  }

  isResponseTimeTargetMet(): boolean {
    return this.isResponseTime达标();
  }

  getPerformanceReport(): string {
    const minTime: number = this.metrics.minResponseTime === Infinity ? 0 : this.metrics.minResponseTime;
    return `性能报告:\n准确率: ${this.metrics.recognitionAccuracy.toFixed(2)}%\n平均响应时间: ${this.metrics.avgResponseTime.toFixed(2)}ms\n最大响应时间: ${this.metrics.maxResponseTime}ms\n最小响应时间: ${minTime}ms\n总请求数: ${this.metrics.totalRequests}\n成功率: ${this.metrics.successRate.toFixed(2)}%`;
  }

  private calculateAverage(values: number[]): number {
    if (values.length === 0) {
      return 0;
    }

    let sum: number = 0;
    for (let index: number = 0; index < values.length; index++) {
      sum += values[index];
    }
    return sum / values.length;
  }
}

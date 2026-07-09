

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

  private updateAccuracy(): void {
    if (this.totalRecognitions > 0) {
      this.metrics.recognitionAccuracy = (this.successfulRecognitions / this.totalRecognitions) * 100;
    }
  }

  private updateAvgResponseTime(): void {
    if (this.responseTimes.length > 0) {
      let sum: number = 0;
      for (let i: number = 0; i < this.responseTimes.length; i++) {
        sum += this.responseTimes[i];
      }
      this.metrics.avgResponseTime = sum / this.responseTimes.length;
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
      minResponseTime: this.metrics.minResponseTime,
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
    this.successfulRecognitions = 0;
    this.totalRecognitions = 0;
  }

  isAccuracy达标(): boolean {
    return this.metrics.recognitionAccuracy >= 93;
  }

  isResponseTime达标(): boolean {
    return this.metrics.avgResponseTime <= 2000;
  }

  getPerformanceReport(): string {
    const minTime: number = this.metrics.minResponseTime === Infinity ? 0 : this.metrics.minResponseTime;
    return `性能报告:\n准确率: ${this.metrics.recognitionAccuracy.toFixed(2)}%\n平均响应时间: ${this.metrics.avgResponseTime.toFixed(2)}ms\n最大响应时间: ${this.metrics.maxResponseTime}ms\n最小响应时间: ${minTime}ms\n总请求数: ${this.metrics.totalRequests}\n成功率: ${this.metrics.successRate.toFixed(2)}%`;
  }
}
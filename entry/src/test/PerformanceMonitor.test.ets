import { describe, it, expect } from '@ohos/hypium';
import { PerformanceMonitor } from '../main/ets/utils/PerformanceMonitor';

export default function performanceMonitorTest() {
  describe('performanceMonitorTest', () => {
    it('records evaluation metrics from accuracy and response time', 0, () => {
      const monitor: PerformanceMonitor = new PerformanceMonitor();

      monitor.recordEvaluationResult(0.95, 1200, true);
      monitor.recordEvaluationResult(80, 1800, false);

      const metrics = monitor.getMetrics();

      expect(Math.round(metrics.recognitionAccuracy * 100) / 100).assertEqual(87.5);
      expect(metrics.avgResponseTime).assertEqual(1500);
      expect(metrics.p95ResponseTime).assertEqual(1800);
      expect(metrics.maxResponseTime).assertEqual(1800);
      expect(metrics.minResponseTime).assertEqual(1200);
      expect(metrics.totalRequests).assertEqual(2);
      expect(metrics.successCount).assertEqual(1);
      expect(metrics.failureCount).assertEqual(1);
      expect(metrics.successRate).assertEqual(50);
      expect(monitor.isAccuracyTargetMet()).assertFalse();
      expect(monitor.isResponseTimeTargetMet()).assertTrue();
    });

    it('resets all tracked metrics', 0, () => {
      const monitor: PerformanceMonitor = new PerformanceMonitor();

      monitor.recordEvaluationResult(0.95, 1200, true);
      monitor.reset();

      const metrics = monitor.getMetrics();

      expect(metrics.recognitionAccuracy).assertEqual(0);
      expect(metrics.avgResponseTime).assertEqual(0);
      expect(metrics.p95ResponseTime).assertEqual(0);
      expect(metrics.maxResponseTime).assertEqual(0);
      expect(metrics.minResponseTime).assertEqual(0);
      expect(metrics.totalRequests).assertEqual(0);
      expect(metrics.successCount).assertEqual(0);
      expect(metrics.failureCount).assertEqual(0);
      expect(metrics.successRate).assertEqual(0);
    });
  });
}

export interface EvaluationDetail {
  sampleId: string;
  recognizedText: string;
  groundTruth: string;
  wordAccuracy: number;
  wordErrorRate: number;
  responseTime: number;
  success: boolean;
  reason: string;
}

export interface EvaluationSummary {
  averageWordAccuracy: number;
  averageResponseTime: number;
  evaluatedCount: number;
  totalSampleCount: number;
  successCount: number;
  failureCount: number;
  successRate: number;
  accuracyTargetMet: boolean;
  responseTimeTargetMet: boolean;
  details: EvaluationDetail[];
}

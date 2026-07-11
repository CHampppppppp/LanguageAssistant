import { DatasetAudioFormat, DatasetLoadSummary } from '../../utils/DatasetLoader';

export interface EvaluationDetail {
  sampleId: string;
  recognizedText: string;
  groundTruth: string;
  wordAccuracy: number;
  wordErrorRate: number;
  responseTime: number;
  meetsAccuracyTarget: boolean;
  meetsResponseTimeTarget: boolean;
  success: boolean;
  audioFormat: DatasetAudioFormat;
  audioPreparation: string;
  failureCategory: string;
  reason: string;
}

export interface EvaluationThresholds {
  accuracyPercent: number;
  responseTimeMs: number;
}

export interface EvaluationSummary {
  averageWordAccuracy: number;
  averageResponseTime: number;
  evaluatedCount: number;
  totalSampleCount: number;
  sampleLimit: number;
  successCount: number;
  failureCount: number;
  successRate: number;
  accuracyTargetMet: boolean;
  responseTimeTargetMet: boolean;
  thresholds: EvaluationThresholds;
  datasetLoadSummary: DatasetLoadSummary;
  recognizerProfile: string;
  audioPreparationPolicy: string;
  profileBoundaryNote: string;
  reportText: string;
  details: EvaluationDetail[];
}

export interface WordAccuracyResult {
  referenceText: string;
  hypothesisText: string;
  totalWords: number;
  editDistance: number;
  wordErrorRate: number;
  wordAccuracy: number;
}

export class AccuracyMetric {
  static calculateWordAccuracy(hypothesisText: string, referenceText: string): WordAccuracyResult {
    const referenceWords: string[] = AccuracyMetric.normalizeWords(referenceText);
    const hypothesisWords: string[] = AccuracyMetric.normalizeWords(hypothesisText);
    const totalWords: number = referenceWords.length;
    const editDistance: number = AccuracyMetric.calculateEditDistance(referenceWords, hypothesisWords);
    const wordErrorRate: number = totalWords > 0 ? editDistance / totalWords : 1;
    const wordAccuracy: number = Math.max(0, 1 - wordErrorRate);

    return {
      referenceText,
      hypothesisText,
      totalWords,
      editDistance,
      wordErrorRate,
      wordAccuracy
    };
  }

  private static normalizeWords(text: string): string[] {
    const normalized: string = text
      .toLowerCase()
      .replace(new RegExp('[^a-z0-9\\s]', 'g'), ' ')
      .trim();

    if (!normalized) {
      return [];
    }

    return normalized.split(new RegExp('\\s+'));
  }

  private static calculateEditDistance(referenceWords: string[], hypothesisWords: string[]): number {
    const rowCount: number = referenceWords.length + 1;
    const columnCount: number = hypothesisWords.length + 1;
    const distance: number[][] = [];

    for (let row: number = 0; row < rowCount; row++) {
      distance[row] = [];
      distance[row][0] = row;
    }

    for (let column: number = 0; column < columnCount; column++) {
      distance[0][column] = column;
    }

    for (let row: number = 1; row < rowCount; row++) {
      for (let column: number = 1; column < columnCount; column++) {
        const substitutionCost: number = referenceWords[row - 1] === hypothesisWords[column - 1] ? 0 : 1;
        const deletionCost: number = distance[row - 1][column] + 1;
        const insertionCost: number = distance[row][column - 1] + 1;
        const substitutionDistance: number = distance[row - 1][column - 1] + substitutionCost;
        distance[row][column] = Math.min(deletionCost, insertionCost, substitutionDistance);
      }
    }

    return distance[referenceWords.length][hypothesisWords.length];
  }
}

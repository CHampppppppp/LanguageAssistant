import localUnitTest from './LocalUnit.test';
import architectureBoundaryTest from './ArchitectureBoundary.test';
import commandExecutorTest from './CommandExecutor.test';
import performanceMonitorTest from './PerformanceMonitor.test';
import audioUtilsTest from './AudioUtils.test';
import speechRecognizerTest from './SpeechRecognizer.test';
import libriSpeechEvaluatorTest from './LibriSpeechEvaluator.test';
import semanticUnderstandingTest from './SemanticUnderstanding.test';

export default function testsuite() {
  localUnitTest();
  architectureBoundaryTest();
  commandExecutorTest();
  semanticUnderstandingTest();
  performanceMonitorTest();
  audioUtilsTest();
  speechRecognizerTest();
  libriSpeechEvaluatorTest();
}

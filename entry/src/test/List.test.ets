import localUnitTest from './LocalUnit.test';
import architectureBoundaryTest from './ArchitectureBoundary.test';
import commandExecutorTest from './CommandExecutor.test';
import performanceMonitorTest from './PerformanceMonitor.test';
import audioUtilsTest from './AudioUtils.test';
import speechRecognizerTest from './SpeechRecognizer.test';

export default function testsuite() {
  localUnitTest();
  architectureBoundaryTest();
  commandExecutorTest();
  performanceMonitorTest();
  audioUtilsTest();
  speechRecognizerTest();
}

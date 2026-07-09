import localUnitTest from './LocalUnit.test';
import architectureBoundaryTest from './ArchitectureBoundary.test';
import commandExecutorTest from './CommandExecutor.test';

export default function testsuite() {
  localUnitTest();
  architectureBoundaryTest();
  commandExecutorTest();
}

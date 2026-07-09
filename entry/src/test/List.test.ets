import localUnitTest from './LocalUnit.test';
import architectureBoundaryTest from './ArchitectureBoundary.test';

export default function testsuite() {
  localUnitTest();
  architectureBoundaryTest();
}

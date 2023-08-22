import 'package:lint_mut_infect/lint_mut_infect.dart';
import 'package:test/test.dart';

void isInconsequential() {}

// expect_lint: mut_infect
void isNotMarked() {
  isMarkedMut();
}

void isMarkedMut() {}

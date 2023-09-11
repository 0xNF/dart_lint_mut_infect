// ignore_for_file: avoid_single_cascade_in_expression_statements, unnecessary_getters_setters, unused_local_variable

int globalScopeVar = 0;

abstract class ForOveridding {
  void doSomeThing();
}

// FYI(nf, 09/08/23): Shouldn't be marked, because it is `main`
void main() {
  globalScopeVar = 3;
}

class BagB extends ForOveridding {
  String s = "";

// FYI(nf, 09/08/23): Shouldn't me marked, because it is `@override`
  @override
  void doSomeThing() {
    globalScopeVar = 3;
  }
}

class BagA {
  int i;
  List<String> strings;
  BagB b = BagB();

  BagA._({this.i = 0, this.strings = const <String>[]});

  factory BagA.sample(int i) {
    return BagA._(i: i);
  }

  // expect_lint: mut_out_of_scope
  void shouldMarkInBagA() {
    globalScopeVar = 1;
  }

  void create(String path) {}
}

/* This section shows that exemptions should be made for certain conditions */
abstract class MockWidget {
  int build();
}

class ImplMockWidget extends MockWidget {
  /* Shows that override method should not be considered */
  @override
  int build() {
    globalScopeVar = 2;
    return 0;
  }

  /* Shows that setters should not be considered */
  int get withSetter => globalScopeVar;
  set withSetter(int i) => globalScopeVar = i;
}

/* This section shows that reassignment to the variable at a depth of n=1 is fine, but reasignment to its inner items is not */
void reAssignDepth1(BagA bagADepth1) {
  bagADepth1 = BagA._();
}

// expect_lint: mut_param
void reAssignDepth2List(BagA bagADepth2List) {
  bagADepth2List.strings = <String>["dummy"];
}

// expect_lint: mut_param
void reAssignDepth2IntMut(BagA bagADepth2Int) {
  bagADepth2Int.i = 2;
}

// FYI(nf, 09/11/23): Cascaded inline assignments should not cause a lint warning
BagA createZipFile(String path) {
  final encoder = BagA._()..create(path);
  return encoder;
}

List<String> visible = [];
List<String> hidden = [];
List<String> makeVisible(String id) {
  final newVis = {...visible, id}.toList();
  final newHidden = [...hidden]..remove(id);

  return [...newVis, ...newHidden];
}

/// Special function to handle moving between LibCoordinator and LibGravioCloud
int dontThrowForComplexCascade() {
  final fromAuth1 = BagA._();
  final lc2auth = BagA.sample(fromAuth1.i)..i = 2;
  return 0;
}

int dontThrowForAssignmentOnConstructorCascade() {
  BagA._()..i = 12;
  return 0;
}

void dummyMut() {}

// expect_lint: mut_infect
void markThisDummy() {
  dummyMut();
}

void dontMarkThisDummyMut() {
  dummyMut();
}

// FYI(nf, 09/08/23): This should not be marked for any errors because it modifies nothing and calls no mut functions
void isInconsequential() {}

// expect_lint: mut_infect
void isNotMarked() {
  isMarkedMut();
}

// FYI(nf, 09/08/23): Should not be marked for errors because its marked mut
void isMarkedMut() {}

// FYI(nf, 09/08/23): Should be marked for Mut because it mutates an out of scope
// expect_lint: mut_out_of_scope
void mutsGlobalScope() {
  globalScopeVar = 2;
}

void mutsGlobalScopeMut() {
  globalScopeVar = 3;
}

// FYI(nf, 09/08/23): Should NOT be marked for errors because the variable is entirely within the function scope
void mutsInnerScope() {
  int i = 0;
  void inner() {
    i = 2;
  }

  print(i);

  inner();
}

// FYI(nf, 09/08/23): should be marked Mut for modifying outer scope
void mutsOuterScope() {
  int i = -1;

  // expect_lint: mut_out_of_scope
  void inner() {
    globalScopeVar = 4;
  }

  print(i);

  inner();
}

void mutsOuterScopeMut() {
  int i = 0;

  void innerMut() {
    globalScopeVar = 5;
  }

  print(i);

  innerMut();
}

// FYI(nf, 09/08/23): Should NOT be marked for errors because the variable is entirely within the function scope
void doesNotMutAnything() {
  void inner() {}

  inner();
}

// FYI(nf, 09/08/23): Should mark a as mut, simple
// expect_lint: mut_param
void markThisToo(BagA a) {
  a.i = 1;
}

void dontMarkThisToo(BagA aMut) {
  aMut.i = 1;
}

// expect_lint: mut_param
void markThisTooMut(BagA a) {
  a.i = 2;
}

void dontMarkThisTooMut(BagA aMut) {
  aMut.i = 2;
}

// expect_lint: mut_out_of_scope, mut_param
void markThisToo2(BagA a) {
  a..b.s = "lol";
}

// expect_lint: mut_out_of_scope
void dontMarkThisToo2(BagA aMut) {
  aMut..b.s = "lol";
}

// expect_lint: mut_param
void markThisToo3Mut(BagA b) {
  b
    ..b.s = "lmao"
    ..i = 3;
}

void dontMarkThisToo3Mut(BagA bMut) {
  bMut
    ..b.s = "lmao"
    ..i = 2;
}

/* The following items won't be marked for MutParam because they are Dart primitive types, which are passed by value */
void dontMarkRequiredPrimitiveInt(int i, {required int i2}) {
  i2 = 3;
}

void dontMarkDefaultPrimitiveInt(int i, {int i3 = 45}) {
  i3 = 4;
}

void dontMarkPositionalPrimitiveInt(int i, [int i4 = 0]) {
  i4 = 4;
}

void dontMarkRequiredPrimitiveDouble(int i, {required double i5}) {
  i5 = 5.0;
}

void dontMarkDefaultPrimitiveDouble(int i, {double i6 = 45.0}) {
  i6 = 6.0;
}

void dontMarkPositionalPrimitiveDouble(int i, [double i7 = 0.0]) {
  i7 = 7.0;
}

void dontMarkRequiredPrimitiveNum(int i, {required num i8}) {
  i8 = 5.0;
}

void dontMarkDefaultPrimitiveNum(int i, {num i9 = 45.0}) {
  i9 = 6.0;
}

void dontMarkPositionalPrimitiveNum(int i, [num i10 = 0.0]) {
  i10 = 7.0;
}

void dontMarkRequiredPrimitiveBool(int i, {required bool bool0}) {
  bool0 = false;
}

void dontMarkDefaultPrimitiveBool(int i, {bool bool1 = true}) {
  bool1 = false;
}

void dontMarkPositionalPrimitiveBool(int i, [bool bool2 = true]) {
  bool2 = false;
}

void dontMarkRequiredPrimitiveString(int i, {required String str0}) {
  str0 = "ay";
}

void dontMarkDefaultPrimitiveString(int i, {String str1 = "abc"}) {
  str1 = "lmao";
}

void dontMarkPositionalPrimitiveString(int i, [String str2 = "xyz"]) {
  str2 = "lol";
}

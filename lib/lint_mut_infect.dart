import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _ExampleLinter();

const String _mutKeyword = "Mut";
const String _buildKeyword = "build";

bool _nameIsMut(Token? t) {
  final tval = t?.lexeme;
  return _nameIsMutStr(tval);
}

bool _nameIsMutStr(String? s) {
  if (s == null) {
    return false;
  }
  return s.endsWith(_mutKeyword);
}

/// A plugin class is used to list all the assists/lints defined by a plugin.
class _ExampleLinter extends PluginBase {
  /// We list all the custom warnings/infos/errors
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        MutInfectLintCode(),
      ];
}

class MutInfectLintCode extends DartLintRule {
  MutInfectLintCode() : super(code: _unmarkedMutInvoked);

  /// Metadata about the warning that will show-up in the IDE.
  /// This is used for `// ignore: code` and enabling/disabling the lint
  static const _unmarkedMutInvoked = LintCode(
    name: 'mut_infect',
    problemMessage: '`Mut` method invoked but not marked `Mut`',
    correctionMessage: 'Add `Mut` to end of method name',
    errorSeverity: ErrorSeverity.WARNING,
  );

  static const _outOfScopeModify = LintCode(
    name: 'mut_out_of_scope',
    problemMessage: 'An out of scope variable is mutated but method is not marked `Mut`',
    correctionMessage: 'Add `Mut` to end of method name',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final mutViolatorVisitor = RecursiveCustomVisitor(
      lintCode: _unmarkedMutInvoked,
      reporter: reporter,
      onViolationFound: (node) {
        reporter.reportErrorForNode(_unmarkedMutInvoked, node);
      },
    );

    context.registry.addMethodDeclaration((methodDecl) {
      mutViolatorVisitor.holderNode = null;
      if (!_nameIsMut(methodDecl.name)) {
        methodDecl.accept(mutViolatorVisitor);
      }
    });
    context.registry.addFunctionDeclaration((functionDecl) {
      mutViolatorVisitor.holderNode = null;
      if (!_nameIsMut(functionDecl.name)) {
        functionDecl.accept(mutViolatorVisitor);
      }
    });
  }

  /// [LintRule]s can optionally specify a list of quick-fixes.
  ///
  /// Fixes will show-up in the IDE when the cursor is above the warning. And it
  /// should contain a message explaining how the warning will be fixed.
  @override
  List<Fix> getFixes() => [_MarkMutFix()];
}

/// We define a quick fix for an issue.
///
/// Our quick fix wants to analyze Dart files, so we subclass [DartFix].
/// Fox quick-fixes on non-Dart files, see [Fix].
class _MarkMutFix extends DartFix {
  /// Similarly to [LintRule.run], [Fix.run] is the core logic of a fix.
  /// It will take care or proposing edits within a file.
  @override
  void run(
    CustomLintResolver resolver,
    // Similar to ErrorReporter, ChangeReporter is an object used for submitting
    // edits within a Dart file.
    ChangeReporter reporter,
    CustomLintContext context,
    // This is the warning that was emitted by our [LintRule] and which we are
    // trying to fix.
    AnalysisError analysisError,
    // This is the other warnings in the same file defined by our [LintRule].
    // Useful in case we want to offer a "fix all" option.
    List<AnalysisError> others,
  ) {
    // Using similar logic as in "PreferFinalProviders", we inspect the Dart file
    // to search for variable declarations.
    context.registry.addMethodDeclaration((node) {
      // We verify that the variable declaration is where our warning is located
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      // We define one edit, giving it a message which will show-up in the IDE.
      final changeBuilder = reporter.createChangeBuilder(
        message: 'Mark method `Mut`',
        // This represents how high-low should this quick-fix show-up in the list
        // of quick-fixes.
        priority: 1,
      );

      // Our edit will consist of editing a Dart file, so we invoke "addDartFileEdit".
      // The changeBuilder variable also has utilities for other types of files.
      changeBuilder.addDartFileEdit((builder) {
        final nodeName = node.name;
        builder.addSimpleInsertion(nodeName.end, 'Mut');
      });
    });
  }
}

class RecursiveCustomVisitor extends RecursiveAstVisitor<void> {
  // 1: Define callback function
  // that contain AST Nodes(NamedExpression, AssignmentExpression,
  // VariableDeclaration, Annotation,...) get from visit function

  final void Function(AstNode node) onViolationFound;

  final LintCode lintCode;
  final ErrorReporter reporter;

  AstNode? holderNode;
  final Set<int> _alreadyConsidered = <int>{};

  // 2: Constructor
  RecursiveCustomVisitor({required this.lintCode, required this.reporter, required this.onViolationFound});

  /// Whether this node should be looked at to consider if it is misnamed
  ///
  /// Only applies to Function or Method Declaration nodes
  ///
  /// Ignores functions whos name is `main`, or anything that `@override`
  bool _shouldConsiderDefinitionNode(AstNode node) {
    if (holderNode == null && node is FunctionDeclaration || node is MethodDeclaration) {
      return !_isExempt(node);
    }
    return false;
  }

  /// Checks whether ths given node is named with Mut, i.e., `_doStuffMut`
  ///
  /// If not marked mut, that is a signal that the parent node should be reported
  bool _isItemMarkedMut(AstNode currentNode, AstNode? containingFunctionNode) {
    if (containingFunctionNode == null) return false;
    if (currentNode is FunctionDeclaration) {
      return _nameIsMut(currentNode.name);
    } else if (currentNode is MethodDeclaration) {
      return _nameIsMut(currentNode.name);
    } else if (currentNode is VariableDeclaration) {
      return _nameIsMut(currentNode.name);
    } else if (currentNode is AssignedVariablePattern) {
      return _nameIsMut(currentNode.name);
    } else if (currentNode is DeclaredIdentifier) {
      return _nameIsMut(currentNode.name);
    } else if (currentNode is DeclaredVariablePattern) {
      return _nameIsMut(currentNode.name);
    } else if (currentNode is MethodInvocation) {
      return _nameIsMut(currentNode.methodName.token);
    } else if (currentNode is SimpleFormalParameter) {
      return _nameIsMut(currentNode.name);
    } else if (currentNode is SimpleIdentifier) {
      return _nameIsMut(currentNode.token);
    } else if (currentNode is SuperFormalParameter) {
      return _nameIsMut(currentNode.name);
    }
    return false;
  }

  void _setUnmarkedMutParentNode(AstNode node) {
    print("[${(node as dynamic).name.lexeme}] Setting current Parent Function Node.");
    holderNode = node;
  }

  void _reportProblem(AstNode node) {
    if (_alreadyConsidered.add(node.hashCode)) {
      print("[${(node as dynamic).name.lexeme}] Reporting an error on this function for Mut violation.");
      onViolationFound(node);
      // reporter.reportErrorForNode(lintCode, node);
    }
    holderNode = null;
  }

  bool _isExempt(AstNode node) {
    bool isExemptElement(Element? e) {
      return (e == null || e.hasOverride);
    }

    bool isExemptElementAnnotation(ElementAnnotation? e) {
      return (e == null || isExemptElement(e.element));
    }

    if (node is FunctionDeclaration) {
      return node.name.lexeme == "main" || node.metadata.any((element) => isExemptElement(element.element) || isExemptElementAnnotation(element.elementAnnotation));
    } else if (node is MethodDeclaration) {
      return node.metadata.any((element) => element.name.name == "override" || isExemptElement(element.element) || isExemptElementAnnotation(element.elementAnnotation));
    } else if (node is FieldDeclaration) {
      return node.metadata.any((element) => element.name.name == "override" || isExemptElement(element.element) || isExemptElementAnnotation(element.elementAnnotation));
    } else if (node is VariableDeclaration) {
      return node.metadata.any((element) => element.name.name == "override" || isExemptElement(element.element) || isExemptElementAnnotation(element.elementAnnotation));
    }
    return false;
  }

  // 3: Override visit function that receives AST Node
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_isItemMarkedMut(node, holderNode)) {
      _reportProblem(holderNode!);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitAssignedVariablePattern(AssignedVariablePattern node) {
    if (_isItemMarkedMut(node, holderNode)) {
      _reportProblem(holderNode!);
    }
    final ne = node.element;
    super.visitAssignedVariablePattern(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    if (_isItemMarkedMut(node, holderNode)) {
      _reportProblem(holderNode!);
    }
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    if (_isItemMarkedMut(node, holderNode)) {
      _reportProblem(holderNode!);
    }
    super.visitDeclaredVariablePattern(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (holderNode == null) {
      if (_shouldConsiderDefinitionNode(node)) {
        holderNode = node;
      }
    }

    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (holderNode == null) {
      if (_shouldConsiderDefinitionNode(node)) {
        holderNode = node;
      }
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    if (_isItemMarkedMut(node, holderNode)) {
      _reportProblem(holderNode!);
    }
    super.visitFunctionTypeAlias(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isItemMarkedMut(node, holderNode)) {
      _reportProblem(holderNode!);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    if (_isItemMarkedMut(node, holderNode)) {
      _reportProblem(holderNode!);
    }
    super.visitSimpleFormalParameter(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_isItemMarkedMut(node, holderNode)) {
      _reportProblem(holderNode!);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    if (_isItemMarkedMut(node, holderNode)) {
      _reportProblem(holderNode!);
    }
    super.visitSuperFormalParameter(node);
  }
}

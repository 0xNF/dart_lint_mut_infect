import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _ExampleLinter();

const String _mutKeyword = "Mut";

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

// /// Checks whether ths given node is named with Mut, i.e., `_doStuffMut`
// ///
// /// If not marked mut, that is a signal that the parent node should be reported
bool nodeIsMarkedMut(AstNode? node) {
  if (node == null) return false;
  final t = extractNameFromNode(node);
  return _nameIsMut(t);
}

/// Primitive Types: `[int, double, num, bool, string]`, etc can't be mutated when passed as a Parameter, so ignore functions that mutate ints in their arg list
bool isDartPrimitive(AstNode node) {
  DartType? dt;
  if (node is Expression) {
    dt = node.staticType;
  } else if (node is SimpleFormalParameter) {
    dt = node.type?.type;
  } else if (node is FormalParameter) {
    dt = node.declaredElement?.type;
  } else if (node is CatchClauseParameter) {
    dt = node.declaredElement?.type;
  } else if (node is VariableDeclaration) {
    dt = node.declaredElement?.type;
  } else if (node is DeclaredIdentifier) {
    dt = node.type?.type ?? node.declaredElement?.type;
  } else if (node is DeclaredVariablePattern) {
    dt = node.type?.type ?? node.declaredElement?.type;
  } else if (node is FieldDeclaration) {
    dt = null;
  } else if (node is FieldFormalParameter) {
    dt = node.type?.type ?? node.declaredElement?.type;
  } else if (node is TypeParameter) {
    dt = null;
  } else if (node is DefaultFormalParameter) {
    dt = node.declaredElement?.type;
  } else if (node is SimpleFormalParameter) {
    dt = node.type?.type ?? node.declaredElement?.type;
  } else if (node is SuperFormalParameterElement) {
    dt = null;
  } else if (node is NormalFormalParameter) {
    dt = node.declaredElement?.type;
  } else if (node is SuperFormalParameter) {
    dt = node.type?.type ?? node.declaredElement?.type;
  } else if (node is FieldFormalParameter) {
    dt = node.type?.type ?? node.declaredElement?.type;
  } else if (node is CatchClauseParameter) {
    dt = node.declaredElement?.type;
  } else if (node is FormalParameter) {
    dt = node.declaredElement?.type;
  }

  if (dt == null) {
    return false;
  }
  if (dt.isDartCoreString | dt.isDartCoreBool || dt.isDartCoreDouble || dt.isDartCoreInt || dt.isDartCoreNum) {
    return true;
  }
  return false;
}

class MutDiagnostic extends DiagnosticMessage {
  @override
  String get filePath => _filePath;
  final String _filePath;

  @override
  int get length => _length;
  final int _length;

  @override
  String messageText({required bool includeUrl}) {
    return "lmao some extra data idk";
  }

  @override
  int get offset => _offset;
  final int _offset;

  @override
  String? get url => _url;
  final String? _url;

  MutDiagnostic._({required String filePath, required int length, required int offset, String? url})
      : _filePath = filePath,
        _offset = offset,
        _url = url,
        _length = length;
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
  MutInfectLintCode() : super(code: unmarkedMutInvoked);

  /// Metadata about the warning that will show-up in the IDE.
  /// This is used for `// ignore: code` and enabling/disabling the lint
  static const unmarkedMutInvoked = LintCode(
    name: 'mut_infect',
    problemMessage: '`Mut` method invoked but not marked `Mut`',
    correctionMessage: 'Add `Mut` to end of method name',
    errorSeverity: ErrorSeverity.WARNING,
  );

  static const outOfScopeMutate = LintCode(
    name: 'mut_out_of_scope',
    problemMessage: 'An non-local variable is mutated but method is not marked `Mut`',
    correctionMessage: 'Add `Mut` to end of method name',
    errorSeverity: ErrorSeverity.WARNING,
  );

  static const unmarkedMutParameter = LintCode(
    name: 'mut_param',
    problemMessage: 'Method parameter is mutated by method, but not marked `Mut`',
    correctionMessage: 'Add `Mut` to end of parameter name',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final mutViolatorVisitor = RecurseCustom2(reporter: reporter);

    context.registry.addMethodDeclaration((methodDecl) {
      methodDecl.accept(mutViolatorVisitor);
    });
    context.registry.addFunctionDeclaration((functionDecl) {
      functionDecl.accept(mutViolatorVisitor);
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

// /// Checks if a node is exempt from being required to be named `Mut`
bool isExemptForMutInfect(AstNode node) {
  if (node is FunctionDeclaration) {
    /* Functions marked @override are exempt */
    if (node.metadata.any((metadata) => metadata.name.name == "override")) {
      return true;
    }
    /* Functions named 'main' are exempt */
    if (node.name.lexeme == "main") {
      return true;
    }
    /* Functions ending in 'Mut' are exempt */
    if (node.name.lexeme.endsWith(_mutKeyword)) {
      return true;
    }
    /* Setters are exempt */
    if (node.isSetter) {
      return true;
    }
  } else if (node is MethodDeclaration) {
    /* Methods marked @override are exempt */
    if (node.metadata.any((metadata) => metadata.name.name == "override")) {
      return true;
    }
    /* Functions ending in 'Mut' are exempt */
    if (node.name.lexeme.endsWith(_mutKeyword)) {
      return true;
    }
    /* Setters are exempt */
    if (node.isSetter) {
      return true;
    }
  } else if (node is VariableDeclaration) {
    /* Methods marked @override are exempt */
    if (node.metadata.any((metadata) => metadata.name.name == "override")) {
      return true;
    }
    /* Functions ending in 'Mut' are exempt */
    if (node.name.lexeme.endsWith(_mutKeyword)) {
      return true;
    }
  }
  return false;
}

Token? extractNameFromNode(AstNode? node) {
  if (node is FunctionDeclaration) {
    return node.name;
  } else if (node is MethodDeclaration) {
    return node.name;
  } else if (node is VariableDeclaration) {
    return node.name;
  } else if (node is DeclaredIdentifier) {
    return node.name;
  } else if (node is DeclaredVariablePattern) {
    return node.name;
  } else if (node is EnumDeclaration) {
    return node.name;
  } else if (node is ClassDeclaration) {
    return node.name;
  } else if (node is FieldDeclaration) {
    return node.endToken;
  } else if (node is FieldFormalParameter) {
    return node.name;
  } else if (node is TypeParameter) {
    return node.name;
  } else if (node is DefaultFormalParameter) {
    return node.name;
  } else if (node is SimpleFormalParameter) {
    return node.name;
  } else if (node is SuperFormalParameterElement) {
    return node?.endToken;
  } else if (node is NormalFormalParameter) {
    return node.name;
  } else if (node is SuperFormalParameter) {
    return node.name;
  } else if (node is FieldFormalParameter) {
    return node.name;
  } else if (node is CatchClauseParameter) {
    return node.name;
  } else if (node is FormalParameter) {
    return node.name;
  } else if (node is MethodInvocation) {
    return node.methodName.token;
  } else if (node is FunctionExpressionInvocation) {
    return null;
    // node.
    // node.function.
  }
  return null;
}

class TokenType {
  final Token token;
  final bool isPrimitive;

  const TokenType({required this.token, required this.isPrimitive});
}

/// For keeping track of local variables so we don't incorrectly mark inner functions as requiring Mut
class Scope {
  final Token? scopeName;
  final Map<String, TokenType> declaredVariables = <String, TokenType>{};
  final Map<String, TokenType> parameterVariables = <String, TokenType>{};
  final Set<Scope> innerScopes = <Scope>{};
  final AstNode? scopeSource;

  final Scope? parentScope;

  bool get isRootScope => scopeName == null;

  Scope({required this.scopeName, required this.scopeSource, required this.parentScope});

  TokenType? isDefinedAsParameter(String lexeme) {
    return parameterVariables[lexeme];
  }

  TokenType? isDefinedAsLocal(String lexeme) {
    return declaredVariables[lexeme];
  }

  void addInnerScope(Scope s) {
    innerScopes.add(s);
  }

  void addDeclaredLocal(Token t, bool isPrimitive) {
    declaredVariables[t.lexeme] = TokenType(token: t, isPrimitive: isPrimitive);
  }

  void addDeclaredParameter(Token t, bool isPrimitive) {
    parameterVariables[t.lexeme] = TokenType(token: t, isPrimitive: isPrimitive);
  }

  bool crawlContains(String lexeme) {
    if (isDefinedAsLocal(lexeme) != null) {
      return true;
    } else if (parentScope != null && !parentScope!.isRootScope) {
      return parentScope!.crawlContains(lexeme);
    }
    return false;
  }

  /// We don't care if a strictly local function call is mutating strictly local variables
  bool belongsToNonRootParent(AstNode? node) {
    if (node == null) {
      return false;
    }
    if (isRootScope || (parentScope?.isRootScope ?? false)) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode => scopeName.hashCode;

  @override
  bool operator ==(Object other) {
    return other is Scope && other.scopeName == scopeName;
  }
}

class RecurseCustom2 extends RecursiveAstVisitor<void> {
  final ErrorReporter reporter;

  final List<String> currentPath = [];
  String get _path => currentPath.join('/');

  final Map<String, Scope> scopesAtPath = <String, Scope>{
    "": Scope(scopeName: null, scopeSource: null, parentScope: null),
  };

  final Set<int> alreadyConsideredNode = <int>{};
  final Set<int> alreadyConsideredForMutParam = <int>{};
  final Set<int> alreadyConsideredForMutInfect = <int>{};
  final Set<int> alreadyConsideredForMutOutOfScope = <int>{};

  RecurseCustom2({required this.reporter});

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      /* push path */
      currentPath.add("FunctionDeclaration(${node.name.lexeme})");

      /* Scope work */
      var thisScope = Scope(scopeName: node.name, scopeSource: node, parentScope: parentScope);
      scopesAtPath[_path] = thisScope;
      parentScope.addInnerScope(thisScope);

      super.visitFunctionDeclaration(node);

      /* cleanup path */
      currentPath.removeLast();
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      /* push path */
      currentPath.add("MethodDeclaration(${node.name.lexeme})");

      /* Scope work */
      var thisScope = Scope(scopeName: node.name, scopeSource: node, parentScope: parentScope);
      scopesAtPath[_path] = thisScope;
      parentScope.addInnerScope(thisScope);

      super.visitMethodDeclaration(node);

      /* cleanup path */
      currentPath.removeLast();
    }
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      parentScope.addDeclaredLocal(node.name, isDartPrimitive(node));

      super.visitVariableDeclaration(node);
    }
  }

  @override
  void visitAssignedVariablePattern(AssignedVariablePattern node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      super.visitAssignedVariablePattern(node);
    }
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      final targetName = node.leftHandSide.beginToken.lexeme;

      var parentScope = scopesAtPath[_path]!;
      final definedParam = parentScope.isDefinedAsParameter(targetName);
      final definedLocal = parentScope.isDefinedAsLocal(targetName);
      if (definedParam != null) {
        /* check name */
        if (!_nameIsMut(definedParam.token) && !definedParam.isPrimitive && node.leftHandSide.childEntities.length > 1) {
          if (alreadyConsideredForMutParam.add(definedParam.token.hashCode)) {
            reporter.reportErrorForToken(MutInfectLintCode.unmarkedMutParameter, definedParam.token);
          }
        }
      } else if (definedLocal == null) {
        if (!parentScope.crawlContains(targetName)) {
          if (!nodeIsMarkedMut(parentScope.scopeSource) && !isExemptForMutInfect(parentScope.scopeSource!) && !isCascadeParentDeclaration(node)) {
            if (alreadyConsideredForMutOutOfScope.add(parentScope.scopeSource.hashCode)) {
              reporter.reportErrorForToken(MutInfectLintCode.outOfScopeMutate, extractNameFromNode(parentScope.scopeSource)!);
            }
          }
        }
      }

      super.visitAssignmentExpression(node);
    }
  }

  bool isCascadeParentDeclaration(AstNode? node) {
    AstNode? current = node;
    while (current != null) {
      if (current is VariableDeclaration) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  @override
  void visitCascadeExpression(CascadeExpression node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      final targetName = node.target.beginToken.lexeme;

      var parentScope = scopesAtPath[_path]!;

      final definedParam = parentScope.isDefinedAsParameter(targetName);
      final definedLocal = parentScope.isDefinedAsLocal(targetName);

      if (definedParam != null) {
        if (!_nameIsMut(definedParam.token) && !definedParam.isPrimitive && node.childEntities.length > 1) {
          if (alreadyConsideredForMutParam.add(definedParam.token.hashCode)) {
            reporter.reportErrorForToken(MutInfectLintCode.unmarkedMutParameter, definedParam.token);
          }
        }
      } else if (definedLocal == null) {
        if (!parentScope.crawlContains(targetName)) {
          if (!nodeIsMarkedMut(parentScope.scopeSource) && !isExemptForMutInfect(parentScope.scopeSource!) && !isCascadeParentDeclaration(node)) {
            if (alreadyConsideredForMutOutOfScope.add(parentScope.scopeSource.hashCode)) {
              reporter.reportErrorForToken(MutInfectLintCode.outOfScopeMutate, extractNameFromNode(parentScope.scopeSource)!);
            }
          }
        }
      }
      super.visitCascadeExpression(node);
    }
  }

  @override
  void visitPatternAssignment(PatternAssignment node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      super.visitPatternAssignment(node);
    }
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    print(node);
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      parentScope.addDeclaredParameter(node.name, isDartPrimitive(node));

      super.visitDeclaredIdentifier(node);
    }
  }

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      parentScope.addDeclaredParameter(node.name, isDartPrimitive(node));

      super.visitDeclaredVariablePattern(node);
    }
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      super.visitFunctionExpression(node);
    }
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      super.visitFunctionTypeAlias(node);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      if (nodeIsMarkedMut(node) && !nodeIsMarkedMut(parentScope.scopeSource)) {
        if (alreadyConsideredForMutInfect.add(parentScope.scopeSource.hashCode)) {
          reporter.reportErrorForToken(MutInfectLintCode.unmarkedMutInvoked, parentScope.scopeName!);
        }
      }

      super.visitMethodInvocation(node);
    }
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;
      if (nodeIsMarkedMut(node) && !nodeIsMarkedMut(parentScope.scopeSource)) {
        if (alreadyConsideredForMutInfect.add(parentScope.scopeSource.hashCode)) {
          reporter.reportErrorForToken(MutInfectLintCode.unmarkedMutInvoked, parentScope.scopeName!);
        }
      }

      super.visitFunctionExpressionInvocation(node);
    }
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      if (node.name != null) {
        parentScope.addDeclaredParameter(node.name!, isDartPrimitive(node));
      }

      super.visitSimpleFormalParameter(node);
    }
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      super.visitSimpleIdentifier(node);
    }
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    if (alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = scopesAtPath[_path]!;

      parentScope.addDeclaredParameter(node.name, isDartPrimitive(node));

      super.visitSuperFormalParameter(node);
    }
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Creates the Linter object. Not intended to be instantiated directly by a user.
PluginBase createPlugin() => _MutLinter();

/// "Mut"
const String _mutKeyword = "Mut";

/// "override"
const String _overrideKeyword = "override";

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

bool _nameIsMaybeMutable(String? s) {
  if (s == null) {
    return false;
  }
  const heuristics = <String>[
    'create',
    'update',
    'delete',
    'edit',
    'setState',
    'add',
    'clear',
    'remove',
    'insert',
  ];
  return heuristics.any((element) => s.startsWith(element));
}

// /// Checks whether ths given node is named with Mut, i.e., `_doStuffMut`
// ///
// /// If not marked mut, that is a signal that the parent node should be reported
bool _nodeIsMarkedMut(AstNode? node) {
  if (node == null) return false;
  final t = _extractNameFromNode(node);
  return _nameIsMut(t);
}

/// Primitive Types: `[int, double, num, bool, string]`, etc can't be mutated when passed as a Parameter, so ignore functions that mutate ints in their arg list
bool _isDartPrimitive(AstNode node) {
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

/// A plugin class is used to list all the assists/lints defined by a plugin.
class _MutLinter extends PluginBase {
  /// We list all the custom warnings/infos/errors
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        _MutInfectLintCode(),
      ];
}

class _MutInfectLintCode extends DartLintRule {
  _MutInfectLintCode() : super(code: unmarkedMutInvoked);

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

  static const unnecessaryMutInfect = LintCode(
    name: 'unnecessary_mut_infect',
    problemMessage: 'This method is marked as `Mut` but it doesn\'t contain any mutating functionality',
    correctionMessage: 'Remove `Mut` from the end of this method name',
    errorSeverity: ErrorSeverity.WARNING,
  );

  // static const unnecessaryMutParam = LintCode(
  //   name: 'unnecessary_mut_param',
  //   problemMessage: 'This parameter is marked as `Mut` but isn\'t mutated by anything in the containing scope',
  //   correctionMessage: 'Remove `Mut` from the end of this parameter name',
  //   errorSeverity: ErrorSeverity.WARNING,
  // );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final mutViolatorVisitor = _LintMutVisitor(reporter: reporter);

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
bool _isExemptForMutInfect(AstNode? node) {
  if (node == null) {
    return true;
  } else if (node is FunctionDeclaration) {
    /* Functions marked @override are exempt */
    if (node.metadata.any((metadata) => metadata.name.name == _overrideKeyword)) {
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
    if (node.metadata.any((metadata) => metadata.name.name == _overrideKeyword)) {
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
    /* Operators are exempt */
    if (node.isOperator) {
      return true;
    }
  } else if (node is VariableDeclaration) {
    /* Methods marked @override are exempt */
    if (node.metadata.any((metadata) => metadata.name.name == _overrideKeyword)) {
      return true;
    }
    /* Functions ending in 'Mut' are exempt */
    if (node.name.lexeme.endsWith(_mutKeyword)) {
      return true;
    }
  }
  return false;
}

Token? _extractNameFromNode(AstNode? node) {
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

class _LintedToken {
  /// Underlying AST Token this token represents
  final Token token;

  /// Whether this token is a Dart Primitive type
  final bool isPrimitive;

  /// Whether this token is suffixed with `Mut`
  bool get isNameMut => _nameIsMut(token);

  /// Whether this token should be marked as mut, regardless of whether its named Mut or not
  bool shouldBeMut = false;

  _LintedToken({required this.token, required this.isPrimitive});
}

/// For keeping track of local variables so we don't incorrectly mark inner functions as requiring Mut
class _Scope {
  final Token? _scopeName;
  final Map<String, _LintedToken> _declaredVariables = <String, _LintedToken>{};
  final Map<String, _LintedToken> _parameterVariables = <String, _LintedToken>{};
  final Set<String> _invocations = <String>{};
  final Set<_Scope> _innerScopes = <_Scope>{};
  final AstNode? _scopeSource;

  bool _shouldBeMut = false;

  final _Scope? _parentScope;

  bool get isRootScope => _scopeName == null;

  _Scope({required Token? scopeName, required AstNode? scopeSource, required _Scope? parentScope})
      : _parentScope = parentScope,
        _scopeSource = scopeSource,
        _scopeName = scopeName;

  /// Whether this scope contains any correct Mut entries
  bool containsAnyMut() {
    if (_shouldBeMut) {
      return true;
    }
    for (final variable in _declaredVariables.entries) {
      if (variable.value.shouldBeMut) {
        return true;
      }
    }
    for (final param in _parameterVariables.entries) {
      if (param.value.shouldBeMut) {
        return true;
      }
    }
    if (_invocations.any((element) => _nameIsMutStr(element) || _nameIsMaybeMutable(element))) {
      return true;
    }
    if (_innerScopes.isEmpty) {
      return false;
    } else {
      for (final innerScope in _innerScopes) {
        if (_nodeIsMarkedMut(innerScope._scopeSource) || innerScope.containsAnyMut()) {
          return true;
        }
      }
    }
    return false;
  }

  /// Returns a non-null [_LintedToken] if the given lexeme exists as a passed-in Parameter to this Scope
  _LintedToken? isDefinedAsParameter(String lexeme) {
    return _parameterVariables[lexeme];
  }

  /// Returns a non-null [_LintedToken] if the given lexeme exists as a declared Variable in this Scope
  _LintedToken? isDefinedAsLocal(String lexeme) {
    return _declaredVariables[lexeme];
  }

  /// Adds the given lexeme as an invoked element of this Scope
  void addInvocation(String s) {
    _invocations.add(s);
  }

  /// Adds the given Scope as a child Scope
  void addInnerScope(_Scope s) {
    _innerScopes.add(s);
  }

  /// Adds the given token to this Scope's list of declared variables
  void addDeclaredLocal(Token t, bool isPrimitive) {
    _declaredVariables[t.lexeme] = _LintedToken(token: t, isPrimitive: isPrimitive);
  }

  /// Adds the goven token to this Scope's list of declared parameters
  void addDeclaredParameter(Token t, bool isPrimitive) {
    _parameterVariables[t.lexeme] = _LintedToken(token: t, isPrimitive: isPrimitive);
  }

  /// Returns `true` if a token with the given `lexeme` is present in any of the lexical parent scopes
  bool crawlContains(String lexeme) {
    if (isDefinedAsLocal(lexeme) != null) {
      return true;
    } else if (_parentScope != null && !_parentScope!.isRootScope) {
      return _parentScope!.crawlContains(lexeme);
    }
    return false;
  }

  /// We don't care if a strictly local function call is mutating strictly local variables
  bool belongsToNonRootParent(AstNode? node) {
    if (node == null) {
      return false;
    }
    if (isRootScope || (_parentScope?.isRootScope ?? false)) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode => _scopeName.hashCode;

  @override
  bool operator ==(Object other) {
    return other is _Scope && other._scopeName == _scopeName;
  }
}

class _LintMutVisitor extends RecursiveAstVisitor<void> {
  final ErrorReporter reporter;

  final List<String> _currentPath = [];
  String get _path => _currentPath.join('/');

  final Map<String, _Scope> _scopesAtPath = <String, _Scope>{
    "": _Scope(scopeName: null, scopeSource: null, parentScope: null),
  };

  final Set<int> _alreadyConsideredNode = <int>{};
  final Set<int> _alreadyConsideredForMutParam = <int>{};
  final Set<int> _alreadyConsideredForMutInfect = <int>{};
  final Set<int> _alreadyConsideredForMutOutOfScope = <int>{};

  _LintMutVisitor({required this.reporter});

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = _scopesAtPath[_path]!;

      /* push path */
      _currentPath.add("FunctionDeclaration(${node.name.lexeme})");

      /* Scope work */
      var thisScope = _Scope(scopeName: node.name, scopeSource: node, parentScope: parentScope);
      _scopesAtPath[_path] = thisScope;
      parentScope.addInnerScope(thisScope);

      super.visitFunctionDeclaration(node);

      if (_nodeIsMarkedMut(thisScope._scopeSource) && !thisScope.containsAnyMut()) {
        reporter.reportErrorForToken(_MutInfectLintCode.unnecessaryMutInfect, _extractNameFromNode(thisScope._scopeSource)!);
      }

      /* cleanup path */
      _currentPath.removeLast();
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = _scopesAtPath[_path]!;

      /* push path */
      _currentPath.add("MethodDeclaration(${node.name.lexeme})");

      /* Scope work */
      var thisScope = _Scope(scopeName: node.name, scopeSource: node, parentScope: parentScope);
      _scopesAtPath[_path] = thisScope;
      parentScope.addInnerScope(thisScope);

      super.visitMethodDeclaration(node);

      if (_nodeIsMarkedMut(thisScope._scopeSource) && !thisScope.containsAnyMut()) {
        reporter.reportErrorForToken(_MutInfectLintCode.unnecessaryMutInfect, _extractNameFromNode(thisScope._scopeSource)!);
      }

      /* cleanup path */
      _currentPath.removeLast();
    }
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = _scopesAtPath[_path]!;

      parentScope.addDeclaredLocal(node.name, _isDartPrimitive(node));

      super.visitVariableDeclaration(node);
    }
  }

  @override
  void visitAssignedVariablePattern(AssignedVariablePattern node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      // var parentScope = scopesAtPath[_path]!;

      super.visitAssignedVariablePattern(node);
    }
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      final targetName = node.leftHandSide.beginToken.lexeme;

      var parentScope = _scopesAtPath[_path]!;
      final definedParam = parentScope.isDefinedAsParameter(targetName);
      final definedLocal = parentScope.isDefinedAsLocal(targetName);
      if (definedParam != null) {
        /* check name */
        if (!_nameIsMut(definedParam.token) && !definedParam.isPrimitive && node.leftHandSide.childEntities.length > 1) {
          if (_alreadyConsideredForMutParam.add(definedParam.token.hashCode)) {
            definedParam.shouldBeMut = true;
            reporter.reportErrorForToken(_MutInfectLintCode.unmarkedMutParameter, definedParam.token);
          }
        }
        definedParam.shouldBeMut = true;
      } else if (definedLocal == null) {
        if (!parentScope.crawlContains(targetName)) {
          final isMarkedMut = _nodeIsMarkedMut(parentScope._scopeSource);
          if (!isMarkedMut) {
            if (!_isExemptForMutInfect(parentScope._scopeSource) && !isCascadeExempt(node)) {
              if (_alreadyConsideredForMutOutOfScope.add(parentScope._scopeSource.hashCode)) {
                parentScope._shouldBeMut = true;
                reporter.reportErrorForToken(_MutInfectLintCode.outOfScopeMutate, _extractNameFromNode(parentScope._scopeSource)!);
              }
            }
          }
        }
        parentScope._shouldBeMut = true;
      } else if (_nameIsMut(definedLocal.token)) {
        definedLocal.shouldBeMut = true;
      }

      super.visitAssignmentExpression(node);
    }
  }

  @override
  void visitCascadeExpression(CascadeExpression node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      final targetName = node.target.beginToken.lexeme;

      var parentScope = _scopesAtPath[_path]!;

      final definedParam = parentScope.isDefinedAsParameter(targetName);
      final definedLocal = parentScope.isDefinedAsLocal(targetName);

      if (definedParam != null) {
        if (!_nameIsMut(definedParam.token) && !definedParam.isPrimitive && node.childEntities.length > 1) {
          if (_alreadyConsideredForMutParam.add(definedParam.token.hashCode)) {
            definedParam.shouldBeMut = true;
            reporter.reportErrorForToken(_MutInfectLintCode.unmarkedMutParameter, definedParam.token);
          }
        }
      } else if (definedLocal == null) {
        /* check name */
        if (!parentScope.crawlContains(targetName)) {
          if (!_nodeIsMarkedMut(parentScope._scopeSource) && !_isExemptForMutInfect(parentScope._scopeSource!) && !isCascadeExempt(node)) {
            if (_alreadyConsideredForMutOutOfScope.add(parentScope._scopeSource.hashCode)) {
              parentScope._shouldBeMut = true;
              reporter.reportErrorForToken(_MutInfectLintCode.outOfScopeMutate, _extractNameFromNode(parentScope._scopeSource)!);
            }
          }
        }
        parentScope._shouldBeMut = true;
      } else if (_nameIsMut(definedLocal.token)) {
        definedLocal.shouldBeMut = true;
      }
      super.visitCascadeExpression(node);
    }
  }

  @override
  void visitPatternAssignment(PatternAssignment node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      // var parentScope = scopesAtPath[_path]!;

      super.visitPatternAssignment(node);
    }
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    print(node);
    if (_alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = _scopesAtPath[_path]!;

      parentScope.addDeclaredParameter(node.name, _isDartPrimitive(node));

      super.visitDeclaredIdentifier(node);
    }
  }

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = _scopesAtPath[_path]!;

      parentScope.addDeclaredParameter(node.name, _isDartPrimitive(node));

      super.visitDeclaredVariablePattern(node);
    }
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      // var parentScope = scopesAtPath[_path]!;

      super.visitFunctionExpression(node);
    }
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      // var parentScope = scopesAtPath[_path]!;

      super.visitFunctionTypeAlias(node);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = _scopesAtPath[_path]!;

      parentScope.addInvocation(_extractNameFromNode(node)?.lexeme ?? '');

      if (_nodeIsMarkedMut(node) && !_nodeIsMarkedMut(parentScope._scopeSource) && !_isExemptForMutInfect(parentScope._scopeSource)) {
        if (_alreadyConsideredForMutInfect.add(parentScope._scopeSource.hashCode)) {
          parentScope._shouldBeMut = true;
          reporter.reportErrorForToken(_MutInfectLintCode.unmarkedMutInvoked, parentScope._scopeName!);
        }
      }

      super.visitMethodInvocation(node);
    }
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = _scopesAtPath[_path]!;

      parentScope.addInvocation(_extractNameFromNode(node)?.lexeme ?? '');

      if (_nodeIsMarkedMut(node) && !_nodeIsMarkedMut(parentScope._scopeSource) && !_isExemptForMutInfect(parentScope._scopeSource)) {
        if (_alreadyConsideredForMutInfect.add(parentScope._scopeSource.hashCode)) {
          reporter.reportErrorForToken(_MutInfectLintCode.unmarkedMutInvoked, parentScope._scopeName!);
        }
      }

      super.visitFunctionExpressionInvocation(node);
    }
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = _scopesAtPath[_path]!;

      if (node.name != null) {
        parentScope.addDeclaredParameter(node.name!, _isDartPrimitive(node));
      }

      super.visitSimpleFormalParameter(node);
    }
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      // var parentScope = scopesAtPath[_path]!;

      super.visitSimpleIdentifier(node);
    }
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    if (_alreadyConsideredNode.add(node.hashCode)) {
      var parentScope = _scopesAtPath[_path]!;

      parentScope.addDeclaredParameter(node.name, _isDartPrimitive(node));

      super.visitSuperFormalParameter(node);
    }
  }

  bool isCascadeExempt(AstNode? node) {
    AstNode? current = node;
    while (current != null) {
      if (current is CascadeExpression && current.target is InstanceCreationExpression) {
        return true;
      }
      if (current is InstanceCreationExpression) {
        return true;
      }
      if (current is VariableDeclaration) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

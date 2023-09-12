A Dart linter enforcing certain naming conventions when dealing with methods that mutate variables.

There are 4 lints included in this package:

1. [mut_infect](#mut_infect)  
    ```dart
    void callAMut() {
        /* Calling a `mut` method should mark the caller as `Mut` */
        callBMut();
    }
    ```
1. [mut_out_of_scope](#mut_out_of_scope)
    ```dart
    void assignGlobalMut() {
        /* Assigning to a variable not owned by this scope should mark the caller as `Mut` */
        globalVar = 3;
    }
    ```
1. [mut_param](#mut_param)
    ```dart
    void changeIncomingParamterValue(AnObject aoMut) {
        /* Changing the parameter's properties should mark the parameter as `Mut` */
        aoMut.innerField = "hi";
    }
    ```
1. [unnecessary_mut_infect](#unnecessary_mut_infect)
    ```dart
    void funcDoesNotMut() {
        /* this function should not be marked with `Mut` */
    }
    ```


## Getting Started
Taken from [custom_lint](https://pub.dev/packages/custom_lint#enablingdisabling-and-configuring-lint):
* The application must contain an `analysis_options.yaml` with the following
```yaml
analyzer:
  plugins:
    - custom_lint
```
* The application also needs to add custom_lint and our package(s) as dev dependency in their application:
```yaml
# The pubspec.yaml of an application using our lints
name: example_app
environment:
  sdk: ">=2.16.0 <3.0.0"

dev_dependencies:
  custom_lint:
  lint_mut_infect:
```

### Disabling a lint
If you want to disable certain lints, add the following to the `analysis_options.yaml` file:
```yaml
lint_mut_infect:
  rules:
    - unnecessary_mut_infect: false # disable this rule
```

All rules are enabled by default.

# Lints
## mut_infect

Produces: Warning

Enforces infectious naming conventions on Method and Function declarations.   
Something that invokes a `Mut` element should also be called `Mut`.  


![Code demonstrating the `Mut Infect lint`, where a method that should be marked with Mut because it calls a method marked Mut](https://github.com/0xNF/dart_lint_mut_infect/blob/master/doc/readme/lint_mut_infect.png?raw=true)

This produces the following message: `'Mut' method invoked but not marked 'Mut'`

The suggested fix is to rename the calling function:

```dart
function markThisDummyMut() {
    dummyMut();
}
```

This way you can establish a chain of all functions that mutate variables.

### Exemptions
This lint is not applied when the element is:
1. Marked with `@override`
1. functions named `main`
1. A `setter`

## mut_out_of_scope
Produces: Warning

This lint checks that variables that are modified within a function are declared within that function, or are contained entirely within the lexical scope of the function in question. For instance:

![Code demonstrating the `Mut Out of Scope` lint, where a method is modifying a variable not declared in the lexical scope](https://github.com/0xNF/dart_lint_mut_infect/blob/master/doc/readme/lint_mut_out_of_scope.png?raw=true)

In this example, `globalScopeVar` is not declared within the `outOfScopeModifier` function, but is modified anyway. This produces a warning that the function should be marked with `Mut`.

This lint also understands locally defined functions, and won't cause undue warnings for strictly-local declarations:

![Code demonstrating that `Mut Out of Scope` doesn't apply to variables that have a perfectly captured lexical scope chain](https://github.com/0xNF/dart_lint_mut_infect/blob/master/doc/readme/lint_inner_funtions_not_included.png?raw=true)

In the above image, although `i` is modified by `inner()` , inner will not be marked as requiring Mut, because all declarations are local to the lexical scope of the top-level containing function.  

### Exemptions
This lint is not applied when the element is:
1. Marked with `@override`
1. functions named `main`
1. A `setter`

## mut_param
Produces: Error

This lint checks that any variable that is passed a parameter and is modified by the function is marked with `Mut`.   
This lint is stronger than the others because it is very important for a caller to know whether some object of theirs is going to be modified or not.

![Code demonstrating the `Mut Param` lint, where a parameter passed to the function is modified inside the function](https://github.com/0xNF/dart_lint_mut_infect/blob/master/doc/readme/lint_mut_unmarked_param.png?raw=true)



### Exemptions

* Parameters with Dart primitive types are exempt because they are passed-by-value. These include:
    - bool
    - int
    - double
    - num
    - String

* Simply reassigning the variable is exempt as well:
    ```dart
    void reassignment(AnObject ao) {
        ao = AnObject();
    }
    ```

## unnecessary_mut_infect
Produces: Warning

This lint checks that any functions or methods named `Mut` actually deserve to be marked. This lint can help keep refactors to your codebase from spiraling out of control with Muts everywhere. 

![Code demonstrating the `unnecessary_mut_infect` lint, where a function as been marked Mut that doesnt need it](https://github.com/0xNF/dart_lint_mut_infect/blob/master/doc/readme/lint_unnecessary_mut.png?raw=true)

### n.b.
Because this package isn't always aware of what constitutes mutating functionality or not, you should tell the the analyzer to ignore this lint when you need to.

For example:

```dart
// ignore: unnecessary_mut_infect
void reallyIsMut() {
    someCallYouCantRenameButIsDefinitelyAMutatingCall();
}
```


# Exemptions

Any function or method marked `@override`, or any function named `main` will not be flagged.  
This means you wont be overloaded with warnings when dealing with names you don't control.

# Limitations
This package doesn't integrate with `dart fix`, as we can't reliably get all symbol references for renaming. You are encouraged to use `F2` rename functionality on your own to add or remove `Mut` as appropriate. 



# Known Bugs
[#1](https://github.com/0xNF/dart_lint_mut_infect/issues/1)
Some functions with inner scope `Mut` calls mutating a variable owned entirely by the calling scope still require their parent scope to be marked as `Mut`, even though they're mutating fully-owned local variables.

# Debugging
To debug,

follow the steps at https://pub.dev/packages/custom_lint

1. Add `custom_lint` and `dart_lint_infect_mut` to Dev Dependencies of target project
2. Run `custom_lint --watch`
3. [Optional] add the dart_lint repo to the Workspace and set breakpoints within  


# Contributing to this plugin
This plugin uses the  [custom_lint](https://pub.dev/packages/custom_lint) package. To help with the underlying functionality, consider helping out that repo. To contribute to this repo specifically, visit https://github.com/0xNF/dart_lint_mut_infect
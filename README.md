# Overview
This linter enforces certain naming conventions when dealing with methods that mutate variables:

## infect_mut
Enforces infectious naming conventions on Method and Function declarations:

```dart
function someFunction() {
    setSomethingMut();
}

function setSomethingMut() {
    // omitted
}
```

This produces the following message: `'Mut' method invoked but not marked 'Mut'`

The suggested fix is to rename the calling function:

```dart
function someFunctionMut() {
    setSomethingMut();
}

function setSomethingMut() {
    // omitted
}
```

This way you can establish a chain of all functions that mutate variables.


## unlabled_mut
Detects variables being assigned that were not declared in scope, and marks those methods as requiring the `Mut` marker

# Exemptions

Any function or method marked `@override`, or any function named `main` will not be flagged.  
This means you wont be overloaded with warnings when dealing with names you don't control.

# Debugging
To debug,

follow the steps at https://pub.dev/packages/custom_lint

1. Add `custom_lint` and `dart_lint_infect_mut` to Dev Dependencies of target project
2. Run `custom_lint --watch`
3. [Optional] add the dart_lint repo to the Workspace and set breakpoints within
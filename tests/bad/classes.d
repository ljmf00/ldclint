// RUN: ldc2 -wi -c %s -o- --plugin=%PLUGIN% 2>&1 | FileCheck %s

class Foo
{
    final void foo() {}
    private void bar() {}

    // CHECK-DAG: classes.d(9): Warning: Redundant attribute `final` with `private` visibility
    private final void foobar() {}
}

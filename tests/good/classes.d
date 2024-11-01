// RUN: ldc2 -w -c %s -o- --plugin=%PLUGIN%

class Foo
{
    final void foo() { bar(); }
    private void bar() {}
}

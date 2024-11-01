// RUN: ldc2 -w -c %s -o- --plugin=%PLUGIN%

private int foo(int p1, int p2)
{
    return p1 + p2;
}

int bar(int p1)
{
    return foo(p1, p1 * 2);
}

void barno(int) {}

__gshared int globalFoo;

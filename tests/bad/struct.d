// RUN: env LDCLINT_FLAGS="-Wsusderef" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

// CHECK-DAG: struct.d(4): Warning: user defined copy construction defined but no destructor
struct Foo1
{
    this(this)
    {}
}


// CHECK-DAG: struct.d(12): Warning: user defined destructor defined but no copy construction
struct Foo2
{
    ~this()
    {}
}

// CHECK-DAG: struct.d(19): Warning: user defined copy construction defined but no destructor
struct Foo3
{
    this(ref Foo3)
    {}
}

struct Foo4
{
    // CHECK-DAG: struct.d(28): Warning: Variable `a` appears to be unused
    private int a;
}

struct Foo5
{
    int[] a;

    int opIndex(size_t i) { return a[i]; }
}

auto foo()
{
    Foo5* foo5 = new Foo5;
    // CHECK-DAG: struct.d(42): Warning: Suspicious pointer indexing, use `pragma(noqa)` to ignore it.
    return foo5[5];
}

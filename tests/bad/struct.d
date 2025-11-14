// RUN: env LDCLINT_FLAGS="-Wunused" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

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
    align(1) @nogc int* a;
    // CHECK-DAG: struct.d(35): Warning: Variable `b` is misaligned and contains pointers. Use `@nogc` to be explicit.
    align(1) float* b;
}

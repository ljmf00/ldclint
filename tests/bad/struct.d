// RUN: ldc -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

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

// RUN: env LDCLINT_FLAGS="-Watproperty" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK-DAG: func.d(6): Warning: Function `foo` appears to be unused
// CHECK-DAG: func.d(6): Warning: Variable `p1` appears to be unused
// CHECK-DAG: func.d(6): Warning: Avoid the usage of `@property` attribute
@property private void foo(int p1)
{
    // CHECK-DAG: func.d(9): Warning: Variable `f` appears to be unused
    auto f = 1;

    // CHECK-DAG: func.d(12): Warning: Variable `gf` appears to be unused
    __gshared int gf;
}

// CHECK-DAG: func.d(16): Warning: Variable `globalFoobar` appears to be unused
private __gshared int globalFoobar;

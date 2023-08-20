// RUN: env LDCLINT_FLAGS="-Watproperty" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK-DAG: func.d(6): Warning: Function `foo` appears to be unused
// CHECK-DAG: func.d(6): Warning: Variable `p1` appears to be unused
// CHECK-DAG: func.d(6): Warning: Avoid the usage of `@property` attribute
@property private void foo(int p1)
{
    // CHECK-DAG: func.d(9): Warning: Variable `f` appears to be unused
    auto f = 1;

    auto r = 2;
    // CHECK-DAG: func.d(13): Warning: Redundant assignment of expression `r`
    r = r;

    // CHECK-DAG: func.d(16): Warning: Variable `gf` appears to be unused
    __gshared int gf;
}

// CHECK-DAG: func.d(20): Warning: Variable `globalFoobar` appears to be unused
private __gshared int globalFoobar;

// CHECK-DAG: func.d(23): Warning: Redundant attribute `static` and `__gshared`
static __gshared int redundantAttr;

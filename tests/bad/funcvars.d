// RUN: ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK-DAG: funcvars.d(5): Warning: Function `foo` appears to be unused
// CHECK-DAG: funcvars.d(5): Warning: Variable `p1` appears to be unused
private void foo(int p1)
{
    // CHECK-DAG: funcvars.d(8): Warning: Variable `f` appears to be unused
    auto f = 1;

    // CHECK-DAG: funcvars.d(11): Warning: Variable `gf` appears to be unused
    __gshared int gf;
}

// CHECK-DAG: funcvars.d(15): Warning: Variable `globalFoobar` appears to be unused
private __gshared int globalFoobar;

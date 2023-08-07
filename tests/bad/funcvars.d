// RUN: ldc -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK: funcvars.d(5): Warning: Function `foo` appears to be unused
// CHECK: funcvars.d(5): Warning: Variable `p1` appears to be unused
private void foo(int p1)
{
    // CHECK: funcvars.d(8): Warning: Variable `f` appears to be unused
    auto f = 1;
}

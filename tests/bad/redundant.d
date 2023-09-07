// RUN: env ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

int foo(int p1)
{
    bool ret;

    // CHECK-DAG: redundant.d(8): Warning: Redundant expression `p1 == p1`
    ret |= p1 == p1;
    // CHECK-DAG: redundant.d(10): Warning: Redundant expression `p1 != p1`
    ret |= p1 != p1;
    // CHECK-DAG: redundant.d(12): Warning: Redundant expression `p1 > p1`
    ret |= p1 > p1;
    // CHECK-DAG: redundant.d(14): Warning: Redundant expression `p1 < p1`
    ret |= p1 < p1;
    // CHECK-DAG: redundant.d(16): Warning: Redundant expression `p1 <= p1`
    ret |= p1 <= p1;
    // CHECK-DAG: redundant.d(18): Warning: Redundant expression `p1 >= p1`
    ret |= p1 >= p1;
    // CHECK-DAG: redundant.d(20): Warning: Redundant expression `p1 is p1`
    ret |= p1 is p1;
    // CHECK-DAG: redundant.d(22): Warning: Redundant expression `p1 !is p1`
    ret |= p1 !is p1;
    // CHECK-DAG: redundant.d(24): Warning: Redundant expression `p1 && p1`
    ret |= p1 && p1;
    // CHECK-DAG: redundant.d(26): Warning: Redundant expression `p1 || p1`
    ret |= p1 || p1;

    return ret;
}

// RUN: env LDCLINT_FLAGS="-Wmayoverflow" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

ulong mul(uint lhs, uint rhs)
{
    // CHECK-DAG: overflow.d(6): Warning: Expression `lhs * rhs` may overflow before cast
    return lhs * rhs;
}

// CHECK-DAG: overflow.d(10): Warning: Expression `cast(int)val * 1234` may overflow before cast
ulong mul(ushort val) { return val * 1234; }
// CHECK-DAG: overflow.d(12): Warning: Expression `val * 1234u` may overflow before cast
ulong mul(uint   val) { return val * 1234; }
// CHECK-DAG: overflow.d(14): Warning: Expression `val * -1234` may overflow before cast
long  mul(int    val) { return val * -1234; }
// CHECK-DAG: overflow.d(16): Warning: Expression `val * 1234.0F` may overflow before cast
real  mul(float  val) { return val * 1234.0f; }
// CHECK-DAG: overflow.d(18): Warning: Expression `val * -1234.0` may overflow before cast
real  mul(double val) { return val * -1234.0; }

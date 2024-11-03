// RUN: env LDCLINT_FLAGS="-Wmayoverflow" ldc2 -w -c %s -o- --plugin=%PLUGIN%

ulong mul(uint lhs, uint rhs)
{
    return cast(ulong)lhs * rhs;
}

ulong mul(ushort val) { return val * 1; }
ulong mul(uint   val) { return val * 0; }
long  mul(int    val) { return val * -1; }
real  mul(float  val) { return val * 1.0f; }
real  mul(double val) { return val * 0.1; }

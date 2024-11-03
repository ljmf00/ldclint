// RUN: ldc2 -wi -c %s -o- --plugin=%PLUGIN% 2>&1 | FileCheck %s
// CHECK-DAG: imports.d(3): Warning: Imported module `std.array` appears to be unused
import std.array;

size_t f(string s, string t)
{
    return s.length - t.length;
}

// RUN: ldc2 -w -c %s -o- --plugin=%PLUGIN%
public import std.array;
package import std.string;

size_t f(string s, string t)
{
    return s.length - t.length;
}

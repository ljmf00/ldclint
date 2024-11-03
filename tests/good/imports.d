// RUN: ldc2 -w -c %s -o- --plugin=%PLUGIN%
import std.array;
import std.complex;
import std.exception;
import std.logger.nulllogger;
import std.stdio;

class MyException : Exception
{
    mixin basicExceptionCtors;
}

size_t f(string s, string t)
{
    return [s, t].join(" ").length;
}

void g(Complex!double c)
{
    writeln(c);
}

class MyLogger : NullLogger
{
}

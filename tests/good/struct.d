// RUN: ldc2 -w -c %s -o- --plugin=libldclint.so

struct Foo1 {}
struct Foo2 { @disable this(this); }


struct Foo3
{
    float a;
    double b;
    real c;
}

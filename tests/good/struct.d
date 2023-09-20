// RUN: ldc2 -w -c %s -o- --plugin=libldclint.so

struct Foo1 {}
struct Foo2 { @disable this(this); }

struct Foo3
{
    @disable this(this);
    ~this()
    {}
}


struct Foo4
{
    float a;
    double b;
    real c;
}

struct Foo5
{
    this (int a) { this.a = a; }
    int foo()
    {
        return a;
    }

    private int a;
}

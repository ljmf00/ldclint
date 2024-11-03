// RUN: ldc2 -w -c %s -o- --plugin=%PLUGIN%

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

struct Foo6
{
    this(this) {}
    ~this() {}
}

struct Foo7
{
    this(this) {}
    ~this() {}
}

struct Foo8
{
    Foo6 foo6;
    Foo7 foo7;
}

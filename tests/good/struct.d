// RUN: ldc -w -c %s -o- --plugin=libldclint.so

struct Foo1 {}
struct Foo2 { @disable this(this); }

// RUN: cd %T && env LDCLINT_FLAGS="-Wctags" ldc2 -c %s -o- --plugin=libldclint.so && FileCheck %s < %T/tags

// CHECK: !_TAG_FILE_FORMAT
// CHECK: !_TAG_FILE_SORTED
// CHECK: !_TAG_PROGRAM_NAME	ldclint

module test_ctags;

// CHECK-DAG: MyEnum{{.*}};"	g
enum MyEnum { a, b, c }
// CHECK-DAG: a{{.*}};"	e	enum:MyEnum
// CHECK-DAG: b{{.*}};"	e	enum:MyEnum
// CHECK-DAG: c{{.*}};"	e	enum:MyEnum

// CHECK-DAG: MyStruct{{.*}};"	s
struct MyStruct
{
    // CHECK-DAG: field1{{.*}};"	m	struct:MyStruct
    int field1;
    // CHECK-DAG: field2{{.*}};"	m	struct:MyStruct
    int field2;

    // CHECK-DAG: method{{.*}};"	f	struct:MyStruct
    void method() {}
}

// CHECK-DAG: MyClass{{.*}};"	c
class MyClass
{
    // CHECK-DAG: classField{{.*}};"	m	class:MyClass
    int classField;

    // CHECK-DAG: classMethod{{.*}};"	f	class:MyClass
    void classMethod() {}
}

// CHECK-DAG: freeFunction{{.*}};"	f
void freeFunction(int x) {}

// CHECK-DAG: MyTemplate{{.*}};"	t
template MyTemplate(T) {}

// CHECK-DAG: MyAlias{{.*}};"	a
alias MyAlias = int;

// CHECK-DAG: MyUnion{{.*}};"	u
union MyUnion
{
    int i;
    float f;
}

// CHECK-DAG: globalVar{{.*}};"	v
int globalVar;

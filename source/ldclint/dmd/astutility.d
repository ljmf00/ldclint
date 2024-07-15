module ldclint.dmd.astutility;

import dmd.expression;
import dmd.mtype;
import dmd.astenums;
import dmd.tokens;
import dmd.target;
import dmd.dsymbol;
import dmd.identifier;
import dmd.opover;

import ldclint.dmd.location;

struct Resolved(T)
{
    @safe pure nothrow @nogc
    this(T wrapped) { _resolved = true; _wrapped = wrapped; }

    @safe pure nothrow @nogc
    ref T get()
    {
        if (!resolved) assert(0, "not resolved");
        return _wrapped;
    }

    @safe pure nothrow @nogc
    bool resolved() const { return _resolved; }

    /// wrapped type
    private T _wrapped;
    /// is resolved or not
    private bool _resolved;
}

Resolved!T markResolved(T)(T t) { return Resolved!T(t); }

struct Querier(T)
{
    T astNode;

    @safe pure nothrow @nogc
    bool isValid() const { return astNode !is T.init; }

    @safe pure nothrow @nogc
    U opCast(U : bool)() const { return isValid; }

    bool isIdentical(U)(Querier!U o)
    {
        return isIdentical(o.astNode);
    }

    bool isIdentical(U)(U o)
        if(!__traits(isSame, imported!"std.traits".TemplateOf!U, Querier))
    {
        static if (__traits(isSame, T, U) || is(T : U) || is(U : T))
        {
            // early check before falling into potentially more expensive check
            if (astNode is o) return true;
        }

        static if (__traits(compiles, astNode.isIdentical(o)))
            return astNode.isIdentical(o);
        else static if (__traits(compiles, o.isIdentical(astNode)))
            return o.isIdentical(astNode);
        else static if (__traits(compiles, astNode.equals(o)))
            return astNode.equals(o);
        else static if (__traits(compiles, o.equals(astNode)))
            return o.equals(astNode);
        else static if (__traits(compiles, astNode == o))
            return astNode == o;
        else static if (__traits(compiles, o == astNode))
            return o == astNode;
        else
            return false;
    }

    static if (is(T : TypePointer))
    {
        auto pointeeType() { return querier(astNode.next); }
    }

    static if (is(T : TypeStruct))
    {
        auto structDeclaration() { return querier(astNode.sym); }
    }

    static if (is(T : TypeClass))
    {
        auto classDeclaration() { return querier(astNode.sym); }
    }

    static if (is(T : Type))
    {
        Querier!Type type() { return querier(cast(Type)astNode); }
        Querier!Type baseType()
        {
            return querier((cast(Type)astNode).toBasetype());
        }

        auto isStructType()       { return querier(baseType.astNode.isTypeStruct()); }
        auto isPointerType()      { return querier(baseType.astNode.isTypePointer()); }
        auto isStaticArrayType()  { return querier(baseType.astNode.isTypeSArray()); }
        auto isDynamicArrayType() { return querier(baseType.astNode.isTypeDArray()); }

        Resolved!size_t alignment()
        {
            auto sa = baseType.astNode.alignment();
            if (sa.isUnknown()) return typeof(return).init;

            return markResolved(size_t(sa.get()));
        }

        Resolved!size_t size()
        {
            switch (baseType.astNode.ty)
            {
                case TY.Tvoid:
                case TY.Tnone:
                    return markResolved(size_t(0));
                case TY.Terror:
                    return typeof(return).init;

                case Tarray:
                    return markResolved(size_t(
                        target.ptrsize + (target.isLP64 ? 8 : 4)
                    ));

                case TY.Taarray:
                case TY.Tpointer:
                case TY.Treference:
                case TY.Tclass:
                case TY.Tnull:
                case TY.Tfunction:
                    return markResolved(size_t(
                        target.ptrsize
                    ));
                case TY.Tdelegate:
                    return markResolved(size_t(
                        target.ptrsize * 2
                    ));

                case TY.Tint8:
                case TY.Tuns8:
                case TY.Tbool:
                case TY.Tchar:
                    return markResolved(size_t(1));
                case TY.Tint16:
                case TY.Tuns16:
                    return markResolved(size_t(2));
                case TY.Tint32:
                case TY.Tuns32:
                case TY.Tfloat32:
                case TY.Timaginary32:
                    return markResolved(size_t(4));
                case TY.Tint64:
                case TY.Tuns64:
                case TY.Tfloat64:
                case TY.Timaginary64:
                    return markResolved(size_t(8));

                case Tint128:
                case Tuns128:
                    return markResolved(size_t(16));

                case TY.Tcomplex32:
                    return markResolved(size_t(8));
                case TY.Tcomplex64:
                    return markResolved(size_t(16));

                case TY.Tfloat80:
                case TY.Timaginary80:
                    return markResolved(size_t(target.realsize));
                case TY.Tcomplex80:
                    return markResolved(size_t(
                        target.realsize * 2
                    ));

                case Twchar:
                    return markResolved(size_t(2));
                case Tdchar:
                    return markResolved(size_t(4));

                default:
                    auto sz = baseType.astNode.size();

                    // should be the same but what if there's an exotic
                    // architecture.  Let's play safe here
                    if (sz == SIZE_INVALID) return typeof(return).init;
                    else                    return markResolved(sz);
            }
        }
    }

    bool isResolved()
    {
        string _; return isResolved(_);
    }

    bool isResolved(out string error)
    {
        if (!isValid)
        {
            error = "invalid node";
            return false;
        }

        static if (is(T : Dsymbol))
        {
            Dsymbol dsym = astNode;

            if (dsym.errors)
            {
                error = "symbol has internal errors";
                return false;
            }

            if(astNode.isforwardRef())
            {
                error = "symbol is a forward reference";
                return false;
            }

            if (astNode.semanticRun < PASS.semantic3done)
            {
                error = "not all semantic passes done in this symbol";
                return false;
            }
        }

        static if (is(T : Type))
        {
            if (astNode.ty == Terror)
            {
                error = "type has internal errors";
                return false;
            }

            auto type = baseType.astNode;
            if (type.ty == Terror)
            {
                error = "base type has internal errors";
                return false;
            }

            if (!baseType.size.resolved)
            {
                error = "unresolved type size";
                return false;
            }

            if (!baseType.alignment.resolved)
            {
                error = "unresolved type alignment";
                return false;
            }
        }

        static if (is(T : Expression))
        {
            Expression e = astNode;

            if (e.op == EXP.error)
            {
                error = "expression has internal errors";
                return false;
            }

            if (e.op == EXP.cantExpression)
            {
                error = "expression can't be constant folded";
                return false;
            }

            if (e.op == EXP.voidExpression)
            {
                error = "expression is void";
                return false;
            }

            // type need to exist to be resolved
            if (!this.type.isResolved(error)) return false;

            if (auto ue = e.isUnaExp())
                return querier(ue.e1).isResolved(error);
            if (auto be = e.isBinExp())
                return querier(be.e1).isResolved(error)
                    && querier(be.e2).isResolved(error);
        }

        // assume its resolved
        return true;
    }

    static if (is(T : Expression))
    {
        Querier!Type type() { return querier(astNode.type); }

        Resolved!bool hasCTKnownValue()
        {
            if (!isResolved) return typeof(return).init;

            switch (astNode.op)
            {
                case EXP.string_:
                case EXP.int64:
                case EXP.float64:
                case EXP.complex80:
                case EXP.null_:
                case EXP.arrayLiteral:
                case EXP.assocArrayLiteral:
                case EXP.structLiteral:
                case EXP.prettyFunction:
                case EXP.line:
                case EXP.file:
                case EXP.fileFullPath:
                case EXP.moduleString:
                case EXP.functionString:
                case EXP.function_:
                case EXP.typeid_:
                    return markResolved(true);
                default:
                    return markResolved(false);
            }
        }

        Resolved!bool isLvalue()
        {
            if (!isResolved) return typeof(return).init;

            static if (__traits(compiles, astNode.isLvalue()))
                return markResolved(astNode.isLvalue());
            else
                // assume its not an lvalue
                return markResolved(false);
        }
    }

    Querier!Dsymbol hasSymbol(string name)
    {
        // FIXME: add compile-time lookup via Id class
        return hasSymbol(Identifier.idPool(name));
    }

    Querier!Dsymbol hasSymbol(Identifier ident)
    {
        static if (__traits(compiles, astNode.search(Loc.initial, ident)))
            if (auto sym = astNode.search(Loc.initial, ident))
                return querier(sym);

        static if (__traits(compiles, search_function(astNode, ident)))
            if (auto sym = search_function(astNode, ident))
                return querier(sym);

        return querier(cast(Dsymbol)null);
    }

    ref const(Loc) loc() const
    {
        static if (__traits(compiles, astNode.loc))
            return astNode.loc;
        else
            return Loc.initial;
    }
}

auto querier(T)(auto ref T t) { return Querier!T(t); }

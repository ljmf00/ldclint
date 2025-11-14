module ldclint.utils.querier;

import DMD = ldclint.dmd;
import DParse = ldclint.dparse;

import ldclint.utils.location;
public import dmd.target : target;

import std.traits;

///////////////////////////////////////////////////////////////////////////////

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

///////////////////////////////////////////////////////////////////////////////

struct Querier(T)
{
    T astNode;
    alias astNode this;

    static if (is(T : DMD.FuncDeclaration))
    {
        @safe pure nothrow @nogc
        bool isValid() const
        {
            // skip invalid nodes
            if (astNode is T.init) return false;

            // skip generated functions by the semantic analysis
            if (this.isGenerated()) return false;
            // skip naked functions due to high possibility of false positives
            if (astNode.isNaked) return false;

            // valid otherwise
            return true;
        }
    }
    else
    {
        @safe pure nothrow @nogc
        bool isValid() const { return astNode !is T.init; }
    }

    Querier!(DMD.Module) getModule() {
        static if (is(T : DMD.Dsymbol))
            return querier(astNode.getModule());
        else
            return typeof(return).init;
    }

    bool isFrom(T)(Querier!T sym)
    {
        auto mod = sym.getModule();
        return mod && mod != this.getModule();
    }

    @safe pure nothrow @nogc
    U opCast(U : bool)() const { return isValid; }

    auto opCast(U)()
        if(__traits(isSame, TemplateOf!U, Querier))
    {
        return querier(cast(typeof(U.astNode))astNode);
    }

    auto opCast(U)()
        if(!is(U == bool) && !__traits(isSame, TemplateOf!U, Querier))
    {
        return querier(cast(U)astNode);
    }

    bool isIdentical(U)(auto ref Querier!U o)
    {
        return isIdentical(o.astNode);
    }

    bool isIdentical(U)(auto ref U o)
        if(!__traits(isSame, TemplateOf!U, TemplateOf!(Querier!T)))
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

    static if (is(T : DMD.TypePointer))
    {
        auto pointeeType() { return querier(astNode.next); }
    }

    static if (is(T : DMD.TypeStruct))
    {
        auto structDeclaration() { return querier(astNode.sym); }
    }

    static if (is(T : DMD.TypeClass))
    {
        auto classDeclaration() { return querier(astNode.sym); }
    }

    static if (is(T : DMD.Type))
    {
        Querier!(DMD.Type) type() { return querier(cast(DMD.Type)astNode); }
        Querier!(DMD.Type) baseType()
        {
            return querier((cast(DMD.Type)astNode).toBasetype());
        }

        Resolved!bool isScalarType()
        {
            if (!isResolved) return typeof(return).init;
            return typeof(return)(astNode.isscalar);
        }

        Resolved!bool isUnsignedType()
        {
            if (!isResolved) return typeof(return).init;
            return typeof(return)(astNode.isunsigned);
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
                case DMD.TY.Tvoid:
                case DMD.TY.Tnone:
                    return markResolved(size_t(0));
                case DMD.TY.Terror:
                    return typeof(return).init;

                case DMD.Tarray:
                    return markResolved(size_t(
                        target.ptrsize + (target.isLP64 ? 8 : 4)
                    ));

                case DMD.TY.Taarray:
                case DMD.TY.Tpointer:
                case DMD.TY.Treference:
                case DMD.TY.Tclass:
                case DMD.TY.Tnull:
                case DMD.TY.Tfunction:
                    return markResolved(size_t(
                        target.ptrsize
                    ));
                case DMD.TY.Tdelegate:
                    return markResolved(size_t(
                        target.ptrsize * 2
                    ));

                case DMD.TY.Tint8:
                case DMD.TY.Tuns8:
                case DMD.TY.Tbool:
                case DMD.TY.Tchar:
                    return markResolved(size_t(1));
                case DMD.TY.Tint16:
                case DMD.TY.Tuns16:
                    return markResolved(size_t(2));
                case DMD.TY.Tint32:
                case DMD.TY.Tuns32:
                case DMD.TY.Tfloat32:
                case DMD.TY.Timaginary32:
                    return markResolved(size_t(4));
                case DMD.TY.Tint64:
                case DMD.TY.Tuns64:
                case DMD.TY.Tfloat64:
                case DMD.TY.Timaginary64:
                    return markResolved(size_t(8));

                case DMD.Tint128:
                case DMD.Tuns128:
                    return markResolved(size_t(16));

                case DMD.TY.Tcomplex32:
                    return markResolved(size_t(8));
                case DMD.TY.Tcomplex64:
                    return markResolved(size_t(16));

                case DMD.TY.Tfloat80:
                case DMD.TY.Timaginary80:
                    return markResolved(size_t(target.realsize));
                case DMD.TY.Tcomplex80:
                    return markResolved(size_t(
                        target.realsize * 2
                    ));

                case DMD.Twchar:
                    return markResolved(size_t(2));
                case DMD.Tdchar:
                    return markResolved(size_t(4));

                default:
                    auto sz = baseType.astNode.size();

                    // should be the same but what if there's an exotic
                    // architecture.  Let's play safe here
                    if (sz == DMD.SIZE_INVALID) return typeof(return).init;
                    else                    return markResolved(sz);
            }
        }
    }

    static if (is(T : DMD.Declaration))
    {
        Resolved!bool isNogc()
        {
            if (!isResolved) return typeof(return).init;
            return typeof(return)((astNode.storage_class & DMD.STC.nogc) != 0);
        }

        Resolved!bool isCTFE()
        {
            if (!isResolved) return typeof(return).init;
            return typeof(return)((astNode.storage_class & DMD.STC.ctfe) != 0);
        }
    }

    static if (is(T : DMD.StructDeclaration))
    {
        Resolved!bool hasPostblit()
        {
            if (!isResolved) return typeof(return).init;
            return typeof(return)(astNode.postblits.length > 0);
        }

        Resolved!bool hasUserPostblit()
        {
            if (!isResolved) return typeof(return).init;

            bool hasUserDefinedPostblit;
            foreach(p; astNode.postblits)
            {
                if (p.ident == DMD.Id.postblit)
                {
                    hasUserDefinedPostblit = true;
                    break;
                }
            }

            return typeof(return)(hasUserDefinedPostblit);
        }

        Resolved!bool hasUserDestructor()
        {
            if (!isResolved) return typeof(return).init;
            return typeof(return)(astNode.userDtors.length > 0);
        }

        Resolved!bool hasCopyConstructor()
        {
            if (!isResolved) return typeof(return).init;
            return typeof(return)(astNode.hasCopyCtor);
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

        static if (is(T : DMD.Dsymbol))
        {
            DMD.Dsymbol dsym = astNode;

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

            switch (astNode.semanticRun)
            {
                case DMD.PASS.initial:       error = "no semantic pass done in this symbol";        return false;
                case DMD.PASS.semantic:      error = "unfinished 1st semantic pass in this symbol"; return false;
                case DMD.PASS.semanticdone: goto default;
                /*
                case DMD.PASS.semanticdone:  error = "only 1st semantic pass in this symbol";       return false;
                case DMD.PASS.semantic2:     error = "unfinished 2nd semantic pass in this symbol"; return false;
                case DMD.PASS.semantic2done: error = "only 2nd semantic pass in this symbol";       return false;
                case DMD.PASS.semantic3:     error = "unfinished 3nd semantic pass in this symbol"; return false;
                case DMD.PASS.semantic3done: goto default;
                */
                default:                 break;
            }
        }

        static if (is(T : DMD.Type))
        {
            if (astNode.ty == DMD.Terror)
            {
                error = "type has internal errors";
                return false;
            }

            auto type = baseType.astNode;
            if (type.ty == DMD.Terror)
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

        static if (is(T : DMD.Expression))
        {
            DMD.Expression e = astNode;

            if (e.op == DMD.EXP.error)
            {
                error = "expression has internal errors";
                return false;
            }

            if (e.op == DMD.EXP.cantExpression)
            {
                error = "expression can't be constant folded";
                return false;
            }

            if (e.op == DMD.EXP.voidExpression)
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

    static if (is(T : DMD.Expression))
    {
        auto type() { return querier(astNode.type); }

        Resolved!bool hasCTKnownValue()
        {
            if (!isResolved) return typeof(return).init;

            switch (astNode.op)
            {
                case DMD.EXP.string_:
                case DMD.EXP.int64:
                case DMD.EXP.float64:
                case DMD.EXP.complex80:
                case DMD.EXP.null_:
                case DMD.EXP.arrayLiteral:
                case DMD.EXP.assocArrayLiteral:
                case DMD.EXP.structLiteral:
                case DMD.EXP.prettyFunction:
                case DMD.EXP.line:
                case DMD.EXP.file:
                case DMD.EXP.fileFullPath:
                case DMD.EXP.moduleString:
                case DMD.EXP.functionString:
                case DMD.EXP.function_:
                case DMD.EXP.typeid_:
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

    static if (is(T : DMD.UnaExp))
    {
        auto e1() { return querier(astNode.e1); }
    }

    static if (is(T : DMD.BinExp))
    {
        auto e1() { return querier(astNode.e1); }
        auto e2() { return querier(astNode.e2); }

        alias lhs = e1;
        alias rhs = e2;
    }

    bool isGenerated() const
    {
        static if (is(T : DMD.VarDeclaration))
        {
            if (astNode.storage_class & DMD.STC.temp)
                return true;
        }

        static if (__traits(compiles, astNode.isGenerated))
            if (astNode.isGenerated)
                return true;

        return false;
    }

    static if (is(T : DMD.RootObject))
    {
        Querier!(DMD.Dsymbol) hasSymbol(string name)
        {
            // FIXME: add compile-time lookup via Id class
            return hasSymbol(DMD.Identifier.idPool(name));
        }

        Querier!(DMD.Dsymbol) hasSymbol(DMD.Identifier ident)
        {
            static if (__traits(compiles, astNode.search(DMD.Loc.initial, ident)))
                if (auto sym = astNode.search(DMD.Loc.initial, ident))
                    return querier(sym);

            static if (__traits(compiles, search_function(astNode, ident)))
                if (auto sym = search_function(astNode, ident))
                    return querier(sym);

            return querier(cast(DMD.Dsymbol)null);
        }

        const(Location) location() const
        {
            static if (__traits(compiles, astNode.loc))
                return Location(astNode.loc);
            else
                return Location.init;
        }
    }
}

auto querier(T)(auto ref Querier!T t) { return t; }
auto querier(T)(auto ref T t)
    if(!__traits(isSame, Querier, TemplateOf!T))
{ return Querier!T(t); }

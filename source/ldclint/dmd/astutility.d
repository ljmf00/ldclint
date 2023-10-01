module ldclint.dmd.astutility;

import dmd.expression;
import dmd.mtype;
import dmd.astenums;
import dmd.target;

bool isIdenticalASTNodes(T, U)(T lhs, U rhs)
{
    static if (__traits(isSame, T, U) || is(T : U) || is(U : T))
    {
        // early check before falling into potentially more expensive check
        if (lhs is rhs) return true;
    }

    static if (__traits(compiles, lhs.isIdentical(rhs)))
        return lhs.isIdentical(rhs);
    else static if (__traits(compiles, rhs.isIdentical(lhs)))
        return rhs.isIdentical(lhs);
    else static if (__traits(compiles, lhs.equals(rhs)))
        return lhs.equals(rhs);
    else static if (__traits(compiles, rhs.equals(lhs)))
        return rhs.equals(lhs);
    else static if (__traits(compiles, lhs == rhs))
        return lhs == rhs;
    else static if (__traits(compiles, rhs == lhs))
        return rhs == lhs;
    else
        return false;
}

bool isResolved(T)(T t)
{
    if (!t) return false;

    static if (is(T : Expression))
    {
        Expression e = t;
        // type need to exist to be resolved
        if (!e.type) return false;

        if (auto ue = e.isUnaExp())
            return isResolved(ue.e1);
        else if (auto be = e.isBinExp())
            return isResolved(be.e1) && isResolved(be.e2);
        else
            return true;
    }
    // assume it is
    else return true;
}

bool isLvalue(T)(T t)
{
    static if (is(T : Expression))
    {
        Expression e = t;
        // skip unresolved expressions
        if (!isResolved(e)) return false;

        // check
        return e.isLvalue();
    }
    // assume its not
    else return false;
}

size_t typeSize(T)(T t)
{
    static if (is(T : Type))
    {
        Type type = (cast(Type)t).toBasetype();
        switch (type.ty)
        {
            case TY.Tnone:
                return 0;
            case TY.Terror:
                return size_t.max;

            case Tarray:
                return target.ptrsize + (target.is64bit ? 8 : 4);

            case TY.Taarray:
            case TY.Tpointer:
            case TY.Treference:
            case TY.Tclass:
            case TY.Tnull:
            case TY.Tfunction:
                return target.ptrsize;
            case TY.Tdelegate:
                return target.ptrsize * 2;

            case TY.Tvoid:
            case TY.Tint8:
            case TY.Tuns8:
            case TY.Tbool:
            case TY.Tchar:
                return 1;
            case TY.Tint16:
            case TY.Tuns16:
                return 2;
            case TY.Tint32:
            case TY.Tuns32:
            case TY.Tfloat32:
            case TY.Timaginary32:
                return 4;
            case TY.Tint64:
            case TY.Tuns64:
            case TY.Tfloat64:
            case TY.Timaginary64:
                return 8;

            case Tint128:
            case Tuns128:
                return 16;

            case TY.Tcomplex32:
                return 8;
            case TY.Tcomplex64:
                return 16;

            case TY.Tfloat80:
            case TY.Timaginary80:
                return target.realsize;
            case TY.Tcomplex80:
                return target.realsize * 2;

            case Twchar:
                return 2;
            case Tdchar:
                return 4;

            default:
                auto sz = type.size();

                // should be the same but what if there's an exotic
                // architecture.  Let's play safe here
                if (sz == SIZE_INVALID) return size_t.max;
                else                    return sz;
        }

    }
    else return size_t.max;
}

module ldclint.dmd.astutility;

import dmd.expression;

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

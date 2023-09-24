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

bool isLvalue(T)(T t)
{
    static if (is(T : Expression))
    {
        if (auto ce = t.isCallExp())
        {
            // assume its not when we don't even know the expression
            if (!ce.e1) return false;

            // the type is not resolved, we say its not
            if (!ce.e1.type) return false;

            return ce.isLvalue();
        }

        return t.isLvalue();
    }
    // assume its not
    else return false;
}

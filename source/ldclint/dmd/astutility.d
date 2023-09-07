module ldclint.dmd.astutility;

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

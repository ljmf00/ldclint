module ldclint.dmd.scopetracker;

import dmd.dscope;
import dmd.dsymbol;
import dmd.func;

struct ScopeTracker
{
    /// current scope being tracked
    Scope* current;

    /// depth of functions
    ptrdiff_t functionDepth;

    Scope* extract(T)(T node)
    {
        static if (is(T : Dsymbol))
            return node._scope;
        else
            return null;
    }

    Scope* track(T)(T node)
    {
        auto previous = current;
        if (auto e = this.extract(node))
            current = e;

        static if (is(T : FuncDeclaration))
            ++functionDepth;

        return previous;
    }

    void untrack(T)(T /*node*/, Scope* sc)
    {
        if (sc) current = sc;

        static if (is(T : FuncDeclaration))
        {
            --functionDepth;
            assert(functionDepth >= 0, "function depth under zero");
        }
    }
}

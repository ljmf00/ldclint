module ldclint.dmd.visitor;

import ldclint.dmd.ast;
import ldclint.utils.querier;

static import std.traits;

extern(C++) class VisitorProxy(V) : Visitor
{
    public this(V visitor) { this.visitor = visitor; }

    private V visitor;

    ///////////////////////////////////////////////////////////////////////////

    static foreach(visitFunction; __traits(getOverloads, Visitor, "visit"))
    {
        override void visit(std.traits.Parameters!(visitFunction)[0] node) { visitor.visit(querier(node)); }
    }

}

auto visitorProxy(V)(V v) { return new VisitorProxy!V(v); }

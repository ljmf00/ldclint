module ldclint.checks.mayoverflow;

import ldclint.visitors;
import ldclint.dmd.astutility;

import dmd.dmodule;
import dmd.declaration;
import dmd.dimport;
import dmd.dsymbol;
import dmd.func;
import dmd.errors;
import dmd.id;
import dmd.expression;
import dmd.statement;
import dmd.mtype;
import dmd.astenums;

import std.stdio;
import std.string;
import std.array;
import std.range;
import std.bitmanip;

extern(C++) final class MayOverflowCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    override void visit(CastExp e)
    {
        super.visit(e);

        // lets skip invalid casts
        if (!isValid(e)) return;

        if (auto mule = e.e1.isMulExp())
            visitCasted(mule, e.to);
    }

    private void visitCasted(MulExp e, Type type)
    {
        // lets skip invalid assignments
        if (!isValid(e)) return;

        // don't warn about null expressions
        if (!e.e1 || !e.e2) return;

        // don't try to get types
        if (!e.e1.type || !e.e2.type) return;

        Type t1 = e.e1.type.toBasetype();
        Type t2 = e.e2.type.toBasetype();

        // if they are not scalars, lets skip it
        if (!t1.isscalar || !t2.isscalar) return;

        auto s1 = t1.size();
        auto s2 = t2.size();

        auto castSize = type.size();

        if (s1 < castSize && s2 < castSize)
        {
            warning(e.loc, "Expression `%s` may overflow before cast", e.toChars());
        }
    }
}

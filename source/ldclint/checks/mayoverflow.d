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

        if (auto re1 = e.e1.isRealExp())
        {
            auto r1 = re1.toReal();
            if (r1 <= 1.0L && r1 >= -1.0L) return;
        }
        else if (auto ie1 = e.e1.isIntegerExp())
        {
            if (t1.isunsigned)
            {
                ulong u1 = ie1.toUInteger();
                if (u1 <= 1) return;
            }
            else
            {
                long i1 = ie1.toInteger();
                if (i1 <= 1 && i1 >= -1) return;
            }
        }

        if (auto re2 = e.e2.isRealExp())
        {
            auto r2 = re2.toReal();
            if (r2 <= 1.0L && r2 >= -1.0L) return;
        }
        else if (auto ie2 = e.e2.isIntegerExp())
        {
            if (t2.isunsigned)
            {
                ulong u2 = ie2.toUInteger();
                if (u2 <= 1) return;
            }
            else
            {
                long i2 = ie2.toInteger();
                if (i2 <= 1 && i2 >= -1) return;
            }
        }

        auto s1 = t1.size();
        auto s2 = t2.size();

        auto castSize = type.size();

        if (s1 < castSize && s2 < castSize)
        {
            warning(e.loc, "Expression `%s` may overflow before conversion", e.toChars());
        }
    }
}

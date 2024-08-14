module ldclint.checks.sus_dref;

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

extern(C++) final class SuspiciousDerefCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    void[0][Expression] expToSkip;

    override void visit(IndexExp e) { checkForDref(e); }

    private void checkForDref(E)(E e)
    {
        super.visit(e);

        // lets skip invalid expressions
        if (!isValid(e)) return;

        auto lhs = querier(e.e1);

        // lets skip invalid lhs expression
        if (!lhs.isValid) return;

        // lets skip unresolved expressions
        if (!lhs.isResolved) return;

        // lets skip expression explicitly marked as skippable
        if ((cast(Expression)e.e1) in expToSkip) return;

        if (auto typ = lhs.type.baseType.isPointerType())
        {
            if (auto tys = typ.pointeeType.isStructType())
            {
                auto s = tys.structDeclaration;

                if (s.hasSymbol(Id.index)
                 || s.hasSymbol(Id.indexass)
                 || s.hasSymbol(Id.slice)
                 || s.hasSymbol(Id.sliceass))
                {
                    // TODO: implement pragma(noqa)
                    warning(lhs.loc, "Suspicious pointer indexing, use `pragma(noqa)` to ignore it.");
                }
            }

        }
    }

    private void visit(AddrExp e)
    {
        super.visit(e);

        // lets skip invalid expressions
        if (!isValid(e)) return;

        auto exp = querier(e.e1);

        // lets skip invalid inner expression
        if (!exp.isValid) return;

        // lets skip unresolved inner expression
        if (!exp.isResolved) return;

        // add to skippable expressions
        if (e.e1.isPtrExp)
        {
            expToSkip[cast(Expression)e] = (void[0]).init;
        }
    }
}

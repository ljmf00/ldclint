module ldclint.checks.boolbitwise;

import ldclint.visitors;

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

extern(C++) final class BoolBitwiseCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    override void visit(AndExp e) { visitBinExp(e); }
    override void visit(OrExp e)  { visitBinExp(e); }
    override void visit(ComExp e) { visitUnaExp(e); }

    private void visitBinExp(E)(E e)
    {
        super.visit(e);

        visitExp(e.e1);
        visitExp(e.e2);
    }

    private void visitUnaExp(E)(E e)
    {
        super.visit(e);

        visitExp(e.e1);
    }

    private void visitExp(Expression e)
    {
        // lets skip invalid assignments
        if (!isValid(e)) return;

        auto t = e.type;
        // skip for unknown types
        if (!t) return;

        if (t.toBasetype().ty == TY.Tbool)
        {
            warning(e.loc, "Avoid bitwise operations with boolean `%s`", e.toChars());
        }
    }
}

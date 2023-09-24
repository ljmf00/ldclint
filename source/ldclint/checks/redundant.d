module ldclint.checks.redundant;

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

extern(C++) final class RedundantCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    override void visit(VarDeclaration vd)
    {
        // lets skip invalid variable declarations
        if (!isValid(vd)) return;

        if (vd.storage_class & STC.static_ && vd.storage_class & STC.gshared)
            warning(vd.loc, "Redundant attribute `static` and `__gshared`");

        // traverse through the AST
        super.visit(vd);
    }

    override void visit(FuncDeclaration fd)
    {
        // lets skip invalid function declarations
        if (!isValid(fd)) return;

        if (fd.storage_class & STC.final_ && fd.visibility.kind == Visibility.Kind.private_)
            warning(fd.loc, "Redundant attribute `final` with `private` visibility");

        // traverse through the AST
        super.visit(fd);
    }

    override void visit(IdentityExp e) { visitBinExp(e); }
    override void visit(EqualExp e)    { visitBinExp(e); }
    override void visit(CmpExp e)      { visitBinExp(e); }
    override void visit(AssignExp e)   { visitBinExp(e); }
    override void visit(LogicalExp e)  { visitBinExp(e); }

    private void visitBinExp(E)(E e)
    {
        // lets skip invalid assignments
        if (!isValid(e)) return;

        // don't warn about null expressions
        if (!e.e1 || !e.e2) return;

        if (isIdenticalASTNodes(e.e1, e.e2))
        {
            // skip rvalues from this check
            if (isResolved(e.e1) && !isLvalue(e.e1)) return;
            if (isResolved(e.e2) && !isLvalue(e.e2)) return;

            warning(e.loc, "Redundant expression `%s`", e.toChars());
        }

        super.visit(e);
    }
}

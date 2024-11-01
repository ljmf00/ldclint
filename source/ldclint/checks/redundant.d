module ldclint.checks.redundant;

import ldclint.visitors;
import ldclint.dmd.astutility;

import dmd.dmodule;
import dmd.declaration;
import dmd.dimport;
import dmd.dtemplate;
import dmd.dsymbol;
import dmd.func;
import dmd.errors;
import dmd.id;
import dmd.expression;
import dmd.statement;
import dmd.mtype;
import dmd.astenums;

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
    override void visit(AndExp e)      { visitBinExp(e); }
    override void visit(OrExp e)       { visitBinExp(e); }

    private void visitBinExp(E)(E e)
    {
        super.visit(e);

        // lets skip invalid expressions
        if (!isValid(e)) return;

        // skip unresolved expressions
        if (!querier(e).isResolved) return;

        if (querier(e.e1).isIdentical(e.e2))
        {
            // skip expressions known at compile-time
            if (querier(e.e1).hasCTKnownValue.get || querier(e.e2).hasCTKnownValue.get) return;

            // skip rvalues from this check
            if (!querier(e.e1).isLvalue.get) return;
            if (!querier(e.e2).isLvalue.get) return;

            warning(e.loc, "Redundant expression `%s`", e.toChars());
        }
    }

    // avoid all sorts of false positives without semantics
    override void visit(TemplateDeclaration) { /* skip */ }
}

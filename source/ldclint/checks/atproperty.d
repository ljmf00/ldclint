module ldclint.checks.atproperty;

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

extern(C++) final class AtPropertyCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    override void visit(FuncDeclaration fd)
    {
        // lets skip invalid functions
        if (!isValid(fd)) return;

        if (fd.type.isTypeFunction().isproperty
            || fd.storage_class & STC.property
            || fd.storage_class2 & STC.property)
            warning(fd.loc, "Avoid the usage of `@property` attribute");

        // traverse through the AST
        super.visit(fd);
    }
}

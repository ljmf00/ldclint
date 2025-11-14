module ldclint.checks.atproperty;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "atproperty",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        // lets skip invalid/unresolved functions
        if (!fd.isResolved) return;

        if (fd.type.isTypeFunction().isproperty
            || fd.storage_class & DMD.STC.property
            || fd.storage_class2 & DMD.STC.property)
            warning(fd.loc, "Avoid the usage of `@property` attribute");

        // traverse through the AST
        super.visit(fd);
    }
}

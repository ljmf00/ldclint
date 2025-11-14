module ldclint.checks.alignment;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "alignment",
    Yes.byDefault,
    Yes.allModules,
    100 /* priority */,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.VarDeclaration) var)
    {
        // traverse through the AST
        super.visit(var);

        // lets skip invalid vars
        if (!var.isValid()) return;

        // skip unresolved variables
        if (!var.isResolved()) return;

        // should be safe inside CTFE
        if (var.isCTFE.get || var.isNogc.get) return;

        // should be safe for any alignment
        if (!var.hasPointers) return;

        // skip unknown/safe alignment
        if (var.alignment.get >= 8 && !var.alignment.isPack) return;

        warning(var.loc, "Variable `%s` is misaligned and contains pointers. Use `@nogc` to be explicit.", var.toChars());
    }
}

module ldclint.checks.structs_dtor_postblit;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "struct-dtorpostblit",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.StructDeclaration) sd)  { visit!DMD(sd); }

    private void visit(alias M)(Querier!(M.StructDeclaration) sd)
    {
        // skip unresolved symbols
        if (!sd.isResolved) return;

        super.visit(sd);

        // skip structs that have disabled postblits
        if (sd.hasPostblit.get && sd.postblits[0].isDisabled)
            return;

        auto hasUserDefinedCopyCtor = sd.hasUserPostblit.get || sd.hasCopyConstructor.get;

        if (hasUserDefinedCopyCtor && !sd.hasUserDestructor.get)
            warning(sd.loc, "user defined copy construction defined but no destructor");
        else if (!hasUserDefinedCopyCtor && sd.hasUserDestructor.get)
            warning(sd.loc, "user defined destructor defined but no copy construction");
    }
}

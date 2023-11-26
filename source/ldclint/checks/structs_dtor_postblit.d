module ldclint.checks.structs_dtor_postblit;

import ldclint.visitors;

import dmd.visitor;
import dmd.dmodule;
import dmd.declaration;
import dmd.dimport;
import dmd.dsymbol;
import dmd.func;
import dmd.errors;
import dmd.id;
import dmd.expression;
import dmd.statement;
import dmd.dstruct;

import std.stdio;
import std.string;

extern(C++) final class StructDtorPostblitCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    override void visit(StructDeclaration sd)
    {
        if (!isValid(sd)) return;

        super.visit(sd);

        // skip structs that have disabled postblits
        if (sd.postblits.length && sd.postblits[0].isDisabled)
            return;

        auto hasUserDefinedCopyCtor = sd.postblits.length || sd.hasCopyCtor;
        auto hasUserDefinedDtors = sd.userDtors.length > 0;

        if (hasUserDefinedCopyCtor && !hasUserDefinedDtors)
            warning(sd.loc, "user defined copy construction defined but no destructor");
        else if (!hasUserDefinedCopyCtor && hasUserDefinedDtors)
            warning(sd.loc, "user defined destructor defined but no copy construction");
    }
}

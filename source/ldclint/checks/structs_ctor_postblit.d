module ldclint.checks.structs_ctor_postblit;

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

//version = printUnvisited;

extern(C++) final class StructCtorPostblitCheckVisitor : SemanticTimeTransitiveVisitor
{
    alias visit = SemanticTimeTransitiveVisitor.visit;

    override void visit(StructDeclaration decl)
    {
        auto hasUserDefinedCopyCtor = (decl.postblits.length && !decl.postblits[0].isDisabled ? true : false)
            || decl.hasCopyCtor;
        auto hasUserDefinedDtors = decl.userDtors.length > 0;

        if (hasUserDefinedCopyCtor && !hasUserDefinedDtors)
            warning(decl.loc, "user defined copy construction defined but no destructor");
        else if (!hasUserDefinedCopyCtor && hasUserDefinedDtors)
            warning(decl.loc, "user defined destructor defined but no copy construction");
    }
}

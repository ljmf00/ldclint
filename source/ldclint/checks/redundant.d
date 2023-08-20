module ldclint.checks.redundant;

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
}

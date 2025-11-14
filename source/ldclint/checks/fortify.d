module ldclint.checks.fortify;

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

extern(C++) final class FortifyCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    override void visit(CallExp call)
    {
        // lets skip invalid calls
        if (!isValid(call)) return;

        /// lets skip if no function declaration symbol
        if (!isValid(call.f)) return;

        if      (call.f.ident == Id.memcpy) visitCall!"memcpy"(call);
        else if (call.f.ident == Id.memset) visitCall!"memset"(call);
        else if (call.f.ident == Id.memcmp) visitCall!"memcmp"(call);
        else if (call.f.ident == Id.strcpy) visitCall!"strcpy"(call);
        else if (call.f.ident == Id.strcmp) visitCall!"strcmp"(call);

        // traverse through the AST
        super.visit(fd);
    }

    void visitCall(string name : "memcpy")(CallExp call) {}
}

module ldclint.checks.atproperty;

import ldclint.visitors;
import ldclint.dmd.location;

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
import dmd.dtemplate;

import std.stdio;
import std.string;
import std.array;
import std.range;
import std.bitmanip;

extern(C++) final class CompilerCoherenceCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    override void visit(Dsymbol sym)
    {
        // lets skip invalid symbols
        if (!isValid(sym)) return;

        if (sym.isforwardRef())
        {
            warning(sym.loc, "This symbol can't be resolved because it's a forward reference");
        }

        // traverse through the AST
        super.visit(sym);
    }

    override void visit(Type t)
    {
        // lets skip invalid types
        if (!isValid(t)) return;

        if (t.ty == TY.Terror)
        {
            warning(Loc.initial, "Type `%s` resolves to an error type", t.toChars());
        }

        // this errors if the size is not known
        cast(void)t.size();

        // traverse through the AST
        super.visit(t);

        if (auto bt = t.toBasetype())
        {
            visit(bt);
        }
        else
        {
            warning(Loc.initial, "Type `%s` can't be resolved to the base type", t.toChars());
        }
    }

    // avoid all sorts of false positives without semantics
    override void visit(TemplateDeclaration) { /* skip */ }
}

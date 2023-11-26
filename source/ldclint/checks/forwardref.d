module ldclint.checks.atproperty;

import ldclint.visitors;
import ldclint.dmd.location;

import dmd.dmodule;
import dmd.declaration;
import dmd.dimport;
import dmd.dsymbol;
import dmd.func;
import dmd.errors;
import dmd.tokens;
import dmd.aggregate;
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

    override void visit(Expression exp)
    {
        // lets skip invalid expressions
        if (!isValid(exp)) return;

        if (exp.op == EXP.error)
        {
            warning(exp.loc, "Expression yields internally to an error");
        }

        // traverse through the AST
        super.visit(exp);
    }

    override void visit(Declaration decl)
    {
        // lets skip invalid declarations
        if (!isValid(decl)) return;

        if (decl.resolvedLinkage() == LINK.default_)
        {
            warning(decl.loc, "Forward reference");
        }

        // traverse through the AST
        super.visit(decl);
    }

    override void visit(AggregateDeclaration ad)
    {
        // lets skip invalid declarations
        if (!isValid(ad)) return;

        if (auto at = ad.aliasthis)
        {
            if (at.isforwardRef() || !at.sym || at.sym.isforwardRef())
            {
                warning(at.loc, "Alias this has a forward reference symbol");
            }
        }

        // traverse through the AST
        super.visit(ad);
    }

    override void visit(Type t)
    {
        // lets skip invalid types
        if (!isValid(t)) return;

        if (t.ty == TY.Terror)
        {
            warning(Loc.initial, "Type `%s` resolves to an error type", t.toChars());
        }

        switch (t.ty)
        {
            case TY.Tident:
            case TY.Ttypeof:
            case TY.Tmixin:
                warning(Loc.initial, "Type `%s` is a forward reference", t.toChars());
                break;
            default: break;
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

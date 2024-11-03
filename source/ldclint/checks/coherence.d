module ldclint.checks.coherence;

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

extern(C++) final class CoherenceCheckVisitor : DFSPluginVisitor
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

        if (auto decl = sym.isDeclaration())
        {
            if (auto fd = decl.isFuncDeclaration())
            {
                if (fd.resolvedLinkage() == LINK.default_)
                {
                    warning(fd.loc, "Forward reference on resolving linkage");
                }
            }

            if (auto vd = decl.isVarDeclaration())
            {
                // this errors if not known
                cast(void)vd.isDataseg();
            }
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

        // traverse through the AST
        super.visit(decl);
    }

    override void visit(AggregateDeclaration ad)
    {
        // lets skip invalid declarations
        if (!isValid(ad)) return;

        if (auto at = ad.aliasthis)
        {
            if (at.isforwardRef() || (at.sym && at.sym.isforwardRef()))
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

        // look for type bugs internally
        t.check();

        switch (t.ty)
        {
            case TY.Tident:
            case TY.Ttypeof:
            case TY.Tmixin:
                warning(Loc.initial, "Type `%s` is a forward reference", t.toChars());
                break;

            case TY.Tstruct:
                auto ts = t.isTypeStruct();
                if (!ts)
                {
                    error(Loc.initial, "Type `%s` is not coherent with it's type class", t.toChars());
                }

                // FIXME: the compiler seem to give wrong information about alias this forward references here

                /*
                if (ts.att == AliasThisRec.fwdref)
                {
                    warning(Loc.initial, "Type struct `%s` has an alias this with a forward reference", t.toChars());
                }
                */

                if (ts.sym && ts.sym.members)
                    goto default;

                break;

            case TY.Terror:
                error(Loc.initial, "Type `%s` resolves to an error type", t.toChars());
                break;
            default:
                // this errors if the size is not known
                cast(void)t.size();
                break;
        }

        // traverse through the AST
        super.visit(t);

        if (auto bt = t.toBasetype())
        {
            if (bt !is t) visit(bt);
        }
        else
        {
            error(Loc.initial, "Type `%s` can't be resolved to the base type", t.toChars());
        }
    }

    // avoid all sorts of false positives without semantics
    override void visit(TemplateDeclaration) { /* skip */ }
}

module ldclint.checks.unused;

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

import std.stdio;
import std.string;

version = printUnvisited;

extern(C++) final class UnusedCheckVisitor : SemanticTimeTransitiveVisitor
{
    alias visit = SemanticTimeTransitiveVisitor.visit;

    static struct Context
    {
        /// currently module being visited
        Module visitingModule;

        /// number of references of a symbol
        size_t[Dsymbol] refs;

        /// number of imports
        size_t[Module] imported;
    }

    /// visit context
    Context context;

    override void visit(Module m)
    {
        // lets skip a module if we already visiting one
        if(context.visitingModule !is null) return;

        context.visitingModule = m;
        scope(exit) context = Context.init;

        if (m.members)
            foreach(sym; *m.members)
                if (sym) sym.accept(this);

        foreach(sym, num; context.refs)
        {
            // skip invalid symbols
            if (!sym) continue;

            // there is references to this symbol
            if (num > 0) continue;

            string prefix;
            if (sym.isFuncDeclaration) prefix = "Function";
            else if (sym.isVarDeclaration) prefix = "Variable";
            else prefix = "Symbol";

            warning(sym.loc, "%s `%s` appears to be unused", prefix.ptr, sym.toChars());
        }
    }

    override void visit(CallExp e)
    {
        // function declaration associated to the call expression
        if (e.f)
            ++context.refs.require(e.f);
        else
            // visit the calling expression otherwise
            e.e1.accept(this);

        // go over the arguments of the call expression
        if (e.arguments)
            foreach(arg; *e.arguments)
                arg.accept(this);
    }

    override void visit(SymbolExp expr)
    {
        ++context.refs.require(expr.var);
    }

    override void visit(Import imp)
    {
        // ignore special object module import
        if (imp.id == Id.object) return;
    }

    override void visit(IntegerExp) { /* skip */ }

    override void visit(Expression e)
    {
        version(printUnvisited) stderr.writefln("expression '%s': %s", e.op, fromStringz(e.toChars()));
        super.visit(e);
    }

    override void visit(Dsymbol s)
    {
        version(printUnvisited) stderr.writefln("symbol '%s': %s", s.kind, fromStringz(s.toChars()));
        super.visit(s);
    }

    override void visit(Statement s)
    {
        version(printUnvisited) stderr.writefln("statement '%s': %s", s.stmt, fromStringz(s.toChars()));
        super.visit(s);
    }

    override void visit(VarDeclaration vd)
    {
        super.visit(vd);

        auto parent = vd.toParent();
        if (parent && parent.isModule())
        {
            final switch(vd.visibility.kind)
            {
                case Visibility.Kind.private_:
                case Visibility.Kind.none:
                    break;

                case Visibility.Kind.protected_:
                case Visibility.Kind.public_:
                case Visibility.Kind.export_:
                case Visibility.Kind.undefined:
                case Visibility.Kind.package_:
                    return;
            }
        }

        context.refs.require(vd);
    }

    override void visit(FuncDeclaration fd)
    {
        // FIXME: Transitive visitor has a bug
        //super.visit(vd);

        if (fd.frequires)
            foreach (frequire; *fd.frequires)
                frequire.accept(this);

        if (fd.fensures)
            foreach (fensure; *fd.fensures)
                fensure.ensure.accept(this);

        if (fd.fbody)
            fd.fbody.accept(this);

        if (fd.parameters)
            foreach (param; *fd.parameters)
                if (param.ident && !param.ident.toString().startsWith("_param_"))
                    param.accept(this);

        if (!fd.isMain && !fd.isCMain)
        {
            final switch(fd.visibility.kind)
            {
                case Visibility.Kind.private_:
                case Visibility.Kind.none:
                    context.refs.require(fd);
                    break;

                case Visibility.Kind.protected_:
                case Visibility.Kind.public_:
                case Visibility.Kind.export_:
                case Visibility.Kind.undefined:
                case Visibility.Kind.package_:
                    break;
            }
        }
    }
}

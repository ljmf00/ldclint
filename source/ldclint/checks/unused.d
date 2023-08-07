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
        // lets skip invalid modules
        if (m is null || !m.md) return;

        // lets skip a module if we already visiting one
        if(context.visitingModule !is null) return;

        context.visitingModule = m;
        scope(exit) context = Context.init;

        if (m.members)
            foreach(sym; *m.members)
                sym.accept(this);

        foreach(sym, num; context.refs)
        {
            // skip invalid symbols
            if (!sym) continue;

            // there is references to this symbol
            if (num > 0) continue;

            warning(sym.loc, "Symbol `%s` appears to be unused", sym.toChars());
        }
    }

    override void visit(CallExp call)
    {
        ++context.refs.require(call.f);
    }

    override void visit(DotVarExp dVarExp)
    {
        ++context.refs.require(dVarExp.var);
    }

    override void visit(FuncExp funcExp)
    {
        context.refs.require(funcExp.fd);
        context.refs.require(funcExp.td);
    }

    override void visit(SymbolExp symExp)
    {
        ++context.refs.require(symExp.var);
    }

    override void visit(Import imp)
    {
        // ignore special object module import
        if (imp.id == Id.object) return;
    }

    override void visit(VarDeclaration vd)
    {
        super.visit(vd);

        context.refs.require(vd);
    }

    override void visit(FuncDeclaration fd)
    {
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

module ldclint.checks.unused;

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

import std.stdio;
import std.string;
import std.array;
import std.range;
import std.bitmanip;

extern(C++) final class UnusedCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    static struct Context
    {
        /// number of references of a symbol
        size_t[void*] refs;

        void addRef(Dsymbol s)
        {
            if (s is null) return;

            this.refs.require(cast(void*)s);
        }

        void incrementRef(Dsymbol s)
        {
            if (s is null) return;

            ++this.refs.require(cast(void*)s);
        }

        /// number of imports
        size_t[Module] imported;

        mixin(bitfields!(
            bool, "insideFunction", 1,
            uint, null,             7,
        ));
    }

    /// visit context
    Context context;

    override void visit(Module m)
    {
        // lets skip invalid modules
        if (!isValid(m)) return;

        super.visit(m);

        foreach(osym, num; context.refs)
        {
            // skip invalid symbols
            if (!osym) continue;

            // there is references to this symbol
            if (num > 0) continue;

            auto sym = cast(Dsymbol)osym;
            assert(sym, "must be a Dsymbol");

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
            context.incrementRef(e.f);
    }

    override void visit(VarExp e)
    {
        if (!isValid(e)) return;

        super.visit(e);

        context.incrementRef(e.var);
    }

    override void visit(SymOffExp e)
    {
        if (!isValid(e)) return;

        super.visit(e);

        context.incrementRef(e.var);
    }

    override void visit(SymbolExp e)
    {
        if (!isValid(e)) return;

        super.visit(e);

        context.incrementRef(e.var);
    }

    override void visit(Import imp)
    {
        // ignore special object module import
        if (imp.id == Id.object) return;
    }

    override void visit(VarDeclaration vd)
    {
        if (!isValid(vd)) return;

        super.visit(vd);

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
                if (context.insideFunction) break;

                return;
        }

        // variables with an underscore are ignored
        if (vd.ident && !vd.ident.toString().startsWith("_"))

        context.addRef(vd);
    }

    override void visit(FuncDeclaration fd)
    {
        // lets skip invalid functions
        if (!isValid(fd)) return;

        context.insideFunction = true;
        scope (exit) context.insideFunction = false;

        if (!fd.isMain && !fd.isCMain)
        {
            final switch(fd.visibility.kind)
            {
                case Visibility.Kind.private_:
                case Visibility.Kind.none:
                    context.addRef(fd);
                    break;

                case Visibility.Kind.protected_:
                case Visibility.Kind.public_:
                case Visibility.Kind.export_:
                case Visibility.Kind.undefined:
                case Visibility.Kind.package_:
                    break;
            }
        }

        // traverse through the AST
        super.visit(fd);
    }
}

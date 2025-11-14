module ldclint.checks.unused;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons;
import std.bitmanip;

enum Metadata = imported!"ldclint.checks".Metadata(
    "unused",
    No.byDefault,
    Yes.allModules,
    100 /* priority */,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    static struct Context
    {
        /// number of references of a symbol
        size_t[void*] refs;

        void addRef(T)(T s)
            if (is(T : DMD.Dsymbol))
        {
            if (s is null) return;

            this.refs.require(cast(void*)s);
        }

        void incrementRef(T)(T s)
            if (is(T : DMD.Dsymbol))
        {
            if (s is null) return;

            ++this.refs.require(cast(void*)s);
        }

        /// number of imports
        size_t[DMD.Module] imported;

        mixin(bitfields!(
            bool, "insideFunction", 1,
            uint, null,             7,
        ));
    }

    /// visit context
    Context context;
    /// scope tracker
    DMD.ScopeTracker scopeTracker;

    override void visit(Querier!(DMD.Module) m)
    {
        // lets skip invalid modules
        if (!m.isValid()) return;

        auto sc = scopeTracker.track(m);
        scope(exit) scopeTracker.untrack(m, sc);

        super.visit(m);

        foreach(osym, num; context.refs)
        {
            // skip invalid symbols
            if (!osym) continue;

            // there is references to this symbol
            if (num > 0) continue;

            auto sym = cast(DMD.Dsymbol)osym;
            assert(sym, "must be a Dsymbol");

            string prefix;
            if (sym.isFuncDeclaration) prefix = "Function";
            else if (sym.isVarDeclaration) prefix = "Variable";
            else prefix = "Symbol";

            warning(sym.loc, "%s `%s` appears to be unused", prefix.ptr, sym.toChars());
        }
    }

    override void visit(Querier!(DMD.CallExp) e)
    {
        if (!e.isValid()) return;

        super.visit(e);

        // function declaration associated to the call expression
        if (e.f)
            context.incrementRef(e.f);
    }

    override void visit(Querier!(DMD.VarExp) e)
    {
        if (!e.isValid()) return;

        super.visit(e);

        context.incrementRef(e.var);
    }

    override void visit(Querier!(DMD.ThisExp) e)
    {
        if (!e.isValid()) return;

        super.visit(e);

        context.incrementRef(e.var);
    }

    override void visit(Querier!(DMD.DotVarExp) e)
    {
        if (!e.isValid()) return;

        super.visit(e);

        context.incrementRef(e.var);
    }

    override void visit(Querier!(DMD.SymOffExp) e)
    {
        if (!e.isValid()) return;

        super.visit(e);

        context.incrementRef(e.var);
    }

    override void visit(Querier!(DMD.SymbolExp) e)
    {
        if (!e.isValid()) return;

        super.visit(e);

        context.incrementRef(e.var);
    }

    override void visit(Querier!(DMD.Import) imp)
    {
        // ignore special object module import
        if (imp.id == DMD.Id.object) return;
    }

    override void visit(Querier!(DMD.VarDeclaration) vd)
    {
        import std.algorithm : startsWith;

        if (!vd.isValid()) return;

        super.visit(vd);

        auto sc = scopeTracker.track(vd);
        scope(exit) scopeTracker.untrack(vd, sc);

        final switch(vd.visibility.kind)
        {
            case DMD.Visibility.Kind.private_:
            case DMD.Visibility.Kind.none:
                break;

            case DMD.Visibility.Kind.protected_:
            case DMD.Visibility.Kind.public_:
            case DMD.Visibility.Kind.export_:
            case DMD.Visibility.Kind.undefined:
            case DMD.Visibility.Kind.package_:
                if (scopeTracker.functionDepth > 0) break;

                return;
        }

        // anonymous variables that doesn't have an identifier are ignored
        if (!vd.ident) return;

        auto strident = vd.ident.toString();
        // variables with an underscore are ignored
        if (strident.startsWith("_")) return;
        // this special variable is ignored
        if (strident == "this") return;

        // TODO: Add tests cases for this
        // FIXME: Use expression lookup table for enums, disable them for now

        // skip temporary variables
        if (vd.isGenerated()) return;
        // skip enums
        if (vd.storage_class & DMD.STC.manifest) return;

        context.addRef(vd);
    }

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        // lets skip invalid functions
        if (!fd.isValid()) return;

        auto sc = scopeTracker.track(fd);
        scope(exit) scopeTracker.untrack(fd, sc);

        if (!fd.isMain && !fd.isCMain)
        {
            final switch(fd.visibility.kind)
            {
                case DMD.Visibility.Kind.private_:
                case DMD.Visibility.Kind.none:
                    context.addRef(fd);
                    break;

                case DMD.Visibility.Kind.protected_:
                case DMD.Visibility.Kind.public_:
                case DMD.Visibility.Kind.export_:
                case DMD.Visibility.Kind.undefined:
                case DMD.Visibility.Kind.package_:
                    break;
            }
        }

        // traverse through the AST
        super.visit(fd);
    }
}

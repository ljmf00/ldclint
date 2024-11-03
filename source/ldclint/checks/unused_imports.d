module ldclint.checks.unused_imports;

import ldclint.visitors;
import ldclint.scopetracker;

import dmd.common.outbuffer: OutBuffer;
import dmd.dmodule;
import dmd.declaration;
import dmd.dimport;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.func;
import dmd.errors;
import dmd.id;
import dmd.expression;
import dmd.statement;
import dmd.mtype;
import dmd.astenums;

extern(C++) final class UnusedImportsCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    static struct Context
    {
        /// number of references of a module
        size_t[void*] refs;
        // if a module was publicly imported
        bool[void*] is_public;

        void addRef(Import imp)
        {
            if (imp is null || imp.mod is null) return;

            this.refs.require(cast(void*)imp.mod);
            this.is_public.require(cast(void*)imp.mod, imp.visibility > Visibility(Visibility.Kind.private_));
        }

        void incrementRef(Dsymbol s)
        {
            if (s is null || s.getModule() is null) return;

            ++this.refs.require(cast(void*)s.getModule());
        }
    }

    /// visit context
    Context[void*] ctx;
    /// scope tracker
    ScopeTracker scopeTracker;

    Module* currentModule = null;

    ref Context context() {
        return ctx.require(cast(void*)currentModule);
    }
    override void visit(Module m)
    {
        // lets skip invalid modules
        if (!isValid(m)) return;

        auto prevModule = this.currentModule;
        this.currentModule = &m;
        auto sc = scopeTracker.track(m);
        scope(exit) scopeTracker.untrack(m, sc);

        super.visit(m);

        foreach(omod, num; context.refs)
        {
            // skip invalid modules
            if (!omod) continue;

            // there are references to this module
            if (num > 0) continue;

            // symbol comes from a module that was not imported explicitly
            // this is actually redudant, since the previous clause will
            // always be true in this case
            if (!(omod in context.is_public)) continue;

            // module is imported publically
            if (context.is_public[omod]) continue;

            auto mod = cast(Module)omod;
            assert(mod, "must be a Module");

            OutBuffer buf;
            mod.fullyQualifiedName(buf);
            buf.writeByte(0);
            warning(mod.loc, "Imported module `%s` appears to be unused", buf.extractData);
        }
        this.currentModule = prevModule;
    }

    override void visit(CallExp e)
    {
        if (!isValid(e)) return;

        super.visit(e);

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

    override void visit(ThisExp e)
    {
        if (!isValid(e)) return;

        super.visit(e);

        context.incrementRef(e.var);
    }

    override void visit(DotVarExp e)
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

    override void visit(ScopeExp e) {
        if (!isValid(e)) return;

        super.visit(e);

        context.incrementRef(e.sds);
    }

    override void visit(TemplateInstance ti) {
        if (!isValid(ti)) return;

        super.visit(ti);

        context.incrementRef(ti.tempdecl);
    }

    override void visit(TemplateMixin tm) {
        if (!isValid(tm)) return;

        super.visit(tm);

        context.incrementRef(tm.tempdecl);
    }

    override void visit(Type t) {
        if (!isValid(t)) return;

        super.visit(t);

    }

    override void visit(TypeStruct t)
    {
        if (!isValid(t)) return;

        super.visit(t);

        context.incrementRef(t.sym);
    }

    override void visit(TypeClass t)
    {
        if (!isValid(t)) return;

        super.visit(t);

        context.incrementRef(t.sym);
    }

    override void visit(Import imp)
    {
        // ignore special object module import
        if (imp.id == Id.object) return;

        context.addRef(imp);
    }
}

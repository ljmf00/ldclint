module ldclint.checks.stack;

import ldclint.options;
import ldclint.visitors;
import ldclint.scopetracker;
import ldclint.dmd.astutility;

import dmd.func;
import dmd.declaration;
import dmd.dtemplate;
import dmd.errors;
import dmd.astenums;
import dmd.mtype;

extern(C++) final class StackCheckVisitor : DFSPluginVisitor
{
    alias visit = DFSPluginVisitor.visit;

    this(Options* options)
    {
        this.options = options;
    }

    // linter options
    Options* options;

    /// scope tracker
    ScopeTracker scopeTracker;

    override void visit(FuncDeclaration fd)
    {
        // lets skip invalid functions
        if (!isValid(fd)) return;

        auto sc = scopeTracker.track(fd);
        scope(exit) scopeTracker.untrack(fd, sc);

        // traverse through the AST
        super.visit(fd);
    }

    override void visit(VarDeclaration vd)
    {
        // lets skip invalid variable declarations
        if (!isValid(vd)) return;

        scope(exit)
        {
            // traverse through the AST
            super.visit(vd);
        }

        // not inside functions
        if (scopeTracker.functionDepth <= 0) return;

        // lets skip global variables inside functions
        if (vd.storage_class & STC.gshared || vd.storage_class & STC.static_)
            return;

        // lets skip extern symbols
        if (vd.storage_class & STC.extern_) return;

        // lets skip fields inside structs/classes
        if (vd.storage_class & STC.field) return;

        // lets skip references
        if (vd.storage_class & STC.ref_) return;

        // lets skip template parameters
        if (vd.storage_class & STC.templateparameter) return;

        Type type = vd.type;
        if (type is null) type = vd.originalType;
        if (type is null) return;

        auto rsz = querier(vd.type).size;
        // unresolved size
        if (!rsz.resolved) return;

        auto sz = rsz.get;

        if (sz != size_t.max && sz > options.maxVariableStackSize)
        {
            warning(vd.loc, "Stack variable `%s` is big (size: %lu, limit: %lu)", vd.toChars(), type.size, options.maxVariableStackSize);
        }
    }

    // avoid all sorts of false positives without semantics
    override void visit(TemplateDeclaration) { /* skip */ }
}

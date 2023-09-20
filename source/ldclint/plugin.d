module ldclint.plugin;

import ldclint.options;
import ldclint.dparseast;

import dmd.dmodule : Module;
import dmd.errors;

import ldclint.dmd.location;

import ldclint.checks.unused;
import ldclint.checks.structs_ctor_postblit;
import ldclint.checks.atproperty;
import ldclint.checks.redundant;
import ldclint.checks.stack;

__gshared Options options;

pragma(crt_constructor)
extern(C) void ldclint_initialize()
{
    tryParseOptions(options);
}

export extern(C) void runSemanticAnalysis(Module m)
{
    if (!m) return;

    if (options.parserCheck)             dparseModule(options, m);

    if (options.unusedCheck)             m.accept(new UnusedCheckVisitor());
    if (options.structCtorPostblitCheck) m.accept(new StructCtorPostblitCheckVisitor());
    if (options.atPropertyCheck)         m.accept(new AtPropertyCheckVisitor());
    if (options.redundantCheck)          m.accept(new RedundantCheckVisitor());
    if (options.stackCheck)              m.accept(new StackCheckVisitor(&options));
}

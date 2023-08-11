module ldclint.plugin;

import dmd.dmodule : Module;
import dmd.errors;

import ldclint.dmd.location;

import ldclint.checks.unused;
import ldclint.checks.structs_ctor_postblit;

export extern(C) void runSemanticAnalysis(Module m)
{
    if (!m) return;

    m.accept(new UnusedCheckVisitor());
    m.accept(new StructCtorPostblitCheckVisitor());
}

module ldclint.plugin;

import dmd.dmodule : Module;
import dmd.errors;
import dmd.location;

import ldclint.checks.unused;

export extern(C) void runSemanticAnalysis(Module m)
{
    if (!m) return;

    m.accept(new UnusedCheckVisitor());
}

module ldclint.plugin;

import std.regex;

import ldclint.options;
import ldclint.dparseast;

import dmd.dmodule : Module;
import dmd.errors;

import ldclint.dmd.location;

import ldclint.checks.unused;
import ldclint.checks.structs_dtor_postblit;
import ldclint.checks.atproperty;
import ldclint.checks.redundant;
import ldclint.checks.stack;
import ldclint.checks.mayoverflow;
import ldclint.checks.boolbitwise;
import ldclint.checks.coherence;
import ldclint.checks.susderef;

import ldclint.visitors;

__gshared Options options;

pragma(crt_constructor)
extern(C) void ldclint_initialize()
{
    tryParseOptions(options);
}

export extern(C) void runSemanticAnalysis(Module m)
{
    if (!m) return;

    auto filename = cast(immutable)m.srcfile.toString();
    foreach (e; options.excludes)
    {
        // skip excluded files
        if (filename.matchFirst(e)) return;
    }

    if (options.parserCheck)             dparseModule(options, m, filename);
    if (options.debug_)                  m.accept(new DFSPluginVisitor());

    if (options.unusedCheck)             m.accept(new UnusedCheckVisitor());
    if (options.mayOverflowCheck)        m.accept(new MayOverflowCheckVisitor());
    if (options.structDtorPostblitCheck) m.accept(new StructDtorPostblitCheckVisitor());
    if (options.boolBitwiseCheck)        m.accept(new BoolBitwiseCheckVisitor());
    if (options.coherenceCheck)          m.accept(new CoherenceCheckVisitor());
    if (options.atPropertyCheck)         m.accept(new AtPropertyCheckVisitor());
    if (options.redundantCheck)          m.accept(new RedundantCheckVisitor());
    if (options.suspiciousDerefCheck)    m.accept(new SuspiciousDerefCheckVisitor());
    if (options.stackCheck)              m.accept(new StackCheckVisitor(&options));
}

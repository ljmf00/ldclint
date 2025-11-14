module ldclint.plugin;

import ldclint.checks;

import std.typecons : Flag, Yes, No;

mixin template plugin(Checks...)
{
    import DMD = ldclint.dmd;

    static struct Options
    {
        static foreach(Check; Checks)
        {
            @(Check.Metadata)
            mixin(
                `Flag!"enabled" `,
                Check.Metadata.varName, ` = `,
                Check.Metadata.byDefault ? "Yes" : "No",
                ".enabled;",
            );
        }

        void parse(string[] args)
        {
            import std.string : strip;

            foreach(arg; args)
            {
LargsSwitch:
                switch(arg.strip())
                {
                    case "-Wall":
                        static foreach(Check; Checks)
                            mixin("this.", Check.Metadata.varName, " = Yes.enabled;");
                        break LargsSwitch;

                    case "-Wno-all":
                        static foreach(Check; Checks)
                            mixin("this.", Check.Metadata.varName, " = No.enabled;");
                        break LargsSwitch;

                    static foreach(Check; Checks)
                    {
                        case "-W" ~ Check.Metadata.name:
                            mixin("this.", Check.Metadata.varName, " = Yes.enabled;");
                            break LargsSwitch;

                        case "-Wno-" ~ Check.Metadata.name:
                            mixin("this.", Check.Metadata.varName, " = No.enabled;");
                            break LargsSwitch;
                    }

                    default: break;
                }
            }
        }
    }


    __gshared Options options;

    pragma(crt_constructor)
    extern(C) void ldclint_initialize()
    {
        import std.string : split;
        import std.process : environment;

        auto args = environment.get("LDCLINT_FLAGS", null).split();
        options.parse(args);
    }

    export extern(C) void runSemanticAnalysis(DMD.Module m)
    {
        auto filename = cast(immutable)m.srcfile.toString();

        import ldclint.dparse : dparseModule;
        dparseModule(
            options.parser ? Yes.parserErrors : No.parserErrors,
            m,
            filename,
        );

        import ldclint.utils.querier : querier;
        static foreach(Check; Checks)
        {
            if (mixin("options.", Check.Metadata.varName))
            {
                auto check = new Check.Check();
                check.visit(querier(m));
            }
        }
    }
}

mixin plugin!(
    imported!"ldclint.checks.atproperty",
    imported!"ldclint.checks.structs_dtor_postblit",
    imported!"ldclint.checks.unused",
    imported!"ldclint.checks.redundant",
    imported!"ldclint.checks.parser",
    imported!"ldclint.checks.alignment",
    imported!"ldclint.checks.mayoverflow",
);

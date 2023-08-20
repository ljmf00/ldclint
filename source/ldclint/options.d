module ldclint.options;

import std.exception;
import std.process;
import std.array;

class InvalidOptionsException : Exception
{
    ///
    mixin basicExceptionCtors;
}

struct Options
{
    /// whether to run unused check
    bool unusedCheck = true;

    /// whether to run the struct ctor/postblit check
    bool structCtorPostblitCheck = true;

    /// whether to run parser checks
    bool parserCheck = true;

    /// whether to warn about @property usage
    bool atPropertyCheck = false;

    /// whether to warn about redundancy
    bool redundantCheck = true;
}

void setAll(ref Options options, bool value)
{
    static foreach(i, _; Options.tupleof)
    {
        static if (is(typeof(_) == bool))
            options.tupleof[i] = value;
    }
}

void tryParseOptions(out Options options)
{
    auto args = environment.get("LDCLINT_FLAGS", null).split();

    while(args.length)
    {
        switch(args.front)
        {
            case "-Wall":    options.setAll(true);  break;
            case "-Wno-all": options.setAll(false); break;

            case "-Wunused":    options.unusedCheck = true;  break;
            case "-Wno-unused": options.unusedCheck = false; break;

            case "-Wparser":    options.parserCheck = true;  break;
            case "-Wno-parser": options.parserCheck = false; break;

            case "-Wstruct-ctorpostblit":    options.structCtorPostblitCheck = true;  break;
            case "-Wno-struct-ctorpostblit": options.structCtorPostblitCheck = false; break;

            case "-Watproperty":    options.atPropertyCheck = true;  break;
            case "-wno-atproperty": options.atPropertyCheck = false; break;

            case "-Wredundant":    options.redundantCheck = true;  break;
            case "-Wno-redundant": options.redundantCheck = false; break;

            default:
                throw new InvalidOptionsException(args.front);
        }

        args.popFront();
    }
}

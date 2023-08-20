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

            case "-Wstruct-ctorpostblit":    options.structCtorPostblitCheck = true;  break;
            case "-Wno-struct-ctorpostblit": options.structCtorPostblitCheck = false; break;

            default:
                throw new InvalidOptionsException(args.front);
        }

        args.popFront();
    }
}

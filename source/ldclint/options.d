module ldclint.options;

import std.exception;
import std.process;
import std.array;
import std.string;
import std.conv : to;

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

    /// whether to warn about stack polution (huge variables, ...)
    bool stackCheck = true;

    /// max variable stack size;
    size_t maxVariableStackSize = 256;

    /// debug plugin (dummy AST traversal, ...)
    bool debug_ = false;
}

void setAll(ref Options options, bool value)
{
    static foreach(i, _; Options.tupleof)
    {
        static if (is(typeof(_) == bool) && __traits(identifier, options.tupleof[i]).endsWith("Check"))
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
            case "--debug": options.debug_ = true;  break;

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

            case "-Wstack":        options.stackCheck = true;  break;
            case "-Wno-stack":     options.stackCheck = false; break;

            case "--max-var-stack-size":
                auto argName = args.front;
                args.popFront();

                if (args.empty) throw new InvalidOptionsException("expected a number argument for " ~ argName);

                options.maxVariableStackSize = args.front.to!size_t;
                break;

            default:
                throw new InvalidOptionsException(args.front);
        }

        args.popFront();
    }
}

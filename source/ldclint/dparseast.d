module ldclint.dparseast;

import ldclint.options;

import dparse.rollback_allocator : RollbackAllocator;
import dparse.parser;
import dparse.lexer;
import dparse.ast;
import dparse.formatter;

import ldclint.dmd.location;
import dmd.errors;
static import dmd.dmodule;

import std.conv : to;
import std.string : toStringz;

private __gshared Module[void*] dparseMap;

Module dparseModule(ref Options options, dmd.dmodule.Module mod, string filename)
{
    if (!mod) return null;

    auto omod = cast(void*)mod;
    if (auto m = omod in dparseMap) return *m;

    static ubyte[] skipBOM(ubyte[] data)
    {
        if (data.length >= 3 && data[0 .. 3] == "\xef\xbb\xbf")
            return data[3 .. $];

        return data;
    }

    RollbackAllocator rba;
    StringCache cache = StringCache(StringCache.defaultBucketCount);
    LexerConfig config = {
        fileName       : filename,
        stringBehavior : StringBehavior.source,
    };

    auto source = skipBOM(cast(ubyte[])mod.src);
    auto tokens = getTokensForParser(source, config, &cache);

    void outputError(
        string fileName,
        size_t lineNumber,
        size_t columnNumber,
        string message,
        bool err,
    )
    {
        if (options.parserCheck)
        {
            auto loc = Loc(toStringz(fileName), lineNumber.to!uint, columnNumber.to!uint);
            if (err) error(loc, toStringz(message));
            else     warning(loc, toStringz(message));
        }
    }

    return dparseMap[omod] = parseModule(tokens, config.fileName, &rba, &outputError);
}

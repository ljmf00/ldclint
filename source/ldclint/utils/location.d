module ldclint.utils.location;

import DMD = ldclint.dmd;

import std.string;

struct Location
{
    this(ref inout(DMD.Loc) loc)
    {
        this.filename = fromStringz(loc.filename);
        this.lineno = loc.linnum;
        this.charno = loc.charnum;

        static if (__traits(hasMember, loc, "fileIndex"))
            this.dmdFileIdx = __traits(getMember, loc, "fileIndex");
    }

    const(char)[] filename;
    size_t lineno;
    size_t charno;

    static if (__traits(hasMember, DMD.Loc, "fileIndex"))
        private uint dmdFileIdx = 0;
}

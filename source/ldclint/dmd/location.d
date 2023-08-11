module ldclint.dmd.location;

static if (__traits(compiles, { import dmd.location; }))
    public import dmd.location;
else
    public import dmd.globals;

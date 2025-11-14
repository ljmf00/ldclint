module ldclint.dmd;

///////////////////////////////////////////////////////////////////////////////

public import ldclint.dmd.ast;
public import ldclint.dmd.visitor;
public import ldclint.dmd.scopetracker;

///////////////////////////////////////////////////////////////////////////////

import std.meta;

static if(__VERSION__ >= 2101)
    alias AssignExpSeq = AliasSeq!(
        BlitExp,
        ConstructExp,
        LoweredAssignExp,
    );
else
    alias AssignExpSeq = AliasSeq!(
        BlitExp,
        ConstructExp,
    );

static if (__VERSION__ >= 2101)
    alias DsymbolSeq = AliasSeq!(
        LabelDsymbol,
        OverloadSet,
        AliasThis,
        Declaration,
        ScopeDsymbol,
        Import,
        DebugSymbol,
        VersionSymbol,
        CAsmDeclaration,
    );
else
    alias DsymbolSeq = AliasSeq!(
        LabelDsymbol,
        OverloadSet,
        AliasThis,
        Declaration,
        ScopeDsymbol,
        Import,
        DebugSymbol,
        VersionSymbol,
    );

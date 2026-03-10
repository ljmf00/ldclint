module ldclint.checks.ctags;

import ldclint.utils.querier : Querier, querier;

import DMD = ldclint.dmd;

import std.typecons;
import std.array;
import std.algorithm;
import std.string;

enum Metadata = imported!"ldclint.checks".Metadata(
    "ctags",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    /// A single ctags entry
    static struct TagEntry
    {
        const(char)[] name;
        const(char)[] file;
        size_t line;
        char kind;
        const(char)[] scopeKind;
        const(char)[] scopeName;

        /// Format as a standard ctags line
        string toString() const
        {
            auto app = appender!string;
            app ~= name;
            app ~= '\t';
            app ~= file;
            app ~= '\t';

            // Use line number as tag address
            import std.conv : to;
            app ~= line.to!string;
            app ~= `;"`;
            app ~= '\t';
            app ~= kind;

            if (scopeKind.length && scopeName.length)
            {
                app ~= '\t';
                app ~= scopeKind;
                app ~= ':';
                app ~= scopeName;
            }

            return app[];
        }
    }

    /// Collected tag entries
    Appender!(TagEntry[]) tags;

    /// Scope stack for tracking containing declarations
    const(char)[][] scopeStack;
    char[] scopeKindStack;

    override void visit(Querier!(DMD.Module) m)
    {
        if (!m.isValid()) return;

        super.visit(m);

        writeTags();
    }

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        if (!fd.isValid()) return;

        addTag(fd, 'f');

        pushScope(fd, "function");
        scope(exit) popScope();

        super.visit(fd);
    }

    override void visit(Querier!(DMD.VarDeclaration) vd)
    {
        if (!vd.isValid()) return;

        // skip compiler-generated variables (__key, __r, etc.)
        if (vd.isGenerated()) { super.visit(vd); return; }

        // skip 'this' parameters
        if (vd.ident && vd.ident.toString() == "this") { super.visit(vd); return; }

        // Use 'm' (member) if inside a struct/class/union, 'v' otherwise
        char kind = scopeKindStack.length > 0 && (
            scopeKindStack[$ - 1] == 's' ||
            scopeKindStack[$ - 1] == 'c' ||
            scopeKindStack[$ - 1] == 'u'
        ) ? 'm' : 'v';

        addTag(vd, kind);

        super.visit(vd);
    }

    override void visit(Querier!(DMD.StructDeclaration) sd)
    {
        if (!sd.isValid()) return;

        addTag(sd, 's');

        pushScope(sd, "struct");
        scope(exit) popScope();

        super.visit(sd);
    }

    override void visit(Querier!(DMD.ClassDeclaration) cd)
    {
        if (!cd.isValid()) return;

        addTag(cd, 'c');

        pushScope(cd, "class");
        scope(exit) popScope();

        super.visit(cd);
    }

    override void visit(Querier!(DMD.InterfaceDeclaration) id)
    {
        if (!id.isValid()) return;

        addTag(id, 'c');

        pushScope(id, "class");
        scope(exit) popScope();

        super.visit(id);
    }

    override void visit(Querier!(DMD.EnumDeclaration) ed)
    {
        if (!ed.isValid()) return;

        addTag(ed, 'g');

        pushScope(ed, "enum");
        scope(exit) popScope();

        super.visit(ed);
    }

    override void visit(Querier!(DMD.EnumMember) em)
    {
        if (!em.isValid()) return;

        addTag(em, 'e');
    }

    override void visit(Querier!(DMD.UnionDeclaration) ud)
    {
        if (!ud.isValid()) return;

        addTag(ud, 'u');

        pushScope(ud, "union");
        scope(exit) popScope();

        super.visit(ud);
    }

    override void visit(Querier!(DMD.TemplateDeclaration) td)
    {
        if (!td.isValid()) return;

        addTag(td, 't');

        pushScope(td, "template");
        scope(exit) popScope();

        super.visit(td);
    }

    override void visit(Querier!(DMD.AliasDeclaration) ad)
    {
        if (!ad.isValid()) return;

        addTag(ad, 'a');

        super.visit(ad);
    }

    override void visit(Querier!(DMD.Import) imp)
    {
        if (imp.astNode is null) return;

        // skip the implicit object import
        if (imp.id == DMD.Id.object) return;

        addTag(imp, 'i');
    }

    override void visit(Querier!(DMD.CtorDeclaration) d)
    {
        if (!d.isValid()) return;

        addTagRaw("this", d, 'f');

        pushScope(d, "function");
        scope(exit) popScope();

        super.visit(d);
    }

    override void visit(Querier!(DMD.DtorDeclaration) d)
    {
        if (!d.isValid()) return;

        addTagRaw("~this", d, 'f');

        pushScope(d, "function");
        scope(exit) popScope();

        super.visit(d);
    }

    override void visit(Querier!(DMD.UnitTestDeclaration) d)
    {
        if (d.astNode is null) return;

        addTagRaw("unittest", d, 'U');

        if (d.fbody)
            d.fbody.accept(dmdVisitorProxy);
    }

    // ─── helpers ────────────────────────────────────────────

    private void addTag(T)(T node, char kind)
    {
        if (node.astNode is null) return;

        auto ident = node.ident;
        if (ident is null) return;
        if (ident.isAnonymous()) return;

        auto name = ident.toString();
        if (!name.length) return;

        addTagRaw(name, node, kind);
    }

    private void addTagRaw(T)(const(char)[] name, T node, char kind)
    {
        auto file = fromStringz(node.loc.filename);
        if (!file.length) return;

        TagEntry entry;
        entry.name = name;
        entry.file = file;
        entry.line = node.loc.linnum;
        entry.kind = kind;

        if (scopeStack.length > 0)
        {
            switch (scopeKindStack[$ - 1])
            {
                case 's': entry.scopeKind = "struct"; break;
                case 'c': entry.scopeKind = "class"; break;
                case 'u': entry.scopeKind = "union"; break;
                case 'g': entry.scopeKind = "enum"; break;
                case 't': entry.scopeKind = "template"; break;
                case 'f': entry.scopeKind = "function"; break;
                default: break;
            }
            entry.scopeName = scopeStack[$ - 1];
        }

        tags ~= entry;
    }

    private void pushScope(T)(T node, string scopeKindStr)
    {
        auto ident = node.ident;
        if (ident is null || ident.isAnonymous())
        {
            scopeStack ~= "";
            scopeKindStack ~= '?';
            return;
        }

        char kindChar;
        if (scopeKindStr == "struct") kindChar = 's';
        else if (scopeKindStr == "class") kindChar = 'c';
        else if (scopeKindStr == "union") kindChar = 'u';
        else if (scopeKindStr == "enum") kindChar = 'g';
        else if (scopeKindStr == "template") kindChar = 't';
        else if (scopeKindStr == "function") kindChar = 'f';
        else kindChar = '?';

        scopeStack ~= ident.toString();
        scopeKindStack ~= kindChar;
    }

    private void popScope()
    {
        scopeStack = scopeStack[0 .. $ - 1];
        scopeKindStack = scopeKindStack[0 .. $ - 1];
    }

    private void writeTags()
    {
        import std.stdio : File;

        auto sortedTags = tags[].array;
        sortedTags.sort!((a, b) => a.name < b.name);

        auto f = File("tags", "w");

        // ctags header
        f.writeln(`!_TAG_FILE_FORMAT	2	/extended format; --format=2/`);
        f.writeln(`!_TAG_FILE_SORTED	1	/0=unsorted, 1=sorted, 2=foldcase/`);
        f.writeln(`!_TAG_PROGRAM_NAME	ldclint	//`);

        foreach (ref tag; sortedTags)
            f.writeln(tag.toString());
    }
}

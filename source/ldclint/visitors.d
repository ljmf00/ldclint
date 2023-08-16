module ldclint.visitors;

import dmd.ast_node;
import dmd.astenums;
import dmd.aggregate;
import dmd.astcodegen;
import dmd.attrib;
import dmd.dclass;
import dmd.declaration;
import dmd.denum;
import dmd.dimport;
import dmd.dmodule;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.errors;
import dmd.expression;
import dmd.func;
import dmd.id;
import dmd.mtype;
import dmd.statement;
import dmd.staticassert;
import dmd.visitor;
import dmd.arraytypes;
import dmd.nspace;
import dmd.init;
import dmd.cond;

import dmd.root.rootobject;
import dmd.root.array;

import std.stdio;
import std.string;
import std.range;
import std.array;

// debug = ast;

extern (C++) class SafeTransitiveVisitor : SemanticTimePermissiveVisitor
{
    ///
    alias visit = SemanticTimePermissiveVisitor.visit;

    /// level of the accepted visitor
    debug (ast) ptrdiff_t level;

    private enum string incrementLevelMixin = q{
        debug (ast)
            stderr.writeln(' '.repeat(level), "> Calling `", (&__traits(parent, {})).stringof, typeof(__traits(parameters)).stringof, "`");
        debug (ast) ++level;
        scope(exit) debug (ast) --level;
    };

    private enum string invalidReturnMixin = q{
        debug (ast) stderr.writeln(' '.repeat(level), "? invalid");
        return;
    };

    protected extern(D) final void traverse(RootObject oarg)
    {
        mixin(incrementLevelMixin);

        if (auto t = isType(oarg))
        {
            traverse(t);
        }
        else if (auto e = isExpression(oarg))
        {
            e.accept(this);
        }
        else if (auto v = isTuple(oarg))
        {
            auto args = &v.objects;
            foreach (arg; *args)
                traverse(arg);
        }
    }

    protected extern(D) final void traverse(TemplateInstance ti)
    {
        mixin(incrementLevelMixin);

        if (!ti.tiargs)
            return;
        foreach (arg; *ti.tiargs)
        {
            traverse(arg);
        }
    }

    protected extern(D) final void traverse(TemplateParameters* parameters)
    {
        mixin(incrementLevelMixin);

        if (!parameters || !parameters.length)
            return;
        foreach (p; *parameters)
            p.accept(this);
    }

    protected extern(D) final void traverse(AttribDeclaration ad)
    {
        mixin(incrementLevelMixin);

        if (ad.decl)
            foreach (d; *ad.decl)
                if (d)
                    d.accept(this);
    }

    protected extern(D) final void traverse(TypeQualified t)
    {
        mixin(incrementLevelMixin);

        foreach (id; t.idents)
        {
            switch(id.dyncast()) with(DYNCAST)
            {
            case dsymbol:
                (cast(TemplateInstance)id).accept(this);
                break;
            case expression:
                (cast(Expression)id).accept(this);
                break;
            case type:
                (cast(Type)id).accept(this);
                break;
            default:
                break;
            }
        }
    }

    protected extern(D) final void traverse(Type t)
    {
        mixin(incrementLevelMixin);

        if (!t)
            return;
        if (auto tf = t.isTypeFunction())
        {
            traverse(tf, null);
            return;
        }
        else
            t.accept(this);
    }

    protected extern(D) final void traverse(TypeFunction t, TemplateDeclaration td = null)
    {
        mixin(incrementLevelMixin);

        if (t.next)
            traverse(t.next);
        if (td)
        {
            foreach (p; *td.origParameters)
                p.accept(this);
        }

        auto params = t.parameterList.parameters;
        if(params)
            foreach(p; *params)
                p.accept(this);
    }

    protected extern(D) final void traverse(VarDeclaration vd)
    {
        mixin(incrementLevelMixin);

        if (vd.type)
            traverse(vd.type);
        if (vd._init)
        {
            if (auto ie = vd._init.isExpInitializer())
            {
                if (auto ce = ie.exp.isConstructExp())
                    ce.e2.accept(this);
                else if (auto be = ie.exp.isBlitExp())
                    be.e2.accept(this);
                else
                    vd._init.accept(this);
            }
            else
                vd._init.accept(this);
        }
    }

    protected extern(D) final void traverse(Array!(Parameter)* params)
    {
        mixin(incrementLevelMixin);

        if (params is null) return;

        foreach (p; *params)
            if (p)
                p.accept(this);
    }

    protected extern(D) final void traverse(Array!(Expression)* expressions, Expression basis = null)
    {
        mixin(incrementLevelMixin);

        if (expressions is null) return;

        foreach (el; *expressions)
        {
            if (!el)
                el = basis;
            if (el)
                el.accept(this);
        }
    }

    protected extern(D) final void traverse(FuncDeclaration fd)
    {
        mixin(incrementLevelMixin);

        if (fd.frequires)
            foreach (frequire; *fd.frequires)
                frequire.accept(this);

        if (fd.fensures)
            foreach (fensure; *fd.fensures)
                fensure.ensure.accept(this);

        if (fd.fbody)
            fd.fbody.accept(this);

        if (fd.parameters)
            foreach (param; *fd.parameters)
                if (param)
                    param.accept(this);
    }

    void traverse(ClassDeclaration d)
    {
        mixin(incrementLevelMixin);

        if (!d || !d.baseclasses.length)
            return;
        foreach (b; *d.baseclasses)
            traverse(b.type);
    }

    bool traverse(TemplateDeclaration d)
    {
        mixin(incrementLevelMixin);

        if (!d.members || d.members.length != 1)
            return false;
        Dsymbol onemember = (*d.members)[0];
        if (onemember.ident != d.ident)
            return false;

        if (FuncDeclaration fd = onemember.isFuncDeclaration())
        {
            assert(fd.type);
            traverse(fd.type.isTypeFunction(), d);
            if (d.constraint)
                d.constraint.accept(this);
            traverse(fd);

            return true;
        }

        if (AggregateDeclaration ad = onemember.isAggregateDeclaration())
        {
            traverse(d.parameters);
            if (d.constraint)
                d.constraint.accept(this);
            traverse(ad.isClassDeclaration());

            if (ad.members)
                foreach (s; *ad.members)
                    s.accept(this);

            return true;
        }

        if (VarDeclaration vd = onemember.isVarDeclaration())
        {
            if (d.constraint)
                return false;
            if (vd.type)
                traverse(vd.type);
            traverse(d.parameters);
            if (vd._init)
            {
                // note similarity of this code with visitVarDecl()
                if (auto ie = vd._init.isExpInitializer())
                {
                    if (auto ce = ie.exp.isConstructExp())
                        ce.e2.accept(this);
                    else if (auto be = ie.exp.isBlitExp())
                        be.e2.accept(this);
                    else
                        vd._init.accept(this);
                }
                else
                    vd._init.accept(this);

                return true;
            }
        }

        return false;
    }

    override void visit(StructDeclaration sd)
    {
        // lets skip invalid structs
        if (!isValid(sd)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        // === traversal ===

        if (sd.members)
            foreach (s; *sd.members)
                s.accept(this);
    }

    override void visit(FuncDeclaration fd)
    {
        // lets skip invalid functions
        if (!isValid(fd)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(fd);
    }

    override void visit(Module m)
    {
        // lets skip invalid modules
        if (!isValid(m)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        // === traversal ===

        if (m.members)
            foreach(sym; *m.members)
                if (sym)
                    sym.accept(this);
    }

    override void visit(CompoundStatement s)
    {
        // lets skip invalid statements
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.statements)
            foreach (sx; *s.statements)
                if (sx)
                    sx.accept(this);
    }

    override void visit(ExpStatement s)
    {
        // lets skip invalid statements
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.exp)
        {
            if (auto de = s.exp.isDeclarationExp())
                de.declaration.accept(this);
            else
                s.exp.accept(this);
        }
    }

    override void visit(VisibilityDeclaration vd)
    {
        if (!isValid(vd)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(vd);
    }

    override void visit(AliasDeclaration ad)
    {
        // lets skip invalid declarations
        if (!isValid(ad)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (ad.aliassym)
            ad.aliassym.accept(this);
        else
            traverse(ad.type);
    }

    override void visit(PragmaStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.args)
            foreach (a; *s.args)
                if (a)
                    a.accept(this);

        if (s._body)
            s._body.accept(this);
    }

    override void visit(StaticAssertStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.sa.accept(this);
    }

    override void visit(SwitchStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.condition.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(CaseStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.exp.accept(this);
        s.statement.accept(this);
    }

    override void visit(CaseRangeStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.first.accept(this);
        s.last.accept(this);
        s.statement.accept(this);
    }

    override void visit(DefaultStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.statement.accept(this);
    }

    override void visit(GotoCaseStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.exp)
            s.exp.accept(this);
    }

    override void visit(ReturnStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.exp)
            s.exp.accept(this);
    }

    override void visit(SynchronizedStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.exp)
            s.exp.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(WithStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.exp.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(TryCatchStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s._body)
            s._body.accept(this);
        foreach (c; *s.catches)
            visit(c);
    }

    override void visit(TryFinallyStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s._body.accept(this);
        s.finalbody.accept(this);
    }

    override void visit(ScopeGuardStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.statement.accept(this);
    }

    override void visit(ThrowStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.exp.accept(this);
    }

    override void visit(LabelStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.statement)
            s.statement.accept(this);
    }

    override void visit(ImportStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (imp; *s.imports)
            imp.accept(this);
    }

    override void visit(VarDeclaration vd)
    {
        // lets skip invalid nodes
        if (!isValid(vd)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(vd);
    }

    /*override*/ void visit(Catch c)
    {
        // lets skip invalid nodes
        if (!isValid(c)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (c.type)
            traverse(c.type);
        if (c.handler)
            c.handler.accept(this);
    }

    override void visit(CompileStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.exps)
            foreach (e; *s.exps)
                if (e)
                    e.accept(this);
    }

    override void visit(CompoundDeclarationStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (sx; *s.statements)
        {
            if (!sx)
                continue;
            if (auto ds = sx.isExpStatement())
            {
                if (auto de = ds.exp.isDeclarationExp())
                {
                    auto d = de.declaration;
                    assert(d.isDeclaration());
                    if (auto v = d.isVarDeclaration())
                        traverse(v);
                    else
                        d.accept(this);
                }
            }
        }
    }

    override void visit(ScopeStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.statement)
            s.statement.accept(this);
    }

    override void visit(WhileStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.condition.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(DoStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s._body)
            s._body.accept(this);
        s.condition.accept(this);
    }

    override void visit(ForStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s._init)
            s._init.accept(this);
        if (s.condition)
            s.condition.accept(this);
        if (s.increment)
            s.increment.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ForeachStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (p; *s.parameters)
            if (p.type)
                traverse(p.type);
        s.aggr.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ForeachRangeStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.prm.type)
            traverse(s.prm.type);
        s.lwr.accept(this);
        s.upr.accept(this);
        if (s._body)
            s._body.accept(this);
    }

    override void visit(IfStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.prm && s.prm.type)
            traverse(s.prm.type);
        s.condition.accept(this);
        s.ifbody.accept(this);
        if (s.elsebody)
            s.elsebody.accept(this);
    }

    override void visit(ConditionalStatement s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.condition.accept(this);
        if (s.ifbody)
            s.ifbody.accept(this);
        if (s.elsebody)
            s.elsebody.accept(this);
    }

    override void visit(TypeVector t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (!t.basetype)
            return;
        t.basetype.accept(this);
    }

    override void visit(TypeSArray t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.next.accept(this);
    }

    override void visit(TypeDArray t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.next.accept(this);
    }

    override void visit(TypeAArray t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.next.accept(this);
        t.index.accept(this);
    }

    override void visit(TypePointer t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (auto tf = t.next.isTypeFunction())
        {
            traverse(tf, null);
        }
        else
            t.next.accept(this);
    }

    override void visit(TypeReference t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.next.accept(this);
    }

    override void visit(TypeFunction t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t, null);
    }

    override void visit(TypeDelegate t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t.next.isTypeFunction(), null);
    }

    override void visit(TypeIdentifier t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t);
    }

    override void visit(TypeInstance t)
    {

        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.tempinst.accept(this);
        traverse(t);
    }

    override void visit(TypeTypeof t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.exp.accept(this);
        traverse(t);
    }

    override void visit(TypeReturn t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t);
    }

    override void visit(TypeTuple t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t.arguments);
    }

    override void visit(TypeSlice t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.next.accept(this);
        t.lwr.accept(this);
        t.upr.accept(this);
    }

    override void visit(TypeTraits t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.exp.accept(this);
    }

    override void visit(TypeMixin t)
    {
        // lets skip invalid nodes
        if (!isValid(t)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t.exps);
    }

//      Miscellaneous
//========================================================

    override void visit(StaticAssert s)
    {
        // lets skip invalid nodes
        if (!isValid(s)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.exp.accept(this);
        if (s.msgs)
            foreach (m; (*s.msgs)[])
                m.accept(this);
    }

    override void visit(EnumMember em)
    {
        // lets skip invalid nodes
        if (!isValid(em)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (em.type)
            traverse(em.type);
        if (em.value)
            em.value.accept(this);
    }

    override void visit(AttribDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    override void visit(StorageClassDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(cast(AttribDeclaration)d);
    }

    override void visit(DeprecatedDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        d.msg.accept(this);
        traverse(cast(AttribDeclaration)d);
    }

    override void visit(LinkDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(cast(AttribDeclaration)d);
    }

    override void visit(CPPMangleDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(cast(AttribDeclaration)d);
    }

    override void visit(AlignDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(cast(AttribDeclaration)d);
    }

    override void visit(AnonDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(cast(AttribDeclaration)d);
    }

    override void visit(PragmaDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d.args);
        traverse(cast(AttribDeclaration)d);
    }

    override void visit(ConditionalDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        d.condition.accept(this);
        if (d.decl)
            foreach (de; *d.decl)
                if (de)
                    de.accept(this);

        if (d.elsedecl)
            foreach (de; *d.elsedecl)
                if (de)
                    de.accept(this);
    }

    override void visit(CompileDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d.exps);
    }

    override void visit(UserAttributeDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d.atts);
        traverse(cast(AttribDeclaration)d);
    }

    override void visit(TemplateDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (traverse(d))
            return;

        traverse(d.parameters);
        if (d.constraint)
            d.constraint.accept(this);

        foreach (s; *d.members)
            s.accept(this);
    }

    override void visit(TemplateInstance ti)
    {
        // lets skip invalid nodes
        if (!isValid(ti)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(ti);
    }

    override void visit(TemplateMixin tm)
    {
        // lets skip invalid nodes
        if (!isValid(tm)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(tm.tqual);
        traverse(tm);
    }

    override void visit(EnumDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (d.memtype)
            traverse(d.memtype);
        if (!d.members)
            return;
        foreach (em; *d.members)
        {
            if (!em)
                continue;
            em.accept(this);
        }
    }

    override void visit(Nspace d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach(s; *d.members)
            s.accept(this);
    }

    override void visit(UnionDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (!d.members)
            return;
        foreach (s; *d.members)
            s.accept(this);
    }

    override void visit(ClassDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
        if (d.members)
            foreach (s; *d.members)
                s.accept(this);
    }

    override void visit(InterfaceDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
        if (d.members)
            foreach (s; *d.members)
                s.accept(this);
    }

    override void visit(AliasAssign d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (d.aliassym)
            d.aliassym.accept(this);
        else
            traverse(d.type);
    }

    override void visit(FuncLiteralDeclaration f)
    {
        // lets skip invalid nodes
        if (!isValid(f)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (f.type.ty == Terror)
            return;
        auto tf = f.type.isTypeFunction();
        if (!f.inferRetType && tf.next)
            traverse(tf.next);
        traverse(tf.parameterList.parameters);
        CompoundStatement cs = f.fbody.isCompoundStatement();
        Statement s = !cs ? f.fbody : null;
        ReturnStatement rs = s ? s.isReturnStatement() : null;
        if (rs && rs.exp)
            rs.exp.accept(this);
        else
            traverse(f);
    }

    override void visit(PostBlitDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    override void visit(DtorDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    override void visit(CtorDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    override void visit(StaticCtorDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    override void visit(StaticDtorDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    override void visit(InvariantDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    override void visit(UnitTestDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    override void visit(NewDeclaration d)
    {
        // lets skip invalid nodes
        if (!isValid(d)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);
    }

    override void visit(StructInitializer si)
    {
        // lets skip invalid nodes
        if (!isValid(si)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (i, const id; si.field)
            if (auto iz = si.value[i])
                iz.accept(this);
    }

    override void visit(ArrayInitializer ai)
    {
        // lets skip invalid nodes
        if (!isValid(ai)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (i, ex; ai.index)
        {
            if (ex)
                ex.accept(this);
            if (auto iz = ai.value[i])
                iz.accept(this);
        }
    }

    override void visit(ExpInitializer ei)
    {
        // lets skip invalid nodes
        if (!isValid(ei)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        ei.exp.accept(this);
    }

    override void visit(CInitializer ci)
    {
        // lets skip invalid nodes
        if (!isValid(ci)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (di; ci.initializerList)
        {
            foreach (des; (*di.designatorList)[])
            {
                if (des.exp)
                    des.exp.accept(this);
            }
            di.initializer.accept(this);
        }
    }

    override void visit(ArrayLiteralExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(e.elements, e.basis);
    }

    override void visit(AssocArrayLiteralExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (i, key; *e.keys)
        {
            key.accept(this);
            ((*e.values)[i]).accept(this);
        }
    }

    override void visit(TypeExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(e.type);
    }

    override void visit(ScopeExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.sds.isTemplateInstance())
            e.sds.accept(this);
    }

    override void visit(NewExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.thisexp)
            e.thisexp.accept(this);
        traverse(e.newtype);
        traverse(e.arguments);
    }

    override void visit(NewAnonClassExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.thisexp)
            e.thisexp.accept(this);
        traverse(e.arguments);
        if (e.cd)
            e.cd.accept(this);
    }

    override void visit(TupleExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e0)
            e.e0.accept(this);
        traverse(e.exps);
    }

    override void visit(FuncExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.fd.accept(this);
    }

    override void visit(DeclarationExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (auto v = e.declaration.isVarDeclaration())
            traverse(v);
        else
            e.declaration.accept(this);
    }

    override void visit(TypeidExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(e.obj);
    }

    override void visit(TraitsExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.args)
            foreach (arg; *e.args)
                traverse(arg);
    }

    override void visit(IsExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(e.targ);
        if (e.tspec)
            traverse(e.tspec);
        if (e.parameters && e.parameters.length)
            traverse(e.parameters);
    }

    override void visit(UnaExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
    }

    override void visit(BinExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
        e.e2.accept(this);
    }

    override void visit(MixinExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(e.exps);
    }

    override void visit(ImportExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
    }

    override void visit(AssertExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
        if (e.msg)
            e.msg.accept(this);
    }

    override void visit(DotIdExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
    }

    override void visit(DotTemplateInstanceExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
        e.ti.accept(this);
    }

    override void visit(CallExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
        traverse(e.arguments);
    }

    override void visit(PtrExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
    }

    override void visit(DeleteExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
    }

    override void visit(CastExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.to)
            traverse(e.to);
        e.e1.accept(this);
    }

    override void visit(IntervalExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.lwr.accept(this);
        e.upr.accept(this);
    }

    override void visit(ArrayExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
        traverse(e.arguments);
    }

    override void visit(PostExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
    }

    override void visit(CondExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.econd.accept(this);
        e.e1.accept(this);
        e.e2.accept(this);
    }

    override void visit(GenericExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.cntlExp.accept(this);
        foreach (i; 0 .. (*e.types).length)
        {
            if (auto t = (*e.types)[i])  // null means default case
                t.accept(this);
            (*e.exps )[i].accept(this);
        }
    }

    override void visit(ThrowExp e)
    {
        // lets skip invalid nodes
        if (!isValid(e)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        e.e1.accept(this);
    }

    override void visit(TemplateTypeParameter tp)
    {
        // lets skip invalid nodes
        if (!isValid(tp)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (tp.specType)
            traverse(tp.specType);
        if (tp.defaultType)
            traverse(tp.defaultType);
    }

    override void visit(TemplateThisParameter tp)
    {
        // lets skip invalid nodes
        if (!isValid(tp)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        visit(cast(TemplateTypeParameter)tp);
    }

    override void visit(TemplateAliasParameter tp)
    {
        // lets skip invalid nodes
        if (!isValid(tp)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (tp.specType)
            traverse(tp.specType);
        if (tp.specAlias)
            traverse(tp.specAlias);
        if (tp.defaultAlias)
            traverse(tp.defaultAlias);
    }

    override void visit(TemplateValueParameter tp)
    {
        // lets skip invalid node
        if (!isValid(tp)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(tp.valType);

        if (tp.specValue)
            tp.specValue.accept(this);
        if (tp.defaultValue)
            tp.defaultValue.accept(this);
    }

    override void visit(StaticIfCondition c)
    {
        // lets skip invalid node
        if (!isValid(c)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        c.exp.accept(this);
    }

    override void visit(Parameter p)
    {
        // lets skip invalid parameters
        if (!isValid(p)) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(p.type);
        if (p.defaultArg)
            p.defaultArg.accept(this);
    }

    override void visit (Dsymbol)    { mixin(incrementLevelMixin); /* skip */ }
    override void visit (Expression) { mixin(incrementLevelMixin); /* skip */ }
    override void visit (Statement)  { mixin(incrementLevelMixin); /* skip */ }
    override void visit (Type)       { mixin(incrementLevelMixin); /* skip */ }

    bool isValid(Module m)             { return isValid(cast(RootObject)m);  }
    bool isValid(StructDeclaration sd) { return isValid(cast(RootObject)sd); }
    bool isValid(Type t)               { return isValid(cast(RootObject)t);  }
    bool isValid(Statement s)          { return isValid(cast(RootObject)s);  }
    bool isValid(Dsymbol s)            { return isValid(cast(RootObject)s);  }
    bool isValid(FuncDeclaration fd)   { return isValid(cast(RootObject)fd); }
    bool isValid(CompoundStatement cs) { return isValid(cast(RootObject)cs); }
    bool isValid(AliasDeclaration ad)  { return isValid(cast(RootObject)ad); }
    bool isValid(Catch c)              { return isValid(cast(RootObject)c);  }
    bool isValid(VarDeclaration vd)    { return isValid(cast(RootObject)vd); }

    bool isValid(ASTNode n) { return isValid(cast(RootObject)n); }
    bool isValid(RootObject obj)
    {
        return obj !is null;
    }
}

extern(C++) class DFSPluginVisitor : SafeTransitiveVisitor
{
    ///
    alias visit = SafeTransitiveVisitor.visit;
    alias isValid = SafeTransitiveVisitor.isValid;

    /// module currently visiting
    Module mod;

    override bool isValid(FuncDeclaration fd)
    {
        if (!super.isValid(fd)) return false;

        // skip generated functions by the semantic analysis
        if (fd.isGenerated) return false;
        // skip naked functions due to high possibility of false positives
        if (fd.isNaked) return false;

        // valid otherwise
        return true;
    }

    override void visit (Module m)
    {
        // lets skip invalid modules
        if (!isValid(m)) { mixin(invalidReturnMixin); }

        // lets skip this module if we are already visiting one
        if (mod !is null) return;

        this.mod = m;
        scope(exit) this.mod = null;

        super.visit(m);
    }

    override void visit (Dsymbol s)
    {
        // lets skip invalid symbols
        if (!isValid(s)) return;

        super.visit(s);
        debug (ast) stderr.writefln("! Unhandled symbol `%s` of kind '%s'", fromStringz(s.toChars()), fromStringz(s.kind));
    }

    override void visit (Expression e)
    {
        // lets skip invalid expression
        if (!isValid(e)) return;

        super.visit(e);
        debug (ast) stderr.writefln("! Unhandled expression `%s` of kind '%s'", fromStringz(e.toChars()), e.op);
    }

    override void visit (Statement s)
    {
        // lets skip invalid statements
        if (!isValid(s)) return;

        super.visit(s);
        debug (ast) stderr.writefln("! Unhandled statement `%s` of type '%s'", fromStringz(s.toChars()), s.stmt);
    }

    override void visit (Type t)
    {
        // lets skip invalid types
        if (!isValid(t)) return;

        super.visit(t);
        debug (ast) stderr.writefln("! Unhandled type `%s` of kind '%s'", fromStringz(t.toChars()), fromStringz(t.kind()));
    }

    override void visit (FuncDeclaration fd)
    {
        // lets skip invalid functions
        if (!isValid(fd)) return;

        super.visit(fd);
    }

    override void visit(IntegerExp) { /* skip */ }
    override void visit(ComplexExp) { /* skip */ }
    override void visit(ErrorExp)   { /* skip */ }
}

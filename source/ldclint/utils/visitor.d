module ldclint.utils.visitor;

import ldclint.utils.querier;

import DMD = ldclint.dmd;
import DParse = ldclint.dparse;

import std.stdio;
import std.string;
import std.range;
import std.array;
import std.traits;
import std.meta;

//debug = visitor;

abstract class Visitor
{
    /// level of the accepted visitor
    debug (visitor) ptrdiff_t level;

    private enum string incrementLevelMixin = q{
        debug (visitor)
            stderr.writeln(' '.repeat(level), "> Calling `", (&__traits(parent, {})).stringof, typeof(__traits(parameters)).stringof, "`");
        debug (visitor) ++level;
        scope(exit) debug (visitor) --level;
    };

    private enum string aliasLevelMixin = q{
        debug (visitor)
            stderr.writeln(' '.repeat(level), "> Calling `", (&__traits(parent, {})).stringof, typeof(__traits(parameters)).stringof, "`");
    };

    private enum string invalidReturnMixin = q{
        debug (visitor) stderr.writeln(' '.repeat(level), "| invalid");
        return;
    };

    private DMD.VisitorProxy!Visitor dmdVisitorProxyImpl;
    auto dmdVisitorProxy() {
        if (dmdVisitorProxyImpl is null)
            dmdVisitorProxyImpl = DMD.visitorProxy(this);

        return dmdVisitorProxyImpl;
    }

    protected final void traverse(DMD.RootObject oarg)
    {
        mixin(incrementLevelMixin);

        if (auto t = DMD.isType(oarg))
        {
            traverse(t);
        }
        else if (auto e = DMD.isExpression(oarg))
        {
            e.accept(dmdVisitorProxy);
        }
        else if (auto v = DMD.isTuple(oarg))
        {
            auto args = &v.objects;
            foreach (arg; *args)
                traverse(arg);
        }
    }

    protected final void traverse(DMD.TemplateInstance ti)
    {
        mixin(incrementLevelMixin);

        if (!ti.tiargs)
            return;
        foreach (arg; *ti.tiargs)
        {
            traverse(arg);
        }
    }

    protected final void traverse(DMD.TemplateParameters* parameters)
    {
        mixin(incrementLevelMixin);

        if (!parameters || !parameters.length)
            return;
        foreach (p; *parameters)
            p.accept(dmdVisitorProxy);
    }

    protected final void traverse(DMD.AttribDeclaration ad)
    {
        mixin(incrementLevelMixin);

        if (ad.decl)
            foreach (d; *ad.decl)
                if (d)
                    d.accept(dmdVisitorProxy);
    }

    protected final void traverse(DMD.TypeQualified t)
    {
        mixin(incrementLevelMixin);

        foreach (id; t.idents)
        {
            switch(id.dyncast())
            {
            case DMD.DYNCAST.dsymbol:
                (cast(DMD.TemplateInstance)id).accept(dmdVisitorProxy);
                break;
            case DMD.DYNCAST.expression:
                (cast(DMD.Expression)id).accept(dmdVisitorProxy);
                break;
            case DMD.DYNCAST.type:
                (cast(DMD.Type)id).accept(dmdVisitorProxy);
                break;
            default:
                break;
            }
        }
    }

    protected final void traverse(DMD.Type t)
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
            t.accept(dmdVisitorProxy);
    }

    protected final void traverse(DMD.TypeFunction t, DMD.TemplateDeclaration td = null)
    {
        mixin(incrementLevelMixin);

        if (t.next)
            traverse(t.next);
        if (td)
        {
            foreach (p; *td.origParameters)
                p.accept(dmdVisitorProxy);
        }

        auto params = t.parameterList.parameters;
        if(params)
            foreach(p; *params)
                p.accept(dmdVisitorProxy);
    }

    protected final void traverse(DMD.VarDeclaration vd)
    {
        mixin(incrementLevelMixin);

        if (vd.type)
            traverse(vd.type);
        if (vd._init)
        {
            if (auto ie = vd._init.isExpInitializer())
            {
                if (auto ce = ie.exp.isConstructExp())
                    ce.e2.accept(dmdVisitorProxy);
                else if (auto be = ie.exp.isBlitExp())
                    be.e2.accept(dmdVisitorProxy);
                else
                    vd._init.accept(dmdVisitorProxy);
            }
            else
                vd._init.accept(dmdVisitorProxy);
        }
    }

    protected void traverse(T)(T* arr)
        if(__traits(isSame, DMD.Array, TemplateOf!T))
    {
        mixin(incrementLevelMixin);

        if (arr is null) return;

        foreach (el; *arr)
            if (el)
                el.accept(dmdVisitorProxy);
    }

    protected final void traverse(DMD.Array!(DMD.Expression)* expressions, DMD.Expression basis = null)
    {
        mixin(incrementLevelMixin);

        if (expressions is null) return;

        foreach (el; *expressions)
        {
            if (!el)
                el = basis;
            if (el)
                el.accept(dmdVisitorProxy);
        }
    }

    protected final void traverse(DMD.FuncDeclaration fd)
    {
        mixin(incrementLevelMixin);

        if (fd.frequires)
            foreach (frequire; *fd.frequires)
                frequire.accept(dmdVisitorProxy);

        if (fd.fensures)
            foreach (fensure; *fd.fensures)
                fensure.ensure.accept(dmdVisitorProxy);

        if (fd.fbody)
            fd.fbody.accept(dmdVisitorProxy);

        traverse(fd.parameters);
    }

    void traverse(DMD.ClassDeclaration d)
    {
        mixin(incrementLevelMixin);

        if (!d || !d.baseclasses.length)
            return;
        foreach (b; *d.baseclasses)
            traverse(b.type);
    }

    bool traverse(DMD.TemplateDeclaration d)
    {
        mixin(incrementLevelMixin);

        if (!d.members || d.members.length != 1)
            return false;
        DMD.Dsymbol onemember = (*d.members)[0];
        if (onemember.ident != d.ident)
            return false;

        if (DMD.FuncDeclaration fd = onemember.isFuncDeclaration())
        {
            assert(fd.type);
            traverse(fd.type.isTypeFunction(), d);
            if (d.constraint)
                d.constraint.accept(dmdVisitorProxy);
            traverse(fd);

            return true;
        }

        if (DMD.AggregateDeclaration ad = onemember.isAggregateDeclaration())
        {
            traverse(d.parameters);
            if (d.constraint)
                d.constraint.accept(dmdVisitorProxy);
            traverse(ad.isClassDeclaration());

            if (ad.members)
                foreach (s; *ad.members)
                    s.accept(dmdVisitorProxy);

            return true;
        }

        if (DMD.VarDeclaration vd = onemember.isVarDeclaration())
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
                        ce.e2.accept(dmdVisitorProxy);
                    else if (auto be = ie.exp.isBlitExp())
                        be.e2.accept(dmdVisitorProxy);
                    else
                        vd._init.accept(dmdVisitorProxy);
                }
                else
                    vd._init.accept(dmdVisitorProxy);

                return true;
            }
        }

        return false;
    }

    void visit(Querier!(DMD.StructDeclaration) sd)
    {
        // lets skip invalid structs
        if (!sd.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        // === traversal ===

        if (sd.members)
            foreach (s; *sd.members)
                s.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ThisExp) this_)
    {
        // lets skip invalid structs
        if (!this_.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (this_.astNode.type !is null)
            this_.astNode.type.accept(dmdVisitorProxy);

        if (this_.var !is null)
            this_.var.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        // lets skip invalid functions
        if (!fd.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);
        debug (visitor) stderr.writeln(' '.repeat(level), "| func=", fromStringz(fd.toChars()));

        traverse(fd);
    }

    void visit(Querier!(DMD.Module) m)
    {
        // lets skip invalid modules
        if (!m.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        // === traversal ===

        if (m.members)
            foreach(sym; *m.members)
                if (sym)
                    sym.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.CompoundStatement) s)
    {
        // lets skip invalid statements
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.statements)
            foreach (sx; *s.statements)
                if (sx)
                    sx.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ExpStatement) s)
    {
        // lets skip invalid statements
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.exp)
        {
            if (auto de = s.exp.isDeclarationExp())
                de.declaration.accept(dmdVisitorProxy);
            else
                s.exp.accept(dmdVisitorProxy);
        }
    }

    void visit(Querier!(DMD.VisibilityDeclaration) vd)
    {
        if (!vd.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(vd);
    }

    void visit(Querier!(DMD.AliasDeclaration) ad)
    {
        // lets skip invalid declarations
        if (!ad.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (ad.aliassym)
            ad.aliassym.accept(dmdVisitorProxy);
        else
            traverse(ad.astNode.type);
    }

    void visit(Querier!(DMD.PragmaStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.args)
            foreach (a; *s.args)
                if (a)
                    a.accept(dmdVisitorProxy);

        if (s._body)
            s._body.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.StaticAssertStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.sa.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.SwitchStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.condition.accept(dmdVisitorProxy);
        if (s._body)
            s._body.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.CaseStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.exp.accept(dmdVisitorProxy);
        s.statement.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.CaseRangeStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.first.accept(dmdVisitorProxy);
        s.last.accept(dmdVisitorProxy);
        s.statement.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.DefaultStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.statement.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.GotoCaseStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.exp)
            s.exp.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ReturnStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.exp)
            s.exp.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.SynchronizedStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.exp)
            s.exp.accept(dmdVisitorProxy);
        if (s._body)
            s._body.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.WithStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.exp.accept(dmdVisitorProxy);
        if (s._body)
            s._body.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TryCatchStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s._body)
            s._body.accept(dmdVisitorProxy);
        foreach (c; *s.catches)
            visit(querier(c));
    }

    void visit(Querier!(DMD.TryFinallyStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s._body.accept(dmdVisitorProxy);
        s.finalbody.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ScopeGuardStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.statement.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ThrowStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.exp.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.LabelStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.statement)
            s.statement.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ImportStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (imp; *s.imports)
            imp.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.VarDeclaration) vd)
    {
        // lets skip invalid nodes
        if (!vd.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        debug (visitor) stderr.writeln(' '.repeat(level), "| var=", fromStringz(vd.toChars()));

        traverse(vd);
    }

    /*override*/ void visit(Querier!(DMD.Catch) c)
    {
        // lets skip invalid nodes
        if (!c.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (c.astNode.type)
            traverse(c.astNode.type);
        if (c.handler)
            c.handler.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.MixinStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.exps)
            foreach (e; *s.exps)
                if (e)
                    e.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.CompoundDeclarationStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

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
                        d.accept(dmdVisitorProxy);
                }
            }
        }
    }

    void visit(Querier!(DMD.ScopeStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.statement)
            s.statement.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.WhileStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.condition.accept(dmdVisitorProxy);
        if (s._body)
            s._body.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.DoStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s._body)
            s._body.accept(dmdVisitorProxy);
        s.condition.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ForStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s._init)
            s._init.accept(dmdVisitorProxy);
        if (s.condition)
            s.condition.accept(dmdVisitorProxy);
        if (s.increment)
            s.increment.accept(dmdVisitorProxy);
        if (s._body)
            s._body.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ForeachStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (p; *s.parameters)
            if (p.type)
                traverse(p.type);
        s.aggr.accept(dmdVisitorProxy);
        if (s._body)
            s._body.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ForeachRangeStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.prm.type)
            traverse(s.prm.type);
        s.lwr.accept(dmdVisitorProxy);
        s.upr.accept(dmdVisitorProxy);
        if (s._body)
            s._body.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.IfStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (s.prm && s.prm.type)
            traverse(s.prm.type);
        s.condition.accept(dmdVisitorProxy);
        s.ifbody.accept(dmdVisitorProxy);
        if (s.elsebody)
            s.elsebody.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ConditionalStatement) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.condition.accept(dmdVisitorProxy);
        if (s.ifbody)
            s.ifbody.accept(dmdVisitorProxy);
        if (s.elsebody)
            s.elsebody.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TypeVector) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (!t.basetype)
            return;
        t.basetype.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TypeSArray) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.next.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TypeDArray) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.next.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TypeAArray) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.next.accept(dmdVisitorProxy);
        t.index.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TypePointer) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (auto tf = t.next.isTypeFunction())
        {
            traverse(tf, null);
        }
        else
            t.next.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TypeReference) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.next.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TypeFunction) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t, null);
    }

    void visit(Querier!(DMD.TypeDelegate) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t.next.isTypeFunction(), null);
    }

    void visit(Querier!(DMD.TypeIdentifier) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t);
    }

    void visit(Querier!(DMD.TypeInstance) t)
    {

        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.tempinst.accept(dmdVisitorProxy);
        traverse(t);
    }

    void visit(Querier!(DMD.TypeTypeof) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.exp.accept(dmdVisitorProxy);
        traverse(t);
    }

    void visit(Querier!(DMD.TypeReturn) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t);
    }

    void visit(Querier!(DMD.TypeTuple) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t.arguments);
    }

    void visit(Querier!(DMD.TypeSlice) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.next.accept(dmdVisitorProxy);
        t.lwr.accept(dmdVisitorProxy);
        t.upr.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TypeTraits) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        t.exp.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TypeMixin) t)
    {
        // lets skip invalid nodes
        if (!t.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(t.exps);
    }

//      Miscellaneous
//========================================================

    void visit(Querier!(DMD.StaticAssert) s)
    {
        // lets skip invalid nodes
        if (!s.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        s.exp.accept(dmdVisitorProxy);
        static if (__traits(compiles, s.msgs))
        {
            if (s.msgs)
                foreach (m; (*s.msgs)[])
                    m.accept(dmdVisitorProxy);
        }
        else
        {
            if (s.msg) s.msg.accept(dmdVisitorProxy);
        }
    }

    void visit(Querier!(DMD.EnumMember) em)
    {
        // lets skip invalid nodes
        if (!em.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (em.astNode.type)
            traverse(em.astNode.type);
        if (em.value)
            em.value.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.AttribDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    void visit(Querier!(DMD.StorageClassDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(cast(DMD.AttribDeclaration)d);
    }

    void visit(Querier!(DMD.DeprecatedDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        d.msg.accept(dmdVisitorProxy);
        traverse(cast(DMD.AttribDeclaration)d);
    }

    void visit(Querier!(DMD.LinkDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(cast(DMD.AttribDeclaration)d);
    }

    void visit(Querier!(DMD.CPPMangleDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(cast(DMD.AttribDeclaration)d);
    }

    void visit(Querier!(DMD.AlignDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(cast(DMD.AttribDeclaration)d);
    }

    void visit(Querier!(DMD.AnonDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(cast(DMD.AttribDeclaration)d);
    }

    void visit(Querier!(DMD.PragmaDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d.args);
        traverse(cast(DMD.AttribDeclaration)d);
    }

    void visit(Querier!(DMD.ConditionalDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        d.condition.accept(dmdVisitorProxy);
        if (d.decl)
            foreach (de; *d.decl)
                if (de)
                    de.accept(dmdVisitorProxy);

        if (d.elsedecl)
            foreach (de; *d.elsedecl)
                if (de)
                    de.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.MixinDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d.exps);
    }

    void visit(Querier!(DMD.UserAttributeDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d.atts);
        traverse(cast(DMD.AttribDeclaration)d);
    }

    void visit(Querier!(DMD.TemplateDeclaration) td)
    {
        // lets skip invalid nodes
        if (!td.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);
        debug (visitor) stderr.writeln(">>> ", fromStringz(td.toChars()));

        if (traverse(td))
            return;

        traverse(td.parameters);
        if (td.constraint)
            td.constraint.accept(dmdVisitorProxy);

        foreach (s; *td.members)
            s.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TemplateInstance) ti)
    {
        // lets skip invalid nodes
        if (!ti.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(ti);
    }

    void visit(Querier!(DMD.TemplateMixin) tm)
    {
        // lets skip invalid nodes
        if (!tm.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(tm.tqual);
        traverse(tm);
    }

    void visit(Querier!(DMD.EnumDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (d.memtype)
            traverse(d.memtype);
        if (!d.members)
            return;
        foreach (em; *d.members)
        {
            if (!em)
                continue;
            em.accept(dmdVisitorProxy);
        }
    }

    void visit(Querier!(DMD.Nspace) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach(s; *d.members)
            s.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.UnionDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (!d.members)
            return;
        foreach (s; *d.members)
            s.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ClassDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
        if (d.members)
            foreach (s; *d.members)
                s.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.InterfaceDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
        if (d.members)
            foreach (s; *d.members)
                s.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.AliasAssign) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (d.aliassym)
            d.aliassym.accept(dmdVisitorProxy);
        else
            traverse(d.astNode.type);
    }

    void visit(Querier!(DMD.FuncLiteralDeclaration) f)
    {
        // lets skip invalid nodes
        if (!f.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (f.astNode.type.ty == DMD.Terror)
            return;
        auto tf = f.astNode.type.isTypeFunction();
        if (!f.inferRetType && tf.next)
            traverse(tf.next);
        traverse(tf.parameterList.parameters);
        DMD.CompoundStatement cs = f.fbody.isCompoundStatement();
        DMD.Statement s = !cs ? f.fbody : null;
        DMD.ReturnStatement rs = s ? s.isReturnStatement() : null;
        if (rs && rs.exp)
            rs.exp.accept(dmdVisitorProxy);
        else
            traverse(f);
    }

    void visit(Querier!(DMD.PostBlitDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    void visit(Querier!(DMD.DtorDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    void visit(Querier!(DMD.CtorDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    void visit(Querier!(DMD.StaticCtorDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    void visit(Querier!(DMD.StaticDtorDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    void visit(Querier!(DMD.InvariantDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    void visit(Querier!(DMD.UnitTestDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(d);
    }

    void visit(Querier!(DMD.NewDeclaration) d)
    {
        // lets skip invalid nodes
        if (!d.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);
    }

    void visit(Querier!(DMD.StructInitializer) si)
    {
        // lets skip invalid nodes
        if (!si.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (i, const id; si.field)
            if (auto iz = si.value[i])
                iz.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ArrayInitializer) ai)
    {
        // lets skip invalid nodes
        if (!ai.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (i, ex; ai.index)
        {
            if (ex)
                ex.accept(dmdVisitorProxy);
            if (auto iz = ai.value[i])
                iz.accept(dmdVisitorProxy);
        }
    }

    void visit(Querier!(DMD.ExpInitializer) ei)
    {
        // lets skip invalid nodes
        if (!ei.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        ei.exp.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.CInitializer) ci)
    {
        // lets skip invalid nodes
        if (!ci.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (di; ci.initializerList)
        {
            foreach (des; (*di.designatorList)[])
            {
                if (des.exp)
                    des.exp.accept(dmdVisitorProxy);
            }
            di.initializer.accept(dmdVisitorProxy);
        }
    }

    void visit(Querier!(DMD.ArrayLiteralExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(e.elements, e.basis);
    }

    void visit(Querier!(DMD.AssocArrayLiteralExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        foreach (i, key; *e.keys)
        {
            key.accept(dmdVisitorProxy);
            ((*e.values)[i]).accept(dmdVisitorProxy);
        }
    }

    void visit(Querier!(DMD.TypeExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(e.astNode.type);
    }

    void visit(Querier!(DMD.ScopeExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.sds.isTemplateInstance())
            e.sds.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.NewExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.thisexp)
            e.thisexp.accept(dmdVisitorProxy);
        traverse(e.newtype);
        traverse(e.arguments);
    }

    void visit(Querier!(DMD.NewAnonClassExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.thisexp) e.thisexp.accept(dmdVisitorProxy);
        if (e.arguments) traverse(e.arguments);
        if (e.cd) e.cd.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TupleExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e0) e.e0.accept(dmdVisitorProxy);
        if (e.exps) traverse(e.exps);
    }

    void visit(Querier!(DMD.FuncExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.fd) e.fd.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.DeclarationExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.declaration is null) return;

        if (auto v = e.declaration.isVarDeclaration())
            traverse(v);
        else
            e.declaration.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TypeidExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(e.obj);
    }

    void visit(Querier!(DMD.TraitsExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.args)
            foreach (arg; *e.args)
                traverse(arg);
    }

    void visit(Querier!(DMD.IsExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(e.targ);
        if (e.tspec)
            traverse(e.tspec);
        if (e.parameters && e.parameters.length)
            traverse(e.parameters);
    }

    void visit(Querier!(DMD.UnaExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.SliceExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1)  e.e1.accept(dmdVisitorProxy);
        if (e.upr) e.upr.accept(dmdVisitorProxy);
        if (e.lwr) e.lwr.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.BinExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
        if (e.e2) e.e2.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.MixinExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.exps) traverse(e.exps);
    }

    void visit(Querier!(DMD.ImportExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.AssertExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
        if (e.msg) e.msg.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.DotIdExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.DotVarExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.DotTemplateInstanceExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        debug (visitor) stderr.writeln(' '.repeat(level), "| instance=", fromStringz(e.toChars()));

        if (e.e1) e.e1.accept(dmdVisitorProxy);
        if (e.ti) e.ti.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.CallExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
        if (e.arguments) traverse(e.arguments);
    }

    void visit(Querier!(DMD.PtrExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.DeleteExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.CastExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.to) traverse(e.to);
        if (e.e1) e.e1.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.IntervalExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.lwr) e.lwr.accept(dmdVisitorProxy);
        if (e.upr) e.upr.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.ArrayExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
        if (e.arguments) traverse(e.arguments);
    }

    void visit(Querier!(DMD.PostExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.CondExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.econd) e.econd.accept(dmdVisitorProxy);
        if (e.e1) e.e1.accept(dmdVisitorProxy);
        if (e.e2) e.e2.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.GenericExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.cntlExp) e.cntlExp.accept(dmdVisitorProxy);

        foreach (i; 0 .. (*e.types).length)
        {
            if (auto t = (*e.types)[i])  // null means default case
                t.accept(dmdVisitorProxy);
            (*e.exps )[i].accept(dmdVisitorProxy);
        }
    }

    void visit(Querier!(DMD.ThrowExp) e)
    {
        // lets skip invalid nodes
        if (!e.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (e.e1) e.e1.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.TemplateTypeParameter) tp)
    {
        // lets skip invalid nodes
        if (!tp.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (tp.specType)
            traverse(tp.specType);
        if (tp.defaultType)
            traverse(tp.defaultType);
    }

    void visit(Querier!(DMD.TemplateThisParameter) tp)
    {
        // lets skip invalid nodes
        if (!tp.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        visit(cast(Querier!(DMD.TemplateTypeParameter))tp);
    }

    void visit(Querier!(DMD.TemplateAliasParameter) tp)
    {
        // lets skip invalid nodes
        if (!tp.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (tp.specType)
            traverse(tp.specType);
        if (tp.specAlias)
            traverse(tp.specAlias);
        if (tp.defaultAlias)
            traverse(tp.defaultAlias);
    }

    void visit(Querier!(DMD.TemplateValueParameter) tp)
    {
        // lets skip invalid node
        if (!tp.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(tp.valType);

        if (tp.specValue)
            tp.specValue.accept(dmdVisitorProxy);
        if (tp.defaultValue)
            tp.defaultValue.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.StaticIfCondition) c)
    {
        // lets skip invalid node
        if (!c.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        if (c.exp) c.exp.accept(dmdVisitorProxy);
    }

    void visit(Querier!(DMD.Parameter) p)
    {
        // lets skip invalid parameters
        if (!p.isValid()) { mixin(invalidReturnMixin); }

        mixin(incrementLevelMixin);

        traverse(p.astNode.type);
        if (p.defaultArg)
            p.defaultArg.accept(dmdVisitorProxy);
    }

    // nodes that are expressions

    static foreach(T; AliasSeq!(
        DMD.ClassReferenceExp,
        DMD.ComplexExp,
        DMD.CompoundLiteralExp,
        DMD.ErrorExp,
        DMD.HaltExp,
        DMD.IntegerExp,
        DMD.ObjcClassReferenceExp,
        DMD.OverExp,
        DMD.RealExp,
        DMD.StructLiteralExp,
        DMD.SymbolExp,
        DMD.TemplateExp,
        DMD.DefaultInitExp,
        DMD.IdentifierExp,
        DMD.NullExp,
        DMD.ThrownExceptionExp,
        DMD.VarExp,
        DMD.VoidInitExp,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.Expression))n);
        }

    static foreach(T; AliasSeq!(
        DMD.FileInitExp,
        DMD.FuncInitExp,
        DMD.LineInitExp,
        DMD.ModuleInitExp,
        DMD.PrettyFuncInitExp,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.DefaultInitExp))n);
        }

    // nodes that are binary expressions

    static foreach(T; AliasSeq!(
        DMD.AndExp,
        DMD.AssignExp,
        DMD.CatExp,
        DMD.CmpExp,
        DMD.CommaExp,
        DMD.DivExp,
        DMD.DotExp,
        DMD.EqualExp,
        DMD.IdentityExp,
        DMD.InExp,
        DMD.IndexExp,
        DMD.LogicalExp,
        DMD.MinExp,
        DMD.ModExp,
        DMD.AddExp,
        DMD.MulExp,
        DMD.OrExp,
        DMD.PowExp,
        DMD.RemoveExp,
        DMD.ShlExp,
        DMD.ShrExp,
        DMD.UshrExp,
        DMD.XorExp,

        //
        DMD.BinAssignExp,
        //
        DMD.CatAssignExp,
        DMD.UshrAssignExp,
        DMD.ShrAssignExp,
        DMD.ShlAssignExp,
        DMD.XorAssignExp,
        DMD.OrAssignExp,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.BinExp))n);
        }

    // nodes that are unary expressions

    static foreach(T; AliasSeq!(
        DMD.AddrExp,
        DMD.ArrayLengthExp,
        DMD.ComExp,
        DMD.DelegateExp,
        DMD.DelegateFuncptrExp,
        DMD.DelegatePtrExp,
        DMD.DotTemplateExp,
        DMD.DotTypeExp,
        DMD.NegExp,
        DMD.NotExp,
        DMD.PreExp,
        DMD.UAddExp,
        DMD.VectorArrayExp,
        DMD.VectorExp,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.UnaExp))n);
        }

    void visit(Querier!(DMD.DollarExp) e) {
        mixin(aliasLevelMixin);
        visit(cast(Querier!(DMD.IdentifierExp))e);
    }
    void visit(Querier!(DMD.SuperExp) e) {
        mixin(aliasLevelMixin);
        visit(cast(Querier!(DMD.ThisExp))e);
    }

    // nodes that are assign expressions

    static foreach(T; DMD.AssignExpSeq)
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.AssignExp))n);
        }

    // nodes that are a subtype of a node
    void visit (Querier!(DMD.SymOffExp) n) {
        mixin(aliasLevelMixin);
        visit(cast(Querier!(DMD.SymbolExp))n);
    }
    void visit (Querier!(DMD.ForwardingAttribDeclaration) n) {
        mixin(aliasLevelMixin);
        visit(cast(Querier!(DMD.AttribDeclaration))n);
    }
    void visit (Querier!(DMD.DtorExpStatement) n) {
        mixin(aliasLevelMixin);
        visit(cast(Querier!(DMD.ExpStatement))n);
    }
    void visit (Querier!(DMD.FuncAliasDeclaration) n) {
        mixin(aliasLevelMixin);
        visit(cast(Querier!(DMD.FuncDeclaration))n);
    }
    void visit (Querier!(DMD.ErrorInitializer) n) {
        mixin(aliasLevelMixin);
        visit(cast(Querier!(DMD.Initializer))n);
    }

    // nodes that are statements

    static foreach(T; AliasSeq!(
        DMD.GccAsmStatement,
        DMD.AsmStatement,
        DMD.BreakStatement,
        DMD.ContinueStatement,
        DMD.DebugStatement,
        DMD.ErrorStatement,
        DMD.ForwardingStatement,
        DMD.GotoDefaultStatement,
        DMD.GotoStatement,
        DMD.PeelStatement,
        DMD.StaticForeachStatement,
        DMD.SwitchErrorStatement,
        DMD.UnrolledLoopStatement,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.Statement))n);
        }

    // nodes that are type infos

    static foreach(T; AliasSeq!(
        DMD.TypeInfoArrayDeclaration,
        DMD.TypeInfoAssociativeArrayDeclaration,
        DMD.TypeInfoClassDeclaration,
        DMD.TypeInfoConstDeclaration,
        DMD.TypeInfoDelegateDeclaration,
        DMD.TypeInfoEnumDeclaration,
        DMD.TypeInfoFunctionDeclaration,
        DMD.TypeInfoInterfaceDeclaration,
        DMD.TypeInfoInvariantDeclaration,
        DMD.TypeInfoPointerDeclaration,
        DMD.TypeInfoSharedDeclaration,
        DMD.TypeInfoStaticArrayDeclaration,
        DMD.TypeInfoStructDeclaration,
        DMD.TypeInfoTupleDeclaration,
        DMD.TypeInfoVectorDeclaration,
        DMD.TypeInfoWildDeclaration,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.TypeInfoDeclaration))n);
        }

    // nodes that are symbols

    static foreach(T; DMD.DsymbolSeq)
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.Dsymbol))n);
        }

    // nodes that are declarations

    static foreach(T; AliasSeq!(
        DMD.OverDeclaration,
        DMD.SymbolDeclaration,
        DMD.TupleDeclaration,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.Declaration))n);
        }

    // nodes that are variable declarations

    static foreach(T; AliasSeq!(
        DMD.ThisDeclaration,
        DMD.TypeInfoDeclaration,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.VarDeclaration))n);
        }

    // nodes that are symbols with scope information

    static foreach(T; AliasSeq!(
        DMD.ArrayScopeSymbol,
        DMD.WithScopeSymbol,
        DMD.Package,
        DMD.AggregateDeclaration,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.ScopeDsymbol))n);
        }

    // nodes that are types

    static foreach(T; AliasSeq!(
        DMD.TypeBasic,
        DMD.TypeError,
        DMD.TypeNull,
        DMD.TypeNoreturn,
        DMD.TypeEnum,
        DMD.TypeClass,
        DMD.TypeStruct,
        DMD.TypeNext,
        DMD.TypeQualified,
        DMD.TypeTag,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.Type))n);
        }

    static foreach(T; AliasSeq!(
        DMD.TypeArray,
    ))
        void visit (Querier!T n) {
            mixin(aliasLevelMixin);
            visit(cast(Querier!(DMD.TypeNext))n);
        }

    // nodes not yet implemented

    static foreach(T; AliasSeq!(
        DMD.SharedStaticCtorDeclaration,
        DMD.SharedStaticDtorDeclaration,
        DMD.CPPNamespaceDeclaration,
        DMD.StaticForeachDeclaration,
        DMD.StaticIfDeclaration,
        DMD.BitFieldDeclaration,
        DMD.CompoundAsmStatement,
        DMD.InlineAsmStatement,
        DMD.StringExp,
        DMD.DsymbolExp,
        DMD.AddAssignExp,
        DMD.MinAssignExp,
        DMD.MulAssignExp,
        DMD.DivAssignExp,
        DMD.ModAssignExp,
        DMD.PowAssignExp,
        DMD.AndAssignExp,
        DMD.VoidInitializer,
        DMD.VersionCondition,
        DMD.DebugCondition,
        DMD.DVCondition,
        DMD.TemplateTupleParameter,
    ))
        void visit (Querier!T) {
            mixin(incrementLevelMixin);
            assert(0, format!"Visitor `visit(%s)` not yet implemented"(T.stringof));
        }

    // nodes that are skipped

    static foreach(T; AliasSeq!(
        DMD.Dsymbol,
        DMD.Expression,
        DMD.Statement,
        DMD.Type,
        DMD.TemplateParameter,
        DMD.Initializer,
        DMD.Condition,
    ))
        void visit (Querier!T) { mixin(incrementLevelMixin); /* skip */ }
}

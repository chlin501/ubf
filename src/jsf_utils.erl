%%% $Id: jsf_utils.erl 131914 2009-04-13 09:02:30Z norton $
%%% Description: utils for jsf
%%%-------------------------------------------------------------------

-module(jsf_utils).
-include("ubf.hrl").

-export([ubf_contract/1, ubf_contract/2]).

get_type(Name,Mod) ->
    get_type(Name,true,Mod).

get_type(Name,Strict,Mod) ->
    case lists:member(Name,Mod:contract_types()) of
        true ->
            {Type, Tag} = Mod:contract_type(Name),
            {Name, Type, Tag};
        false ->
            if Strict ->
                    exit({undefined_ubf_type,Name});
               true ->
                    undefined
            end
    end.

ubf(Name,Mod) ->
    {Name,Type,_} = get_type(Name,Mod),
    type(Type,Mod).

type(Type,Mod) ->
    io_lib:format("\t\t~s\n", [typeref(Type, Mod)]).

typeref({tuple,Elements},Mod) ->
    io_lib:format("{\"$T\" : [ ~s ]}", [join([typeref(Element, Mod) || Element <- Elements], ", ")]);
typeref({record,Name,Elements},Mod) when is_atom(Name) ->
    Values = tl(tl(Elements)),
    RecordKey = {Name,length(Elements)-2},
    Fields = Mod:contract_record(RecordKey),
    io_lib:format("{\"$R\" : \"~p\", ~s}",
                  [Name, join([ io_lib:format("\"~p\" : ~s", [Field, typeref(Element, Mod)])
                                || {Field,Element} <- lists:zip(Fields,Values) ], ", ")]);
typeref({record_ext,Name,_,_Elements},_Mod) when is_atom(Name) ->
    erlang:exit(fatal);
typeref({prim,integer},_Mod) ->
    "integer()";
typeref({prim,float},_Mod) ->
    "float()";
typeref({prim,atom},_Mod) ->
    "atom()";
typeref({prim,{atom,Attrs}},_Mod) ->
    io_lib:format("atom(~s)", [join([ atom_to_list(Attr) || Attr <- Attrs ], ",")]);
typeref({prim,string},_Mod) ->
    "string()";
typeref({prim,{string,Attrs}},_Mod) ->
    io_lib:format("string(~s)", [join([ atom_to_list(Attr) || Attr <- Attrs ], ",")]);
typeref({prim,binary},_Mod) ->
    "binary()";
typeref({prim,{binary,Attrs}},_Mod) ->
    io_lib:format("binary(~s)", [join([ atom_to_list(Attr) || Attr <- Attrs ], ",")]);
typeref({prim,tuple},_Mod) ->
    "tuple()";
typeref({prim,term},_Mod) ->
    "term()";
typeref({prim,{term,Attrs}},_Mod) ->
    io_lib:format("term(~s)", [join([ atom_to_list(Attr) || Attr <- Attrs ], ",")]);
typeref({prim,void},_Mod) ->
    erlang:exit(fatal);
typeref({prim,Tag},_Mod) ->
    io_lib:format("~p()", [Tag]);
typeref({prim_optional,Tag},_Mod) ->
    io_lib:format("~p()?", [Tag]);
typeref({prim_nil,Tag},_Mod) ->
    io_lib:format("~p(){0}", [Tag]);
typeref({prim_required,Tag},_Mod) ->
    io_lib:format("~p(){1}", [Tag]);
typeref({integer,Value},_Mod) ->
    io_lib:format("~p", [Value]);
typeref({float,Value},_Mod) ->
    io_lib:format("~p", [Value]);
typeref({range,Lo,Hi},_Mod) ->
    io_lib:format("~p..~p", [Lo, Hi]);
typeref({atom,Value},_Mod) ->
    io_lib:format("{\"$A\" : \"~p\"}", [Value]);
typeref({string,Value},_Mod) ->
    io_lib:format("{\"$S\" : \"~p\"}", [Value]);
typeref({binary,Value},_Mod) ->
    io_lib:format("\"~p\"", [Value]);
typeref({alt,Type1,Type2},Mod) ->
    io_lib:format("~s | ~s", [typeref(Type1, Mod), typeref(Type2, Mod)]);
typeref({concat,Type1,Type2},Mod) ->
    io_lib:format("~s++~s", [typeref(Type1, Mod), typeref(Type2, Mod)]);
typeref({list_optional,Element},Mod) ->
    io_lib:format("[~s]?", [typeref(Element, Mod)]);
typeref({list_nil,Element},Mod) ->
    io_lib:format("[~s]{0}", [typeref(Element, Mod)]);
typeref({list_required,Element},Mod) ->
    io_lib:format("[~s]{1}", [typeref(Element, Mod)]);
typeref({list,Element},Mod) ->
    io_lib:format("[~s]", [typeref(Element, Mod)]);
typeref({list_required_and_repeatable,Element},Mod) ->
    io_lib:format("[~s]+", [typeref(Element, Mod)]);
typeref(Type, _Mod) ->
    io_lib:format("~p()", [Type]).

ubf_contract(Mod, FileName) ->
    Contract = ubf_contract(Mod),
    file:write_file(FileName, Contract).

ubf_contract(Mod) when is_list(Mod) ->
    ubf_contract(list_to_atom(Mod));
ubf_contract(Mod) ->
    X0 = [""
          , "///"
          , "/// Auto-generated by jsf_utils:ubf_contract()"
          , "/// Do not edit manually!"
          , "///"
          , ""
          , ""
         ],
    X1 = ["// --------------------"
          , "// pre defined types"
          , "//   - left hand-side is UBF"
          , "//   - right hand-side is JSON"
          , "//   - A() means replace with \"A type reference\""
          , "//   - A() | B() means \"A() or B()\""
          , "//   - A()? means \"optional A()\""
          , "//   - A()++B() means \"list A() concatenate list B()"
          , "//   - A(Attrs) means \"A() subject to the comma-delimited type attributes"
          , "//"
          , ""
          , "integer()\n\t\tint"
          , "integer()?\n\t\tint | null"
          , ""
          , "float()\n\t\tint frac"
          , "float()?\n\t\tint frac | null"
          , ""
          , "integer()..integer()\n\t\tint"
          , ""
          , "atom()\n\t\t{\"$A\" : string }"
          , "atom()?\n\t\t{\"$A\" : string } | null"
          , "atom(AtomAttrs)\n\t\t{\"$A\" : string }"
          , "atom(AtomAttrs)?\n\t\t{\"$A\" : string } | null"
          , ""
          , "string()\n\t\t{\"$S\" : string }"
          , "string()?\n\t\t{\"$S\" : string } | null"
          , "string(StringAttrs)\n\t\t{\"$S\" : string }"
          , "string(StringAttrs)?\n\t\t{\"$S\" : string } | null"
          , ""
          , "binary()\n\t\tstring"
          , "binary()?\n\t\tstring | null"
          , "binary(BinaryAttrs)\n\t\tstring"
          , "binary(BinaryAttrs)?\n\t\tstring | null"
          , ""
          , "tuple()\n\t\t{\"$T\" : array }"
          , "tuple()?\n\t\t{\"$T\" : array } | null"
          , ""
          , "record()\n\t\t{\"$R\" : string, pair ... }"
          , "record()?\n\t\t{\"$R\" : string, pair ... } | null"
          , ""
          , "list()\n\t\tarray"
          , "list()?\n\t\tarray | null"
          , "list(){0}\n\t\t[]"
          , "list(){1}\n\t\t[ value ]"
          , "list()+\n\t\t[ elements ]"
          , "list()++list()\n\t\tarray"
          , ""
          , "term()\n\t\tvalue"
          , "term()?\n\t\tvalue | null"
          , "term(TermAttrs)\n\t\tvalue"
          , "term(TermAttrs)?\n\t\tvalue | null"
          , ""
          , "void()\n\t\t /* no result is returned */"
          , "void()?\n\t\t /* no result is returned */ | null"
          , ""
          , "true\n\t\ttrue"
          , "false\n\t\tfalse"
          , "undefined\n\t\tnull"
          , ""
          , "// --------------------"
          , "// type attributes"
          , "//"
          , ""
          , "AtomAttrs"
          , "\t ascii | asciiprintable"
          , "\t nonempty"
          , "\t nonundefined"
          , ""
          , "StringAttrs"
          , "\t ascii | asciiprintable"
          , "\t nonempty"
          , ""
          , "BinaryAttrs"
          , "\t ascii | asciiprintable"
          , "\t nonempty"
          , ""
          , "TermAttrs"
          , "\t nonempty"
          , "\t nonundefined"
          , ""
          , "// --------------------"
          , "// leaf types"
          , "//"
          , ""
          , ""
         ],
    X2 = [ [atom_to_list(Name), "()", "\n", ubf(Name,Mod)]
           || Name <- lists:sort(Mod:contract_leaftypes()) ],
    X3 = [""
          , "// --------------------"
          , "// JSON-RPC"
          , "//"
          , ""
         ],
    X4 = [ begin
               Params =
                   case get_type(Input,true,Mod) of
                       {Input, {tuple, Elements1}, _} ->
                           io_lib:format("[ ~s ]", [join([typeref(E, Mod) || E <- tl(Elements1), E =/= {prim,authinfo}], ", ")]);
                       {Input, {atom, _Atom}, _} ->
                           io_lib:format("[]", [])
                   end,
               Result =
                   case get_type(Output,false,Mod) of
                       {Output, OutputType, _} ->
                           typeref(OutputType, Mod);
                       undefined ->
                           io_lib:format("~p()", [Output])
                   end,
               join([
                     ""
                     , "// ----------"
                     , io_lib:format("// ~p", [Input])
                     , "//"
                     , "request {"
                     , io_lib:format("\t\"version\" : \"1.1\"", [])
                     , io_lib:format("\t\"id\"      : binary()", [])
                     , io_lib:format("\t\"method\"  : \"~p\"", [Input])
                     , io_lib:format("\t\"params\"  : ~s", [Params])
                     , " }"
                     , "response {"
                     , io_lib:format("\t\"version\" : \"1.1\"", [])
                     , io_lib:format("\t\"id\"      : binary()", [])
                     , io_lib:format("\t\"result\"  : ~s | null", [Result])
                     , io_lib:format("\t\"error\"   : term()?", [])
                     , " }"
                    ], "\n")
           end
           || {{prim,Input}, {prim,Output}} <- Mod:contract_anystate() ],
    lists:flatten([ join(L, "\n") || L <- [X0, X1, X2, X3, X4] ]).

join(L, Sep) ->
    lists:flatten(join2(L, Sep)).

join2([A, B|Rest], Sep) ->
    [A, Sep|join2([B|Rest], Sep)];
join2(L, _Sep) ->
    L.

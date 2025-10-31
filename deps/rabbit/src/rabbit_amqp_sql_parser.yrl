%%% This is the grammar file for SQL Filter Expressions:
%%% https://docs.oasis-open.org/amqp/filtex/v1.0/csd01/filtex-v1.0-csd01.html#_Toc67929276
%%%
%%% To manually generate the parser file rabbit_amqp_sql_parser.erl run:
%%% yecc:file("rabbit_amqp_sql_parser.yrl", [deterministic]).

Nonterminals
    selector
    conditional_expr
    comparison_expr
    logical_expr
    additive_expr
    multiplicative_expr
    unary_expr
    primary
    literal
    identifier_expr
    expression_list
    in_expr
    like_expr
    is_null_expr
    function_call.

Terminals
    integer float boolean string binary identifier
    '=' '<>' '>' '<' '>=' '<='
    '+' '-' '*' '/' '%'
    'AND' 'OR' 'NOT'
    'LIKE' 'IN' 'IS' 'NULL' 'ESCAPE'
    'UTC'
    '(' ')' ','.

Rootsymbol selector.

%% operator precedences (lowest to highest)
Left 100 'OR'.
Left 200 'AND'.
Nonassoc 300 '=' '<>' '>' '<' '>=' '<='.
Left 400 '+' '-'.
Left 500 '*' '/' '%'.
Unary 600 'NOT'.

%% "A selector is a conditional expression"
selector -> conditional_expr : '$1'.

%% Conditional expressions
conditional_expr -> logical_expr : '$1'.

%% Logical expressions
logical_expr -> logical_expr 'AND' logical_expr : {'and', '$1', '$3'}.
logical_expr -> logical_expr 'OR' logical_expr : {'or', '$1', '$3'}.
logical_expr -> 'NOT' logical_expr : {'not', '$2'}.
logical_expr -> comparison_expr : '$1'.

%% Comparison expressions
comparison_expr -> additive_expr '=' additive_expr : {'=', '$1', '$3'}.
comparison_expr -> additive_expr '<>' additive_expr : {'<>', '$1', '$3'}.
comparison_expr -> additive_expr '>' additive_expr : {'>', '$1', '$3'}.
comparison_expr -> additive_expr '<' additive_expr : {'<', '$1', '$3'}.
comparison_expr -> additive_expr '>=' additive_expr : {'>=', '$1', '$3'}.
comparison_expr -> additive_expr '<=' additive_expr : {'<=', '$1', '$3'}.
comparison_expr -> like_expr : '$1'.
comparison_expr -> in_expr : '$1'.
comparison_expr -> is_null_expr : '$1'.
comparison_expr -> additive_expr : '$1'.

%% LIKE expression
like_expr -> additive_expr 'LIKE' string :
    {'like', '$1', process_like_pattern('$3'), no_escape}.
like_expr -> additive_expr 'LIKE' string 'ESCAPE' string :
    {'like', '$1', process_like_pattern('$3'), process_escape_char('$5')}.
like_expr -> additive_expr 'NOT' 'LIKE' string :
    {'not', {'like', '$1', process_like_pattern('$4'), no_escape}}.
like_expr -> additive_expr 'NOT' 'LIKE' string 'ESCAPE' string :
    {'not', {'like', '$1', process_like_pattern('$4'), process_escape_char('$6')}}.

%% IN expression
in_expr -> additive_expr 'IN' '(' expression_list ')' : {'in', '$1', '$4'}.
in_expr -> additive_expr 'NOT' 'IN' '(' expression_list ')' : {'not', {'in', '$1', '$5'}}.
expression_list -> additive_expr : ['$1'].
expression_list -> additive_expr ',' expression_list : ['$1'|'$3'].

%% IS NULL expression
is_null_expr -> identifier_expr 'IS' 'NULL' : {'is_null', '$1'}.
is_null_expr -> identifier_expr 'IS' 'NOT' 'NULL' : {'not', {'is_null', '$1'}}.

%% Arithmetic expressions
additive_expr -> additive_expr '+' multiplicative_expr : {'+', '$1', '$3'}.
additive_expr -> additive_expr '-' multiplicative_expr : {'-', '$1', '$3'}.
additive_expr -> multiplicative_expr : '$1'.

multiplicative_expr -> multiplicative_expr '*' unary_expr : {'*', '$1', '$3'}.
multiplicative_expr -> multiplicative_expr '/' unary_expr : {'/', '$1', '$3'}.
multiplicative_expr -> multiplicative_expr '%' unary_expr : {'%', '$1', '$3'}.
multiplicative_expr -> unary_expr : '$1'.

%% Handle unary operators through grammar structure instead of precedence
unary_expr -> '+' primary : {unary_plus, '$2'}.
unary_expr -> '-' primary : {unary_minus, '$2'}.
unary_expr -> primary : '$1'.

%% Primary expressions
primary -> '(' conditional_expr ')' : '$2'.
primary -> literal : '$1'.
primary -> identifier_expr : '$1'.
primary -> function_call : '$1'.

%% Function calls
function_call -> 'UTC' '(' ')' : {function, 'UTC', []}.

%% Identifiers (header fields or property references)
identifier_expr -> identifier :
    {identifier, extract_value('$1')}.

%% Literals
literal -> integer : {integer, extract_value('$1')}.
literal -> float : {float, extract_value('$1')}.
literal -> string : {string, extract_value('$1')}.
literal -> binary : {binary, extract_value('$1')}.
literal -> boolean : {boolean, extract_value('$1')}.

Erlang code.

extract_value({_Token, _Line, Value}) -> Value.

process_like_pattern({string, Line, Value}) ->
    case unicode:characters_to_list(Value) of
        L when is_list(L) ->
            L;
        _ ->
            return_error(Line, "pattern-value in LIKE must be valid Unicode")
    end.

process_escape_char({string, Line, Value}) ->
    case unicode:characters_to_list(Value) of
        [SingleChar] ->
            SingleChar;
        _ ->
            return_error(Line, "ESCAPE must be a single-character string literal")
    end.

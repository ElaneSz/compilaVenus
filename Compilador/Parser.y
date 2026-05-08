{
module Parser where

import Token
import AST
}

%name parser
%tokentype { Token }
%error { parseError }

%token
    int        { TKint }
    double     { TKdouble }
    string     { TKstring }
    void       { TKvoid }
    if         { TKif }
    else       { TKelse }
    while      { TKwhile }
    print      { TKprint }
    return     { TKreturn }
    '+'        { TKmais }
    '-'        { TKmenos }
    '*'        { TKmult }
    '/'        { TKdiv }
    '<'        { TKlt }
    '>'        { TKgt }
    '<='       { TKle }
    '>='       { TKge }
    '=='       { TKeq }
    '/='       { TKdif }
    '&&'       { TKand }
    '||'       { TKor }
    '!'        { TKnot }
    '='        { TKatrib }
    '('        { TKabreP }
    ')'        { TKfechaP }
    '{'        { TKabreC }
    '}'        { TKfechaC }
    ','        { TKvirgula }
    ';'        { TKponto_e_virgula }
    id         { TKid $$ }
    int_lit    { TKint_lit $$ }
    double_lit { TKdouble_lit $$ }
    string_lit { TKstring_lit $$ }

%left '||' '&&'
%right '!'
%left '<' '>' '<=' '>=' '==' '/='
%left '+' '-'
%left '*' '/'
%left NEG

%%

-- REGRAS AQUI



Tipo : int    { TInt }
     | double { TDouble }
     | string { TString }

ListaId : ListaId ',' id  { $1 ++ [$3] }
        | id              { [$1] }

TipoRet : Tipo  { $1 }
        | void  { TVoid }

-- O Int é o índice da variável (para geração de código depois). Por enquanto pode usar 0
ParamFormal : Tipo id { $2 :#: ($1, 0) }

ExpressaoAritmetica : int_lit    { Const (CInt $1) }
                    | double_lit { Const (CDouble $1) }
                    | id         { IdVar $1 }
                    | '(' ExpressaoAritmetica ')' { $2 }
                    | ExpressaoAritmetica '+' ExpressaoAritmetica { Add $1 $3 }
                    | ExpressaoAritmetica '-' ExpressaoAritmetica { Sub $1 $3 }
                    | ExpressaoAritmetica '*' ExpressaoAritmetica { Mul $1 $3 }
                    | ExpressaoAritmetica '/' ExpressaoAritmetica { Div $1 $3 }
                    | '-' ExpressaoAritmetica %prec NEG           { Neg $2 }
                    | ChamadaFuncao                               { $1 }

ExpressaoRelacional : ExpressaoAritmetica '<'  ExpressaoAritmetica { Rlt $1 $3 }
                    | ExpressaoAritmetica '>'  ExpressaoAritmetica { Rgt $1 $3 }
                    | ExpressaoAritmetica '<=' ExpressaoAritmetica { Rle $1 $3 }
                    | ExpressaoAritmetica '>=' ExpressaoAritmetica { Rge $1 $3 }
                    | ExpressaoAritmetica '==' ExpressaoAritmetica { Req $1 $3 }
                    | ExpressaoAritmetica '/=' ExpressaoAritmetica { Rdif $1 $3 }

ExpressaoLogica : ExpressaoLogica '&&' ExpressaoLogica { And $1 $3 }
                | ExpressaoLogica '||' ExpressaoLogica { Or $1 $3 }
                | '!'  ExpressaoLogica                 { Not $2 }
                | ExpressaoRelacional                  { Rel $1 }

ParamReais : ParamReais ',' ExpressaoAritmetica { $1 ++ [$3] }
           | ParamReais ',' string_lit          { $1 ++ [Lit $3] }
           | ExpressaoAritmetica                { [$1] }
           | string_lit                         { [Lit $1] }

ChamadaFuncao : id '(' ParamReais ')' { Chamada $1 $3 }
              | id '(' ')'            { Chamada $1 [] }

CmdAtrib : id '=' ExpressaoAritmetica ';' { Atrib $1 $3 }
         | id '=' string_lit ';'          { Atrib $1 (Lit $3) }

CmdEscrita : print '(' ExpressaoAritmetica ')' ';' { Imp $3 }
           | print '(' string_lit ')' ';'          { Imp (Lit $3) } 

-- $3 é String, mas Imp espera Expr

Retorno : return ExpressaoAritmetica ';' { Ret (Just  $2) }
        | return string_lit ';'          { Ret (Just  (Lit $2)) }
        | return ';'                     { Ret Nothing }

ChamadaProc : id '(' ParamReais ')' ';' { Proc $1 $3 }
            | id '(' ')' ';'            { Proc $1 [] }

CmdSe : if '(' ExpressaoLogica ')' Bloco            { If $3 $5 [] }
      | if '(' ExpressaoLogica ')' Bloco else Bloco { If $3 $5 $7 }

CmdEnquanto : while '(' ExpressaoLogica ')' Bloco { While $3 $5 }

Comando : CmdSe       { $1 }
        | CmdEnquanto { $1 }
        | CmdAtrib    { $1 }
        | CmdEscrita  { $1 }
        | Retorno     { $1 }
        | ChamadaProc { $1 }

ListaCmd : ListaCmd Comando { $1 ++ [$2] }
         | Comando          { [$1] }

Bloco : '{' ListaCmd '}' { $2 }




{
parseError :: [Token] -> a
parseError tokens = error $ "Erro sintático: " ++ show tokens
}
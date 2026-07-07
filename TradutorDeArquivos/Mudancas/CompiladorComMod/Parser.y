{
module Parser where

import Token
import AST
import FuncAux
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
    read       { TKread }
    '+'        { TKmais }
    '-'        { TKmenos }
    '*'        { TKmult }
    '/'        { TKdiv }
    '%'        { TKmod }
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
-- mod tem a mesma precedência que '*' e '/'
%left '*' '/' '%'
%left NEG

%%

-- REGRAS AQUI


-- pra executar, é só dar "cat Teste.j-- | ./compilador" no terminal

-- nivel 1: Feito e funcionando
-- nivel 2: Feito e funcionando
-- nível 3: Feito e funcionando
-- nivel 4: Feito e funcionando 
-- nível 5: Feito e funcionando 

-- não estamos considerando for

-- ==== NIVEL 5 ====

--tava dando problema aq (o lista funcoes recebe uma LISTA de (Funcoes, BlocoPrincipal), dai dava problema em só ter o fst, q só funciona com uma tupla)
Programa : ListaFuncoes BlocoPrincipal { Prog (map fst $1) (geraFuncaoCompleta $1) (fst $2) (snd $2)}
         | BlocoPrincipal              { Prog [] [] (fst $1) (snd $1)}


ListaFuncoes : ListaFuncoes Funcao { $1 ++ [$2] }
             | Funcao              { [$1] }


Funcao : TipoRet id '(' ParamFormais ')' BlocoPrincipal { ($2 :->: ($4, $1), $6) }
       | TipoRet id '(' ')' BlocoPrincipal              { ($2 :->: ([], $1), $5) }
        

BlocoPrincipal : '{' Declaracoes ListaCmd '}' { ($2, $3) }
               | '{' ListaCmd '}'             { ([], $2) }

ParamFormais : ParamFormais ',' ParamFormal { $1 ++ [$3] }
             | ParamFormal                  { [$1] }

ParamFormal : Tipo id { $2 :#: ($1, 0) }

-- dei uma ajeitada aqui também q tava dando problema, ele retornava [[Var]], ai eu tirei as chaves do $1 ++ [$2] pra retornar só [Var] e facilitar um pouco na FuncAux 
Declaracoes : Declaracoes Declaracao { $1 ++ $2 }
            | Declaracao             { $1 }

-- O Int é o índice da variável (para geração de código depois). Por enquanto pode usar 0
Declaracao : Tipo ListaId ';' { map (\x -> x :#: ($1, 0)) $2 }

-- ==== NIVEL 5 ====

-- ==== NIVEL 4 ====

Bloco : '{' ListaCmd '}' { $2 }

ListaCmd : ListaCmd Comando { $1 ++ [$2] }
         | Comando          { [$1] }

Comando : CmdSe       { $1 }
        | CmdEnquanto { $1 }
        | CmdAtrib    { $1 }
        | CmdEscrita  { $1 }
        | Retorno     { $1 }
        | CmdLeitura  { $1 }
        | ChamadaProc { $1 }
        
CmdSe : if '(' ExpressaoLogica ')' Bloco            { If $3 $5 [] }
      | if '(' ExpressaoLogica ')' Bloco else Bloco { If $3 $5 $7 }

CmdEnquanto : while '(' ExpressaoLogica ')' Bloco { While $3 $5 }

-- ==== NIVEL 4 ====

-- ==== NIVEL 3 ====

CmdAtrib : id '=' ExpressaoAritmetica ';' { Atrib $1 $3 }
         | id '=' string_lit ';'          { Atrib $1 (Lit $3) }

CmdEscrita : print '(' ExpressaoAritmetica ')' ';' { Imp $3 }
           | print '(' string_lit ')' ';'          { Imp (Lit $3) } 

CmdLeitura : read '(' id ')' ';' { Leitura $3 }



Retorno : return ExpressaoAritmetica ';' { Ret (Just  $2) }
        | return string_lit ';'          { Ret (Just  (Lit $2)) }
        | return ';'                     { Ret Nothing }

ChamadaProc : id '(' ParamReais ')' ';' { Proc $1 $3 }
            | id '(' ')' ';'            { Proc $1 [] }
            
-- ==== NIVEL 3 ==== 

-- ==== NIVEL 2 ====

ExpressaoAritmetica : int_lit                                      { Const (CInt $1) }
                    | double_lit                                   { Const (CDouble $1) }
                    | id                                           { IdVar $1 }
                    | '(' ExpressaoAritmetica ')'                  { $2 }
                    | ExpressaoAritmetica '+' ExpressaoAritmetica  { Add $1 $3 }
                    | ExpressaoAritmetica '-' ExpressaoAritmetica  { Sub $1 $3 }
                    | ExpressaoAritmetica '*' ExpressaoAritmetica  { Mul $1 $3 }
                    | ExpressaoAritmetica '/' ExpressaoAritmetica  { Div $1 $3 }
                    | ExpressaoAritmetica '%' ExpressaoAritmetica  { Mod $1 $3 }
                    | '-' ExpressaoAritmetica %prec NEG            { Neg $2 }
                    | ChamadaFuncao                                { $1 }

ExpressaoRelacional : ExpressaoAritmetica '<'  ExpressaoAritmetica { Rlt $1 $3 }
                    | ExpressaoAritmetica '>'  ExpressaoAritmetica { Rgt $1 $3 }
                    | ExpressaoAritmetica '<=' ExpressaoAritmetica { Rle $1 $3 }
                    | ExpressaoAritmetica '>=' ExpressaoAritmetica { Rge $1 $3 }
                    | ExpressaoAritmetica '==' ExpressaoAritmetica { Req $1 $3 }
                    | ExpressaoAritmetica '/=' ExpressaoAritmetica { Rdif $1 $3 }

ExpressaoLogica : ExpressaoLogica '&&' ExpressaoLogica { And $1 $3 }
                | ExpressaoLogica '||' ExpressaoLogica { Or $1 $3 }
                | '!'  ExpressaoLogica                 { Not $2 }
                | '!' '(' ExpressaoLogica ')'          { Not $3 }
                | ExpressaoRelacional                  { Rel $1 }

ChamadaFuncao : id '(' ParamReais ')' { Chamada $1 $3 }
              | id '(' ')'            { Chamada $1 [] }

ParamReais : ParamReais ',' ExpressaoAritmetica { $1 ++ [$3] }
           | ParamReais ',' string_lit          { $1 ++ [Lit $3] }
           | ExpressaoAritmetica                { [$1] }
           | string_lit                         { [Lit $1] }

-- ==== NIVEL 2 ====

-- ==== NIVEL 1 ====

Tipo : int    { TInt }
     | double { TDouble }
     | string { TString }

ListaId : ListaId ',' id  { $1 ++ [$3] }
        | id              { [$1] }

TipoRet : Tipo  { $1 }
        | void  { TVoid }

-- ==== NIVEL 1 ====

{
parseError :: [Token] -> a
parseError tokens = error $ "Erro sintático: " ++ show tokens
}

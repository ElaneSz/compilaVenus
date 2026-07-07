{
module Lex where

import Token
}

%wrapper "basic"

-- Definições de conjuntos de caracteres
$digit  = [0-9]
$alpha  = [a-zA-Z]
$alnum  = [a-zA-Z0-9_]
$any    = [.\n]

:-

-- Ignorar espaços e quebras de linha
$white+   ;

-- Comentarios (precisam vir antes das regras de operador, pra "//" e "/*"
-- ganharem do "/" de divisao por maximal munch) (entre todas as regras que casam a 
-- partir da posição atual, ele sempre escolhe a que casa o trecho mais longo)

-- lê tudo que não seja uma quebra de linha
"//" [^\n]*;

-- na parte 1: o comentário pode conter quebra de linha ou qualquer coisa que não seja um asterísco
-- na parte 2: OU, o comentário pode conter 1 ou mais asteríscos concatenados com quebra de linha, ou qualquer coisa que não seja asterísco ou "/"
-- na parte 3: fechamento correto do comentário

--           1              2               3
"/*" (([^\*] | \n) | \*+ ([^\*\/] | \n))* \*+ "/";

-- Palavras reservadas (devem vir ANTES da regra de identificador)
"int"     { \s -> TKint }
"double"  { \s -> TKdouble }
"string"  { \s -> TKstring }
"void"    { \s -> TKvoid }
"if"      { \s -> TKif }
"else"    { \s -> TKelse }
"while"   { \s -> TKwhile }
"print"   { \s -> TKprint }
"return"  { \s -> TKreturn }

-- Identificador (depois das palavras reservadas)
"read"    { \s -> TKread }
$alpha $alnum*  { \s -> TKid s }

-- Constantes numéricas (double antes de int)
$digit+ \. $digit+  { \s -> TKdouble_lit (read s) }
$digit+             { \s -> TKint_lit (read s) }

-- String literal
\" [^\"]* \"  { \s -> TKstring_lit (init (tail s)) }

-- Operadores relacionais (os de 2 chars antes dos de 1 char)
"<="  { \s -> TKle }
">="  { \s -> TKge }
"=="  { \s -> TKeq }
"/="  { \s -> TKdif }
"<"   { \s -> TKlt }
">"   { \s -> TKgt }

-- Operadores lógicos
"&&"  { \s -> TKand }
"||"  { \s -> TKor }
"!"   { \s -> TKnot }

-- Operadores aritméticos
"+"   { \s -> TKmais }
"-"   { \s -> TKmenos }
"*"   { \s -> TKmult }
"/"   { \s -> TKdiv }

-- Atribuição e pontuação
"="   { \s -> TKatrib }
"("   { \s -> TKabreP }
")"   { \s -> TKfechaP }
"{"   { \s -> TKabreC }
"}"   { \s -> TKfechaC }
","   { \s -> TKvirgula }
";"   { \s -> TKponto_e_virgula }

-- Para teste:
    -- alex Lexer.x
    -- ghci Lexer.hs Token.hs
    -- alexScanTokens "int x; x = 3 + 2;"
    -- Resultado: [TKint, TKid "x", TKponto_e_virgula, TKid "x", TKatrib, TKint_lit 3, TKmais, TKint_lit 2, TKponto_e_virgula]
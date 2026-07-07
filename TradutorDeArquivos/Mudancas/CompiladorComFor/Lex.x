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

-- Palavras reservadas (devem vir ANTES da regra de identificador)
"int"     { \s -> TKint }
"double"  { \s -> TKdouble }
"string"  { \s -> TKstring }
"void"    { \s -> TKvoid }
"if"      { \s -> TKif }
"else"    { \s -> TKelse }
"while"   { \s -> TKwhile }
"for"     { \s -> TKfor }
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
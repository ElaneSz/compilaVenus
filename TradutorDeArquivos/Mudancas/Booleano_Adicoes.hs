-- =============================================================================
-- ADIÇÕES PARA SUPORTE AO TIPO BOOLEANO
-- =============================================================================
-- Este arquivo contém todas as alterações necessárias para adicionar o tipo
-- booleano ao compilador. As seções estão marcadas com o arquivo de destino
-- e onde colar cada trecho.
-- =============================================================================


-- =============================================================================
-- [1] AST.hs
-- =============================================================================
-- ONDE COLAR: em data Tipo, adicione TBool ao lado dos outros tipos
-- ANTES:
--   data Tipo = TDouble | TInt | TString | TVoid deriving (Show, Eq)
-- DEPOIS:
--   data Tipo = TDouble | TInt | TString | TVoid | TBool deriving (Show, Eq)

-- ONDE COLAR: em data Expr, adicione BoolLit para literais booleanos
-- ANTES:
--   data Expr = Add Expr Expr | ... | IntDouble Expr | DoubleInt Expr deriving Show
-- DEPOIS:
--   data Expr = Add Expr Expr | ... | IntDouble Expr | DoubleInt Expr
--             | BoolLit Bool deriving Show
--
-- Isso permite escrever: bool b; b = true;
-- BoolLit True  → constante true
-- BoolLit False → constante false


-- =============================================================================
-- [2] Token.hs
-- =============================================================================
-- ONDE COLAR: na seção de palavras reservadas, junto com TKint, TKdouble, etc.
-- ANTES:
--   = TKint | TKdouble | TKstring | TKvoid
--   | TKif | TKelse | TKwhile | TKprint | TKreturn
-- DEPOIS:
--   = TKint | TKdouble | TKstring | TKvoid | TKbool
--   | TKif | TKelse | TKwhile | TKprint | TKreturn
--   | TKtrue | TKfalse


-- =============================================================================
-- [3] Lex.x
-- =============================================================================
-- ONDE COLAR: na seção de palavras reservadas, junto com "int", "double", etc.
-- Deve vir ANTES da regra de identificador ($alpha $alnum*)
--
-- "bool"    { \s -> TKbool  }
-- "true"    { \s -> TKtrue  }
-- "false"   { \s -> TKfalse }


-- =============================================================================
-- [4] Parser.y
-- =============================================================================
-- ONDE COLAR (a): na seção %token, junto com int, double, string, void
--
--     bool       { TKbool  }
--     true       { TKtrue  }
--     false      { TKfalse }

-- ONDE COLAR (b): na regra Tipo, junto com int, double, string
-- ANTES:
--   Tipo : int    { TInt }
--        | double { TDouble }
--        | string { TString }
-- DEPOIS:
--   Tipo : int    { TInt }
--        | double { TDouble }
--        | string { TString }
--        | bool   { TBool }

-- ONDE COLAR (c): em ExpressaoAritmetica, junto com int_lit, double_lit, etc.
-- Literais booleanos podem aparecer em expressões e atribuições
-- ANTES:
--   ExpressaoAritmetica : int_lit    { Const (CInt $1) }
--                       | double_lit { Const (CDouble $1) }
--                       | ...
-- DEPOIS:
--   ExpressaoAritmetica : int_lit    { Const (CInt $1) }
--                       | double_lit { Const (CDouble $1) }
--                       | true       { BoolLit True  }
--                       | false      { BoolLit False }
--                       | ...

-- ONDE COLAR (d): em CmdAtrib, para permitir atribuição de bool
-- ANTES:
--   CmdAtrib : id '=' ExpressaoAritmetica ';' { Atrib $1 $3 }
--            | id '=' string_lit ';'          { Atrib $1 (Lit $3) }
-- DEPOIS:
--   CmdAtrib : id '=' ExpressaoAritmetica ';' { Atrib $1 $3 }
--            | id '=' string_lit ';'          { Atrib $1 (Lit $3) }
--            | id '=' true  ';'               { Atrib $1 (BoolLit True)  }
--            | id '=' false ';'               { Atrib $1 (BoolLit False) }


-- =============================================================================
-- [5] Semantico.hs
-- =============================================================================

-- ONDE COLAR (a): em verificaExpr, junto com os outros casos de Const e Lit
-- Adicione ANTES do caso IdVar:
--
--   verificaExpr tg tl (BoolLit b) = return (BoolLit b, TBool)

-- ONDE COLAR (b): em verificaComando, no case (tipoVar, tipoExpr) dentro de Atrib
-- Adicione o caso de bool junto com (TInt,TInt), (TDouble,TDouble), etc.
-- ANTES do _ final:
--
--   (TBool, TBool) -> return (Atrib nome e')

-- ONDE COLAR (c): em verificaComando, no case (tr, tipoExpr) dentro de Ret (Just e)
-- Adicione junto com (TInt,TInt), (TDouble,TDouble), etc.
-- ANTES do _ final:
--
--   (TBool, TBool) -> return (Ret (Just e'))

-- ONDE COLAR (d): em coerceArg, no case (tipoParam, tipoArg)
-- Adicione junto com (TInt,TInt), (TDouble,TDouble), (TString,TString):
--
--   (TBool, TBool) -> return e


-- =============================================================================
-- [6] Gerador.hs
-- =============================================================================

-- ONDE COLAR (a): em tipoJVM, junto com TInt, TDouble, TString, TVoid
-- Na JVM, boolean é representado como int (Z é o descritor formal,
-- mas iconst_0/iconst_1 + istore/iload funcionam igual a int)
--
--   tipoJVM TBool = "Z"

-- ONDE COLAR (b): em tamanhoTipo, junto com TDouble
-- Bool ocupa 1 slot (igual a int)
-- Não precisa alterar — o caso _ já cobre TBool com 1 slot.
-- Só documente:
--
--   tamanhoTipo TDouble = 2
--   tamanhoTipo _       = 1  -- cobre TInt, TString, TVoid, TBool

-- ONDE COLAR (c): em genExpr, junto com Const (CInt n), Const (CDouble d), Lit s
-- Adicione ANTES do caso IdVar:
--
--   genExpr c tg tl ti (BoolLit True)  = return (TBool, "\ticonst_1\n")
--   genExpr c tg tl ti (BoolLit False) = return (TBool, "\ticonst_0\n")
--
-- Na JVM não existe tipo booleano primitivo em bytecode — booleans são
-- representados como int: 1 = true, 0 = false.

-- ONDE COLAR (d): em genCmd, no case t dentro de Atrib (istore/dstore/astore)
-- Bool usa istore/iload igual a int — já coberto pelo caso TInt.
-- Não precisa alterar.

-- ONDE COLAR (e): em genCmd, no case t dentro de Ret (Just e)
-- Bool usa ireturn igual a int — já coberto pelo caso TInt.
-- Não precisa alterar.

-- ONDE COLAR (f): em genCmd, no case t dentro de Imp
-- Se quiser suportar print de bool, adicione junto com TInt, TDouble:
--
--   TBool -> "\tinvokevirtual java/io/PrintStream/print(Z)V\n"
--
-- Ou, para imprimir "true"/"false" em vez de 1/0, gere uma chamada
-- para Boolean.toString antes do print — mais complexo, opcional.

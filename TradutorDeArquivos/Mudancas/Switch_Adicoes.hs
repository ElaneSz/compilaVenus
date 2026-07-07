-- =============================================================================
-- ADIÇÕES PARA SUPORTE AO SWITCH/CASE
-- =============================================================================
-- Sintaxe suportada:
--
--   switch (expr) {
--       case 1: { ... }
--       case 2: { ... }
--       default: { ... }
--   }
--
-- RESTRIÇÕES (igual a Java/C simplificado):
--   - A expressão do switch deve ser do tipo Int
--   - Os valores de cada case devem ser constantes inteiras (int_lit)
--   - default é opcional, mas só pode aparecer uma vez
--   - Não há fall-through: cada case é um bloco isolado (sem break necessário)
--
-- DECISÃO DE DESIGN — geração de código:
--   Switch é compilado como cadeia de if/else usando tableswitch do Jasmin.
--   Cada case vira uma comparação "expr == valor" seguida de salto.
--   Reutilizamos genExpr, genBloco e novoLabel que já existem.
--
-- ALTERAÇÕES NECESSÁRIAS:
--   AST.hs      → 1 novo construtor em Comando
--   Token.hs    → 2 novos tokens (TKswitch, TKcase, TKdefault)
--   Lex.x       → 3 novas regras
--   Parser.y    → novas regras gramaticais
--   Semantico.hs → 1 novo caso em verificaComando
--   Gerador.hs  → 1 nova função genSwitch + 1 novo caso em genCmd
-- =============================================================================


-- =============================================================================
-- [1] AST.hs
-- =============================================================================
-- ONDE COLAR: em data Comando, adicione Switch ao lado de If e While
--
-- ANTES:
--   data Comando = If ExprL Bloco Bloco
--                | While ExprL Bloco
--                | Atrib Id Expr
--                | ...
--
-- DEPOIS:
--   data Comando = If ExprL Bloco Bloco
--                | While ExprL Bloco
--                | Switch Expr [(Int, Bloco)] (Maybe Bloco)
--                | Atrib Id Expr
--                | ...
--
-- Switch recebe:
--   Expr            → a expressão sendo testada (deve ser TInt)
--   [(Int, Bloco)]  → lista de pares (valor_do_case, bloco_do_case)
--   Maybe Bloco     → o bloco do default (Nothing se não houver)


-- =============================================================================
-- [2] Token.hs
-- =============================================================================
-- ONDE COLAR: na seção de palavras reservadas, junto com TKif, TKwhile, etc.
--
-- ANTES:
--   | TKif | TKelse | TKwhile | TKprint | TKreturn
--
-- DEPOIS:
--   | TKif | TKelse | TKwhile | TKprint | TKreturn
--   | TKswitch | TKcase | TKdefault
--
-- TKcolon (o ':' do case) também precisa ser adicionado:
--
-- ANTES (seção de pontuação):
--   | TKvirgula | TKponto_e_virgula
--
-- DEPOIS:
--   | TKvirgula | TKponto_e_virgula | TKcolon


-- =============================================================================
-- [3] Lex.x
-- =============================================================================
-- ONDE COLAR: na seção de palavras reservadas, junto com "if", "while", etc.
-- Devem vir ANTES da regra de identificador ($alpha $alnum*)
--
-- "switch"  { \s -> TKswitch  }
-- "case"    { \s -> TKcase    }
-- "default" { \s -> TKdefault }
--
-- ONDE COLAR: na seção de pontuação, junto com ";" e ","
-- ":"       { \s -> TKcolon  }


-- =============================================================================
-- [4] Parser.y
-- =============================================================================

-- ONDE COLAR (a): na seção %token, junto com if, else, while, etc.
--
--     switch     { TKswitch  }
--     case       { TKcase    }
--     default    { TKdefault }
--     ':'        { TKcolon   }

-- ONDE COLAR (b): em Comando, junto com CmdSe e CmdEnquanto
--
-- ANTES:
--   Comando : CmdSe       { $1 }
--           | CmdEnquanto { $1 }
--           | CmdAtrib    { $1 }
--           | ...
--
-- DEPOIS:
--   Comando : CmdSe       { $1 }
--           | CmdEnquanto { $1 }
--           | CmdSwitch   { $1 }
--           | CmdAtrib    { $1 }
--           | ...

-- ONDE COLAR (c): novas regras gramaticais — cole junto com CmdSe e CmdEnquanto
-- na seção ==== NIVEL 4 ====

{-

-- Um case individual: "case 42: { ... }"
-- Retorna (Int, Bloco) — o valor inteiro e o bloco associado
CaseClausula : case int_lit ':' Bloco { ($2, $4) }

-- Lista de cases
-- Retorna [(Int, Bloco)]
ListaCases : ListaCases CaseClausula { $1 ++ [$2] }
           | CaseClausula            { [$1] }

-- Cláusula default opcional
-- Retorna Maybe Bloco
DefaultClausula : default ':' Bloco { Just $3 }
                | {- vazio -}       { Nothing }

-- O comando switch completo
-- switch (expr) { cases default? }
CmdSwitch : switch '(' ExpressaoAritmetica ')' '{' ListaCases DefaultClausula '}'
              { Switch $3 $6 $7 }

-}


-- =============================================================================
-- [5] Semantico.hs
-- =============================================================================
-- ONDE COLAR: em verificaComando, junto com os casos de If e While
-- Cole este trecho completo após o caso de While:

{-

verificaComando tg tl tr (Switch expr cases mDefault) = do
    -- 1. verifica a expressão do switch — deve ser TInt
    (expr', tipoExpr) <- verificaExpr tg tl expr
    case tipoExpr of
        TInt -> return ()
        _    -> errorMsg (" Switch requer expressao do tipo Int, recebeu: "
                          ++ show tipoExpr)
    -- 2. verifica cada bloco de case
    cases' <- mapM (verificaCase tg tl tr) cases
    -- 3. verifica o bloco default se existir
    mDefault' <- case mDefault of
                     Nothing  -> return Nothing
                     Just def -> do
                         def' <- mapM (verificaComando tg tl tr) def
                         return (Just def')
    return (Switch expr' cases' mDefault')

-- Função auxiliar: verifica um único case (Int, Bloco)
-- Reutiliza verificaComando para cada comando do bloco
-- NOVA FUNÇÃO — cole junto com verificaComando no Semantico.hs
verificaCase :: TabelaGlobal -> TabelaLocal -> Tipo -> (Int, Bloco)
             -> Result (Int, Bloco)
verificaCase tg tl tr (val, bloco) = do
    bloco' <- mapM (verificaComando tg tl tr) bloco
    return (val, bloco')

-}

-- ONDE COLAR (b): em blocoRetorna/comandoRetorna, para o Switch contribuir
-- para a análise de retorno garantido (opcional mas recomendado)
--
-- ANTES:
--   comandoRetorna (If _ b1 b2) = blocoRetorna b1 && blocoRetorna b2
--   comandoRetorna _            = False
--
-- DEPOIS:
--   comandoRetorna (If _ b1 b2)         = blocoRetorna b1 && blocoRetorna b2
--   comandoRetorna (Switch _ cases mDef) =
--       maybe False blocoRetorna mDef &&    -- default garante retorno
--       all (blocoRetorna . snd) cases      -- todos os cases garantem retorno
--   comandoRetorna _                     = False


-- =============================================================================
-- [6] Gerador.hs
-- =============================================================================
-- Estratégia: Switch é compilado como cadeia de comparações com saltos.
-- Para cada case, comparamos a expressão com o valor e saltamos para o bloco.
-- Ao final de cada bloco, saltamos para o label de saída (fim do switch).
--
-- Exemplo para switch(x) { case 1:{A} case 2:{B} default:{C} }:
--
--   <código de x>
--   dup              ← duplica x na pilha para cada comparação
--   ldc 1
--   if_icmpeq lcase0  ← se x == 1 vai para lcase0
--   dup
--   ldc 2
--   if_icmpeq lcase1  ← se x == 2 vai para lcase1
--   goto ldefault     ← nenhum case bateu, vai para default
-- lcase0:
--   pop              ← descarta a cópia de x da pilha
--   <bloco A>
--   goto lend
-- lcase1:
--   pop
--   <bloco B>
--   goto lend
-- ldefault:
--   pop
--   <bloco C>
-- lend:

-- ONDE COLAR (a): nova função genSwitch — cole junto com genCmd no Gerador.hs
-- É a única função nova necessária. Reutiliza genExpr, genBloco e novoLabel.

{-

genSwitch :: String -> TabelaGlobal -> TabelaLocal -> TabelaIndices
          -> Expr -> [(Int, Bloco)] -> Maybe Bloco
          -> State Int String
genSwitch c tg tl ti expr cases mDefault = do
    -- gera o código da expressão sendo testada
    (_, exprCode) <- genExpr c tg tl ti expr
    -- gera labels únicos para cada case e para o fim
    lend     <- novoLabel
    ldefault <- novoLabel
    caseLabels <- mapM (\_ -> novoLabel) cases

    -- gera o cabeçalho: código da expr + comparações com salto
    -- dup + ldc val + if_icmpeq lcase para cada case
    let cabecalho = concatMap geraComparacao (zip caseLabels cases)
                    ++ "\tgoto " ++ ldefault ++ "\n"
          where
            geraComparacao (lbl, (val, _)) =
                "\tdup\n" ++
                "\tldc " ++ show val ++ "\n" ++
                "\tif_icmpeq " ++ lbl ++ "\n"

    -- gera o corpo de cada case: label + pop + bloco + goto lend
    corpos <- mapM (geraCorpoCase lend) (zip caseLabels cases)

    -- gera o bloco default: label + pop + bloco (sem goto — cai no lend)
    defaultCode <- case mDefault of
                       Nothing  -> return (ldefault ++ ":\n\tpop\n")
                       Just def -> do
                           def' <- genBloco c tg tl ti def
                           return (ldefault ++ ":\n\tpop\n" ++ def')

    return (exprCode ++ cabecalho ++ concat corpos ++ defaultCode ++ lend ++ ":\n")

  where
    geraCorpoCase lend (lbl, (_, bloco)) = do
        bloco' <- genBloco c tg tl ti bloco
        return (lbl ++ ":\n\tpop\n" ++ bloco' ++ "\tgoto " ++ lend ++ "\n")

-}

-- ONDE COLAR (b): em genCmd, novo caso para Switch
-- Cole junto com os casos de If e While:

{-

genCmd c tg tl ti (Switch expr cases mDefault) =
    genSwitch c tg tl ti expr cases mDefault

-}

-- ONDE COLAR (c): em comandoRetorna no Semantico — já documentado na seção [5]


-- =============================================================================
-- EXEMPLO DE USO (arquivo .j--)
-- =============================================================================
-- {
--     int x;
--     x = 2;
--
--     switch (x) {
--         case 1: { print("um");  }
--         case 2: { print("dois"); }
--         case 3: { print("tres"); }
--         default: { print("outro"); }
--     }
--
--     return;
-- }
--
-- Saída esperada: "dois"
--
-- Também funciona com expressões:
--   switch (fat(3)) {
--       case 6:  { print("fatorial de 3 e 6"); }
--       default: { print("outro"); }
--   }

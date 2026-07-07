-- =============================================================================
-- ADIÇÕES PARA SUPORTE À ATRIBUIÇÃO NA DECLARAÇÃO (int x = 5;)
-- =============================================================================
-- Este arquivo contém todas as alterações necessárias para suportar
-- inicialização de variáveis na declaração, como:
--
--   int x = 5;
--   double d = 3.14;
--   string s = "ola";
--   int a = 1, b = 2, c;   ← mix de inicializados e não inicializados
--
-- DECISÃO DE DESIGN:
-- A AST não precisa de nenhum novo construtor. A estratégia é:
--   1. O parser transforma "int x = 5;" em dois resultados separados:
--      - uma Var  "x :#: (TInt, 0)"  que vai para a lista de declarações
--      - um Atrib "Atrib "x" (Const (CInt 5))" que vai para o bloco
--   2. BlocoPrincipal já retorna ([Var], Bloco) — basta acrescentar os
--      Atribs gerados pela inicialização no início do Bloco.
--   3. Semântico e Gerador não precisam de nenhuma alteração — eles já
--      sabem lidar com Var e Atrib separadamente.
--
-- RESUMO DE ALTERAÇÕES: só Lex.x e Parser.y precisam mudar.
-- =============================================================================


-- =============================================================================
-- [1] AST.hs  —  SEM ALTERAÇÕES
-- =============================================================================
-- Nenhuma mudança necessária. Var e Atrib já existem e são suficientes.


-- =============================================================================
-- [2] Token.hs  —  SEM ALTERAÇÕES
-- =============================================================================
-- O token TKatrib ('=') já existe. Nenhum novo token é necessário.


-- =============================================================================
-- [3] Lex.x  —  SEM ALTERAÇÕES
-- =============================================================================
-- A regra "=" -> TKatrib já existe. Nenhuma nova regra é necessária.


-- =============================================================================
-- [4] Parser.y  —  ÚNICA ALTERAÇÃO NECESSÁRIA
-- =============================================================================
-- Toda a lógica está aqui. Precisamos de duas novas regras auxiliares:
--
--   ItemDeclaracao  → um único item que pode ser "id" ou "id = expr"
--   ListaDeclaracao → lista de ItemDeclaracao separados por vírgula
--
-- E substituir a regra Declaracao atual.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- PASSO 1 — Substituir a regra Declaracao (e ListaId que ela usava)
-- ─────────────────────────────────────────────────────────────────────────────
--
-- ONDE COLAR: substitua as regras Declaracao e ListaId atuais por estas.
-- A regra ListaId pode ser mantida se for usada em outro lugar — verifique.
-- No projeto atual ListaId só é usada em Declaracao, então pode substituir.
--
-- ANTES (regras atuais):
--   Declaracao : Tipo ListaId ';' { map (\x -> x :#: ($1, 0)) $2 }
--
--   ListaId : ListaId ',' id  { $1 ++ [$3] }
--           | id              { [$1] }
--
-- DEPOIS (novas regras — cole no lugar das antigas):

--   -- ItemDeclaracao: retorna um par (Var, Maybe Comando)
--   --   "id"         → (Var, Nothing)      sem inicialização
--   --   "id = expr"  → (Var, Just (Atrib)) com inicialização
--   --   "id = str"   → (Var, Just (Atrib)) com string literal
--   ItemDeclaracao : id '=' ExpressaoAritmetica { ($1 :#: ($0, 0), Just (Atrib $1 $3)) }
--                  | id '=' string_lit          { ($1 :#: ($0, 0), Just (Atrib $1 (Lit $3))) }
--                  | id                         { ($1 :#: ($0, 0), Nothing) }
--
--   -- ATENÇÃO: $0 acima não é sintaxe Happy válida!
--   -- O tipo vem do não-terminal Tipo que está FORA de ItemDeclaracao.
--   -- A solução é passar o tipo como parâmetro via ListaDeclaracao.
--   -- Veja a explicação completa abaixo.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- EXPLICAÇÃO: por que precisamos de ListaDeclaracao com o tipo "embutido"
-- ─────────────────────────────────────────────────────────────────────────────
-- O Happy não permite passar parâmetros entre regras. "int x = 5, y;"
-- precisa que tanto x quanto y saibam que o tipo é TInt — mas ItemDeclaracao
-- sozinho não tem acesso ao Tipo que vem antes.
--
-- A solução é fazer a regra de mais alto nível (Declaracao) construir
-- cada item passando o tipo explicitamente na ação semântica:
--
--   Declaracao : Tipo ListaDeclaracao ';'
--       { map (\(nome, mCmd) -> nome :#: ($1, 0)) $2  -- extrai [Var]
--       , ...                                          -- extrai [Atrib]
--       }
--
-- Mas Declaracao hoje retorna [Var]. Para também devolver os Atribs,
-- precisamos mudar o tipo de retorno para ([Var], [Comando]).
-- BlocoPrincipal já recebe ([Var], Bloco) — basta ajustar como ele
-- constrói o Bloco.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- REGRAS COMPLETAS — cole no lugar de Declaracao, Declaracoes e ListaId
-- ─────────────────────────────────────────────────────────────────────────────
--
-- ONDE COLAR: substitua as três regras (Declaracao, Declaracoes, ListaId)
-- pelas quatro abaixo. Estão na seção ==== NIVEL 5 ==== do Parser.y.

{-

-- Um item de declaração: "id" ou "id = expr" ou "id = string"
-- Retorna (String, Maybe Comando) — o nome e a inicialização opcional
ItemDeclaracao : id '=' ExpressaoAritmetica { ($1, Just (Atrib $1 $3))   }
               | id '=' string_lit          { ($1, Just (Atrib $1 (Lit $3))) }
               | id                         { ($1, Nothing)               }

-- Lista de itens separados por vírgula
-- Retorna [(String, Maybe Comando)]
ListaDeclaracao : ListaDeclaracao ',' ItemDeclaracao { $1 ++ [$3] }
                | ItemDeclaracao                     { [$1] }

-- Uma declaração completa: Tipo seguido de lista de itens e ponto e vírgula
-- Retorna ([Var], [Comando]) em vez de só [Var]
-- Os Var sempre entram em declarations; os Atrib só quando há inicialização
Declaracao : Tipo ListaDeclaracao ';'
    { ( map (\(nome, _)    -> nome :#: ($1, 0)) $2
      , [ cmd | (_, Just cmd) <- $2 ]
      ) }

-- Acumula declarações — agora acumula ([Var], [Comando])
-- Usa ++ para concatenar ambas as partes dos pares
Declaracoes : Declaracoes Declaracao { (fst $1 ++ fst $2, snd $1 ++ snd $2) }
            | Declaracao             { $1 }

-}

-- ─────────────────────────────────────────────────────────────────────────────
-- AJUSTE EM BlocoPrincipal
-- ─────────────────────────────────────────────────────────────────────────────
-- Declaracoes agora retorna ([Var], [Comando]) em vez de [Var].
-- BlocoPrincipal precisa colocar os Atribs gerados no início do Bloco.
--
-- ONDE COLAR: substitua as regras BlocoPrincipal atuais por estas.
--
-- ANTES:
--   BlocoPrincipal : '{' Declaracoes ListaCmd '}' { ($2, $3) }
--                  | '{' ListaCmd '}'             { ([], $2) }
--
-- DEPOIS:

{-

BlocoPrincipal : '{' Declaracoes ListaCmd '}' { (fst $2, snd $2 ++ $3) }
               | '{' ListaCmd '}'             { ([], $2) }

-}

-- Explicação:
--   fst $2  → [Var]      as variáveis declaradas (igual a antes)
--   snd $2  → [Comando]  os Atribs das inicializações
--   $3      → [Comando]  os comandos normais do bloco
--   snd $2 ++ $3  → os Atribs de inicialização vêm ANTES dos outros comandos


-- =============================================================================
-- [5] Semantico.hs  —  SEM ALTERAÇÕES
-- =============================================================================
-- Nenhuma mudança necessária.
-- verificaComando já trata Atrib corretamente, inclusive com coerção de tipos.
-- Então "double d = 5;" vai gerar um Atrib "d" (IntDouble (Const (CInt 5)))
-- automaticamente pela análise semântica existente.


-- =============================================================================
-- [6] Gerador.hs  —  SEM ALTERAÇÕES
-- =============================================================================
-- Nenhuma mudança necessária.
-- genCmd já trata Atrib corretamente com istore/dstore/astore.
-- Os Atribs gerados pela inicialização entram no Bloco normal e são
-- processados junto com os outros comandos.


-- =============================================================================
-- EXEMPLO DE USO (arquivo .j--)
-- =============================================================================
-- int fat(int n)
-- {
--     int f = 1;          ← inicialização na declaração
--     while (n > 0)
--     {
--         f = f * n;
--         n = n - 1;
--     }
--     return f;
-- }
--
-- {
--     int x = 10, y = 20, z;   ← mix: x e y inicializados, z não
--     double d = 3.14;
--     string s = "ola";
--
--     z = x + y;
--     print(z);
--     print(d);
--     print(s);
--     return;
-- }
--
-- O que o parser gera para "int x = 10, y = 20, z;":
--   Vars:    ["x" :#: (TInt,0), "y" :#: (TInt,0), "z" :#: (TInt,0)]
--   Cmds:    [Atrib "x" (Const (CInt 10)), Atrib "y" (Const (CInt 20))]
--
-- Esses Atribs entram no início do Bloco, antes dos outros comandos —
-- exatamente como se o programador tivesse escrito:
--   int x, y, z;
--   x = 10;
--   y = 20;

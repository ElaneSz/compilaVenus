# Implementação do `for`

Gramática implementada (exatamente como pedido):

```
for ( atribuicao1 ; expressao_logica ; atribuicao2 ) { bloco }
```

- `atribuicao1` e `atribuicao2`: só `id = ExpressaoAritmetica` (ou string), em variável **já declarada** — não aceita declaração dentro do `for`.
- `atribuicao2` não precisa ter relação nenhuma com a variável de `atribuicao1`.
- Semântica de execução: igual ao `for` de C (init roda 1x, testa condição, roda bloco, roda update, volta a testar condição...).

Design escolhido: as duas atribuições do cabeçalho do `for` são guardadas como `Comando` (reaproveitando o construtor `Atrib` que já existe). Isso é o que permite reaproveitar 100% do `verificaComando` do caso `Atrib` já implementado (que checa se a variável foi declarada, faz coerção de tipos, etc.) sem duplicar nenhuma lógica semântica.

Abaixo, uma seção por arquivo. Em cada uma tem a **âncora** (trecho exato do seu arquivo original) e o que colar antes/depois/no lugar dela.

---

## 1. `Token.hs`

**Âncora** (linha já existente):
```haskell
  | TKif | TKelse | TKwhile | TKprint | TKreturn
```

**Trocar por:**
```haskell
  | TKif | TKelse | TKwhile | TKfor | TKprint | TKreturn
```

(Só adiciona `TKfor` no meio da lista de palavras reservadas.)

---

## 2. `Lex.x`

**Âncora** (linha já existente):
```
"while"   { \s -> TKwhile }
```

**Colar logo abaixo:**
```
"for"     { \s -> TKfor }
```

Fica assim:
```
"while"   { \s -> TKwhile }
"for"     { \s -> TKfor }
"print"   { \s -> TKprint }
```

---

## 3. `AST.hs`

**Âncora** (linha já existente):
```haskell
data Comando = If ExprL Bloco Bloco
                | While ExprL Bloco
```

**Colar logo abaixo do `While`:**
```haskell
                | Para Comando ExprL Comando Bloco
```

Fica assim:
```haskell
data Comando = If ExprL Bloco Bloco
                | While ExprL Bloco
                | Para Comando ExprL Comando Bloco
                | Atrib Id Expr
                | Leitura Id
                | Imp Expr
                | Ret (Maybe Expr)
                | Proc Id [Expr] deriving Show
```

`Para ini cond upd bloco`: `ini` e `upd` são sempre um `Atrib` (o parser garante isso, veja seção 4), `cond` é a `ExprL` do meio, `bloco` é o corpo.

---

## 4. `Parser.y`

### 4.1 Declaração do token

**Âncora:**
```
    while      { TKwhile }
```

**Colar logo abaixo:**
```
    for        { TKfor }
```

### 4.2 Novo comando na lista de `Comando`

**Âncora:**
```
Comando : CmdSe       { $1 }
        | CmdEnquanto { $1 }
```

**Trocar por:**
```
Comando : CmdSe       { $1 }
        | CmdEnquanto { $1 }
        | CmdPara     { $1 }
```

### 4.3 Regras novas (`CmdPara` e `AtribSemPV`)

**Âncora:**
```
CmdEnquanto : while '(' ExpressaoLogica ')' Bloco { While $3 $5 }

-- ==== NIVEL 4 ====
```

**Colar entre as duas linhas acima** (ou seja, logo depois do `CmdEnquanto`, antes do comentário `-- ==== NIVEL 4 ====`):
```
CmdPara : for '(' AtribSemPV ';' ExpressaoLogica ';' AtribSemPV ')' Bloco { Para $3 $5 $7 $9 }

-- Atribuição sem ';' no final -- usada só dentro do cabeçalho do for,
-- onde o ';' já aparece como separador entre as 3 partes do for.
AtribSemPV : id '=' ExpressaoAritmetica { Atrib $1 $3 }
           | id '=' string_lit          { Atrib $1 (Lit $3) }
```

Fica assim, no fim:
```
CmdEnquanto : while '(' ExpressaoLogica ')' Bloco { While $3 $5 }

CmdPara : for '(' AtribSemPV ';' ExpressaoLogica ';' AtribSemPV ')' Bloco { Para $3 $5 $7 $9 }

AtribSemPV : id '=' ExpressaoAritmetica { Atrib $1 $3 }
           | id '=' string_lit          { Atrib $1 (Lit $3) }

-- ==== NIVEL 4 ====
```

> Não tem conflito de gramática com `CmdAtrib` (que já existe e consome o `;`): `AtribSemPV` só é alcançável logo depois de `for '('`, contexto em que `CmdAtrib` nunca é esperado, então o parser LALR não tem ambiguidade nenhuma pra resolver aqui.

---

## 5. `Semantico.hs`

**Âncora:**
```haskell
verificaComando tg tl tr (While exprL b) = do
                                            exprL' <- verificaExprL tg tl exprL
                                            b'    <- mapM (verificaComando tg tl tr) b
                                            return (While exprL' b')
```

**Colar logo abaixo:**
```haskell
verificaComando tg tl tr (Para ini exprL upd b) = do
                                                  -- reaproveita o caso (Atrib nome e) do próprio verificaComando:
                                                  -- isso já garante que a variável exista previamente (senão dá erro
                                                  -- "Variavel nao declarada"), e já faz a coerção de tipo certa.
                                                  -- É exatamente essa checagem que impede declarar variável no for.
                                                  ini' <- verificaComando tg tl tr ini
                                                  exprL' <- verificaExprL tg tl exprL
                                                  upd' <- verificaComando tg tl tr upd
                                                  b'   <- mapM (verificaComando tg tl tr) b
                                                  return (Para ini' exprL' upd' b')
```

> Não precisa mexer em `comandoRetorna`/`blocoRetorna`: como não existe um caso explícito pra `Para` lá, ele cai no `comandoRetorna _ = False`, que é o comportamento certo (um `for` não garante retorno, igual o `while`).

---

## 6. `Gerador.hs`

**Âncora:**
```haskell
genCmd c tg tl ti (While exprL bloco) = do
                                     li <- novoLabel
                                     lv <- novoLabel
                                     lf <- novoLabel
                                     e'  <- genExprL c tg tl ti lv lf exprL
                                     b'  <- genBloco c tg tl ti bloco
                                     return (li ++ ":\n" ++ e' ++ lv ++ ":\n" ++ b' ++ "\tgoto " ++ li ++ "\n" ++ lf ++ ":\n")
```

**Colar logo abaixo:**
```haskell
genCmd c tg tl ti (Para ini exprL upd bloco) = do
                                     ini' <- genCmd c tg tl ti ini    -- código da atribuição inicial (roda 1x, antes do loop)
                                     li <- novoLabel                 -- topo do loop (onde a condição é reavaliada)
                                     lv <- novoLabel                 -- corpo do loop
                                     lf <- novoLabel                 -- saída do loop
                                     e'   <- genExprL c tg tl ti lv lf exprL
                                     b'   <- genBloco c tg tl ti bloco
                                     upd' <- genCmd c tg tl ti upd   -- código do incremento/atualização, roda no FIM de cada iteração
                                     return (ini' ++ li ++ ":\n" ++ e' ++ lv ++ ":\n" ++ b' ++ upd' ++ "\tgoto " ++ li ++ "\n" ++ lf ++ ":\n")
```

O bytecode gerado segue exatamente a mesma estrutura do `while`, só que com a inicialização antes do loop e o update colado no fim do corpo, antes do `goto` de volta pro topo — que é a semântica padrão de um `for` estilo C.

---

## Exemplo de teste (depois de aplicar tudo)

```c
{
  int i;
  int soma;

  soma = 0;
  for (i = 0; i <= 10; i = i + 1) {
      soma = soma + i;
      print(soma);
  }

  print(soma);
  return;
}
```

Esse teste cobre: atribuição inicial simples, condição relacional simples (sem `&&`/`||`/`!`, pra isolar o `for` dos bugs que já mexemos), update independente da lógica interna do bloco, e um `print` dentro do loop pra você acompanhar iteração por iteração.

Se quiser, dá pra testar também um caso onde a segunda atribuição do `for` mexe numa variável diferente da primeira (ex: `for (i = 0; i < 10; flag = 1)`), só pra confirmar que o "não precisa ter relação com a variável original" está funcionando.

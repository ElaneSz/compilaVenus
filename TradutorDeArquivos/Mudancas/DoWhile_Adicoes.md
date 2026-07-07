# Implementação do `do-while` (faça-enquanto)

Sintaxe que passa a ser aceita:

```
do {
    x = x + 1;
} while (x < 10);
```

Diferença pro `while` que já existe: o corpo do `do-while` **sempre roda pelo menos uma
vez**, e só depois disso a condição é testada (se verdadeira, repete; se falsa, sai).

Cada seção abaixo mostra em qual arquivo mexer, uma citação do trecho já existente
(pra você achar o lugar certo) e o que colar. Só precisei criar **uma função nova de
verdade** (o `genCmd` do `DoWhile` no Gerador — inevitável, é o código novo em si);
todo o resto reaproveita funções que já existiam (`genExprL`, `genBloco`,
`verificaExprL`, `blocoRetorna`, etc.), do mesmo jeito que `While`/`If` já faziam.

---

## 1. `Token.hs`

Ache a linha das palavras reservadas:

```haskell
  | TKif | TKelse | TKwhile | TKprint | TKreturn
```

Troque por (só acrescentei `TKdo`):

```haskell
  | TKif | TKelse | TKwhile | TKprint | TKreturn
  | TKdo
```

---

## 2. `Lex.x`

Ache a linha:

```
"while"   { \s -> TKwhile }
```

E logo abaixo dela, acrescente:

```
"do"      { \s -> TKdo }
```

(Tem que ficar antes da regra genérica de identificador `$alpha $alnum* { \s -> TKid s }`,
igual as outras palavras reservadas — e já vai ficar, já que você só está acrescentando
uma linha no meio do bloco de palavras reservadas que já existe.)

---

## 3. `AST.hs`

Ache o final da definição de `Comando`:

```haskell
data Comando = If ExprL Bloco Bloco
                | While ExprL Bloco
                | Atrib Id Expr
                | Leitura Id
                | Imp Expr
                | Ret (Maybe Expr)
                | Proc Id [Expr] deriving Show
```

Troque a última linha (`| Proc Id [Expr] deriving Show`) por estas duas:

```haskell
                | Proc Id [Expr]
                | DoWhile Bloco ExprL deriving Show
```

`DoWhile` guarda o bloco do corpo primeiro e a condição depois — na mesma ordem que
aparece no código-fonte (`do { corpo } while (condicao);`).

---

## 4. `Parser.y`

**4.1 — Declarar o token novo.** Ache:

```
    while      { TKwhile }
```

E acrescente logo abaixo:

```
    do         { TKdo }
```

**4.2 — Adicionar como alternativa de `Comando`.** Ache:

```
Comando : CmdSe       { $1 }
        | CmdEnquanto { $1 }
        | CmdAtrib    { $1 }
        | CmdEscrita  { $1 }
        | Retorno     { $1 }
        | CmdLeitura  { $1 }
        | ChamadaProc { $1 }
```

Acrescente mais uma linha:

```
        | CmdFacaEnquanto { $1 }
```

**4.3 — Criar a regra da gramática.** Ache:

```
CmdEnquanto : while '(' ExpressaoLogica ')' Bloco { While $3 $5 }
```

E logo abaixo dela, acrescente:

```
CmdFacaEnquanto : do Bloco while '(' ExpressaoLogica ')' ';' { DoWhile $2 $5 }
```

Não precisa mexer em mais nada no Parser: `Bloco` e `ExpressaoLogica` já existem e
já sabem lidar com qualquer coisa (inclusive um `do-while` aninhado dentro de outro,
já que `Comando` — e portanto `Bloco` — agora inclui `CmdFacaEnquanto`).

---

## 5. `Semantico.hs`

**5.1 — Verificar o comando.** Ache o bloco do `While`:

```haskell
verificaComando tg tl tr (While exprL b) = do
                                            exprL' <- verificaExprL tg tl exprL
                                            b'    <- mapM (verificaComando tg tl tr) b
                                            return (While exprL' b')
```

E logo abaixo, acrescente (é basicamente a mesma coisa do `While`, só que devolvendo
`DoWhile` e mantendo a ordem bloco-depois-condição da AST):

```haskell
verificaComando tg tl tr (DoWhile b exprL) =   do
                                                b'     <- mapM (verificaComando tg tl tr) b
                                                exprL' <- verificaExprL tg tl exprL
                                                return (DoWhile b' exprL')
```

**5.2 — Encaixar no `comandoRetorna`.** Ache:

```haskell
comandoRetorna :: Comando -> Bool
comandoRetorna (Ret _)      = True
comandoRetorna (If _ b1 b2) = blocoRetorna b1 && blocoRetorna b2
comandoRetorna _            = False
```

Acrescente uma linha ANTES do `comandoRetorna _ = False` (essa linha precisa continuar
sendo a última, já que é o caso "pega-tudo"):

```haskell
comandoRetorna :: Comando -> Bool
comandoRetorna (Ret _)       = True
comandoRetorna (If _ b1 b2)  = blocoRetorna b1 && blocoRetorna b2
comandoRetorna (DoWhile b _) = blocoRetorna b
comandoRetorna _             = False
```

Detalhe interessante aqui: no `While` normal isso não daria pra fazer (por isso ele
cai no caso `_ -> False`), porque o corpo de um `while` pode nunca executar nenhuma
vez — então mesmo que o corpo sempre retorne, o `while` inteiro não garante retorno.
Já no `do-while`, o corpo **sempre** executa pelo menos uma vez, então se o bloco do
corpo (`b`) garante retorno, o `do-while` inteiro também garante. É por isso que dá
pra escrever `comandoRetorna (DoWhile b _) = blocoRetorna b` em vez de só `False`.

---

## 6. `Gerador.hs`

Ache o `genCmd` do `While`:

```haskell
genCmd c tg tl ti (While exprL bloco) = do
                                     li <- novoLabel
                                     lv <- novoLabel
                                     lf <- novoLabel
                                     e'  <- genExprL c tg tl ti lv lf exprL
                                     b'  <- genBloco c tg tl ti bloco
                                     return (li ++ ":\n" ++ e' ++ lv ++ ":\n" ++ b' ++ "\tgoto " ++ li ++ "\n" ++ lf ++ ":\n")
```

E logo abaixo, acrescente:

```haskell
-- do-while: roda o bloco pelo menos uma vez, e só depois testa a condição.
-- Reaproveita genBloco e genExprL exatamente como já são (nenhum dos dois precisou mudar):
-- a diferença toda tá em COMO eu chamo genExprL. No While, o teste vem antes do corpo,
-- então precisa de um label separado pra "entrada do corpo" (lv) além do label de
-- reteste (li). Aqui no do-while o corpo sempre roda primeiro, então o próprio label
-- de início do corpo (li) já serve como o label de "repetir" — passo ele como o
-- "label de verdadeiro" pro genExprL, e lf como o "label de falso" (saída do laço).
genCmd c tg tl ti (DoWhile bloco exprL) = do
                                       li <- novoLabel
                                       lf <- novoLabel
                                       b' <- genBloco c tg tl ti bloco
                                       e' <- genExprL c tg tl ti li lf exprL
                                       return (li ++ ":\n" ++ b' ++ e' ++ lf ++ ":\n")
```

O código Jasmin gerado fica no formato:

```
l0:
    <corpo>
    <checagem da condição: verdadeiro -> goto l0, falso -> goto l1>
l1:
```

Ou seja, um label a menos que o `While` (2 em vez de 3), porque não precisa de um
label separado só pra marcar "onde o corpo começa" — o `li` já cumpre esse papel.

---

## Testando rapidinho

Depois de colar tudo, um `.j--` desse tipo já deve funcionar:

```
int contador;
contador = 0;
do {
    print(contador);
    contador = contador + 1;
} while (contador < 5);
```

E, se quiser testar o `comandoRetorna` novo, uma função assim deve passar na semântica
sem erro (porque o `do-while` sempre executa o corpo, e o corpo sempre retorna):

```
int teste() {
    int x;
    x = 1;
    do {
        return x;
    } while (x < 0);
}
```

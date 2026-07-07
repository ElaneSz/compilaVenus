# Implementação do `float`

Sintaxe que passa a ser aceita:

```
float media(float a, float b) {
    return (a + b) / 2.0;
}
```

`float` no JVM é diferente de `double`: ocupa **1 posição** na pilha/variáveis locais
(igual `int`), não 2 — e usa um conjunto próprio de instruções (`fload`, `fstore`,
`fadd`, `fcmpg`, `freturn`, etc.) em vez de reaproveitar as de `int` ou `double`.

Uma decisão de design importante: **não criei um literal próprio pra float** (tipo
`3.14f`). Literais decimais (`3.14`) continuam sendo sempre `TDouble` — igual já
acontecia antes — e viram `float` através da mesma coerção implícita que já existe
pra `int`↔`double` (só que agora com mais uma camada: `int` ↔ `float` ↔ `double`). Isso
evita mexer no lexer/parser pra literais, e reaproveita 100% do mecanismo de coerção
que já existia (`IntDouble`/`DoubleInt`), só estendendo ele com 4 conversões novas
(`IntFloat`, `FloatInt`, `DoubleFloat`, `FloatDouble`).

A hierarquia de conversão implícita (mesma lógica que já existia pra `int`/`double`,
só que agora com 3 níveis):

```
TInt  --(silencioso)-->  TFloat  --(silencioso)-->  TDouble
TInt  <--(advertência)--  TFloat  <--(advertência)--  TDouble
```
Ou seja: subir de precisão é sempre silencioso, descer sempre dá advertência (nunca
erro) — exatamente a mesma política que já existia entre `int` e `double`, só
estendida com o degrau do meio.

---

## 1. `Token.hs`

Ache:

```haskell
  = TKint | TKdouble | TKstring | TKvoid
```

Troque por (só acrescentei `TKfloat`):

```haskell
  = TKint | TKdouble | TKfloat | TKstring | TKvoid
```

---

## 2. `Lex.x`

Ache:

```
"double"  { \s -> TKdouble }
```

E logo abaixo, acrescente:

```
"float"   { \s -> TKfloat }
```

---

## 3. `AST.hs`

**3.1 — Novo tipo.** Ache:

```haskell
data Tipo = TDouble | TInt | TString | TVoid deriving (Show, Eq)
```

Troque por:

```haskell
data Tipo = TDouble | TInt | TFloat | TString | TVoid deriving (Show, Eq)
```

**3.2 — Novos nós de conversão.** Ache o final de `Expr`:

```haskell
            | IntDouble Expr | DoubleInt Expr deriving Show
```

Troque por (4 construtores novos, um pra cada direção de conversão):

```haskell
            | IntDouble Expr | DoubleInt Expr
            | IntFloat Expr | FloatInt Expr | DoubleFloat Expr | FloatDouble Expr deriving Show
```

A convenção de nome é a mesma que já existia: `OrigemDestino` — `IntFloat e` lê-se
"`e` era Int, virou Float"; `FloatDouble e` lê-se "`e` era Float, virou Double".

---

## 4. `Parser.y`

**4.1 — Token.** Ache:

```
    double     { TKdouble }
```

Acrescente logo abaixo:

```
    float      { TKfloat }
```

**4.2 — Regra de tipo.** Ache:

```
Tipo : int    { TInt }
     | double { TDouble }
     | string { TString }
```

Troque por:

```
Tipo : int    { TInt }
     | double { TDouble }
     | float  { TFloat }
     | string { TString }
```

Não precisa de mais nada no Parser — literais continuam vindo por `double_lit`
(igual expliquei lá em cima), e toda a gramática de expressões/comandos já
funciona pra qualquer `Tipo`, incluindo o novo.

---

## 5. `Semantico.hs`

Essa é a parte com mais mudanças, mas todas seguem o **mesmo padrão que já existia**
pra `int`/`double` — só que agora com mais combinações de par de tipos. São 9 lugares.

**5.1 — `Add`, `Sub`, `Mul`, `Div` (4 funções, mesmo padrão nas 4).** Em cada uma, ache
o caso `(TDouble, TDouble)` e a linha do erro logo depois, tipo (usando `Add` de exemplo):

```haskell
                                        (TDouble, TDouble)  -> return (Add e1' e2', TDouble)
                                        _                   ->  do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
                                                                errorMsg (" Tipos incompativeis em adicao: " ++ show e1' ++ " + " ++ show e2')
```

E acrescente as 5 linhas de `float` ANTES do `_ ->` (repita pra `Sub`, `Mul`, `Div`,
trocando `Add`/"adicao" pelo nome de cada uma):

```haskell
                                        (TDouble, TDouble)  -> return (Add e1' e2', TDouble)
                                        (TFloat, TFloat)    -> return (Add e1' e2', TFloat)
                                        (TInt, TFloat)      -> return (Add (IntFloat e1') e2', TFloat)
                                        (TFloat, TInt)      -> return (Add e1' (IntFloat e2'), TFloat)
                                        (TFloat, TDouble)   -> return (Add (FloatDouble e1') e2', TDouble)
                                        (TDouble, TFloat)   -> return (Add e1' (FloatDouble e2'), TDouble)
                                        _                   ->  do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
                                                                errorMsg (" Tipos incompativeis em adicao: " ++ show e1' ++ " + " ++ show e2')
```

Repare que misturar `float` com `double` sempre promove pro `double` (o tipo maior),
igual `int`+`double` já promovia pra `double` — sem advertência, porque nenhuma
informação é perdida ao subir de precisão numa conta.

**5.2 — `Neg`.** Ache:

```haskell
                                    TInt    -> return (Neg e', TInt)
                                    TDouble -> return (Neg e', TDouble)
                                    _       -> do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
```

Acrescente uma linha:

```haskell
                                    TInt    -> return (Neg e', TInt)
                                    TDouble -> return (Neg e', TDouble)
                                    TFloat  -> return (Neg e', TFloat)
                                    _       -> do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
```

**5.3 — `coerceArg` (parâmetros de função).** Ache:

```haskell
                                    (TInt, TDouble)    -> do                   -- converte com advertência
                                        warningMsg (" Conversao de double para int em parametro: " ++ show e)
                                        return (DoubleInt e)
                                    _ -> do
                                        errorMsg " Tipo de parametro incompativel"
                                        return e
```

Troque por:

```haskell
                                    (TInt, TDouble)    -> do                   -- converte com advertência
                                        warningMsg (" Conversao de double para int em parametro: " ++ show e)
                                        return (DoubleInt e)
                                    (TFloat, TFloat)   -> return e
                                    (TFloat, TInt)     -> return (IntFloat e)  -- converte silenciosamente
                                    (TInt, TFloat)     -> do                   -- converte com advertência
                                        warningMsg (" Conversao de float para int em parametro: " ++ show e)
                                        return (FloatInt e)
                                    (TDouble, TFloat)  -> return (FloatDouble e) -- converte silenciosamente
                                    (TFloat, TDouble)  -> do                   -- converte com advertência
                                        warningMsg (" Conversao de double para float em parametro: " ++ show e)
                                        return (DoubleFloat e)
                                    _ -> do
                                        errorMsg " Tipo de parametro incompativel"
                                        return e
```

**5.4 — As 6 comparações (`Rlt`, `Rgt`, `Rle`, `Rge`, `Req`, `Rdif`).** Mesmo padrão nas
6 (uso `Rlt`/`<` de exemplo — repita trocando o construtor e o símbolo do texto do erro
pelos das outras 5: `Rgt`/`>`, `Rle`/`<=`, `Rge`/`>=`, `Req`/`==`, `Rdif`/`/=`). Ache:

```haskell
                                        (TDouble, TDouble) -> return (Rlt e1' e2')
                                        (TString, TString) -> return (Rlt e1' e2')
                                        _ -> do
                                            errorMsg (" Tipos incompativeis em expressao relacional: " ++ show e1' ++ " < " ++ show e2')
```

Troque por:

```haskell
                                        (TDouble, TDouble) -> return (Rlt e1' e2')
                                        (TFloat, TFloat)   -> return (Rlt e1' e2')
                                        (TInt, TFloat)     -> return (Rlt (IntFloat e1') e2')
                                        (TFloat, TInt)     -> return (Rlt e1' (IntFloat e2'))
                                        (TFloat, TDouble)  -> return (Rlt (FloatDouble e1') e2')
                                        (TDouble, TFloat)  -> return (Rlt e1' (FloatDouble e2'))
                                        (TString, TString) -> return (Rlt e1' e2')
                                        _ -> do
                                            errorMsg (" Tipos incompativeis em expressao relacional: " ++ show e1' ++ " < " ++ show e2')
```

**5.5 — `Atrib` (atribuição de variável).** Ache:

```haskell
                                                        (TInt, TDouble)    ->   do
                                                                                warningMsg (" Conversao de double para int na atribuicao de " ++ nome ++ " = " ++ show e')
                                                                                return (Atrib nome (DoubleInt e'))
                                                        _ ->    do
                                                                errorMsg (" Tipos incompativeis na atribuicao de " ++ nome)
                                                                return (Atrib nome e')
```

Troque por:

```haskell
                                                        (TInt, TDouble)    ->   do
                                                                                warningMsg (" Conversao de double para int na atribuicao de " ++ nome ++ " = " ++ show e')
                                                                                return (Atrib nome (DoubleInt e'))
                                                        (TFloat, TFloat)   -> return (Atrib nome e')
                                                        (TFloat, TInt)     -> return (Atrib nome (IntFloat e'))
                                                        (TInt, TFloat)     ->   do
                                                                                warningMsg (" Conversao de float para int na atribuicao de " ++ nome ++ " = " ++ show e')
                                                                                return (Atrib nome (FloatInt e'))
                                                        (TDouble, TFloat)  -> return (Atrib nome (FloatDouble e'))
                                                        (TFloat, TDouble)  ->   do
                                                                                warningMsg (" Conversao de double para float na atribuicao de " ++ nome ++ " = " ++ show e')
                                                                                return (Atrib nome (DoubleFloat e'))
                                                        _ ->    do
                                                                errorMsg (" Tipos incompativeis na atribuicao de " ++ nome)
                                                                return (Atrib nome e')
```

**5.6 — `Ret (Just e)` (retorno de função).** Ache:

```haskell
                                                (TInt, TDouble)    ->   do
                                                                        warningMsg (" Conversao de double para int no retorno: " ++ show e')
                                                                        return (Ret (Just (DoubleInt e')))
                                                _ ->    do
                                                        errorMsg (" Tipos incompativeis no retorno")
                                                        return (Ret (Just e'))
```

Troque por:

```haskell
                                                (TInt, TDouble)    ->   do
                                                                        warningMsg (" Conversao de double para int no retorno: " ++ show e')
                                                                        return (Ret (Just (DoubleInt e')))
                                                (TFloat, TFloat)   -> return (Ret (Just e'))
                                                (TFloat, TInt)     -> return (Ret (Just (IntFloat e')))
                                                (TInt, TFloat)     ->   do
                                                                        warningMsg (" Conversao de float para int no retorno: " ++ show e')
                                                                        return (Ret (Just (FloatInt e')))
                                                (TDouble, TFloat)  -> return (Ret (Just (FloatDouble e')))
                                                (TFloat, TDouble)  ->   do
                                                                        warningMsg (" Conversao de double para float no retorno: " ++ show e')
                                                                        return (Ret (Just (DoubleFloat e')))
                                                _ ->    do
                                                        errorMsg (" Tipos incompativeis no retorno")
                                                        return (Ret (Just e'))
```

**Nada muda** em `comandoRetorna`/`blocoRetorna` (não olham `Tipo`, só a forma dos
comandos) nem em `Ret Nothing` (só compara com `TVoid`, qualquer outro tipo — incluindo
`TFloat` agora — já cai certo no caso de erro que já existia).

---

## 6. `Gerador.hs`

**6.1 — Descritor JVM.** Ache:

```haskell
tipoJVM TDouble = "D"
```

Acrescente logo abaixo:

```haskell
tipoJVM TFloat  = "F"
```

**6.2 — Operações aritméticas (`fadd`/`fsub`/`fmul`/`fdiv`/`fneg`).** Ache:

```haskell
genOp TDouble op = "\td" ++ op ++ "\n"
```

Acrescente logo abaixo:

```haskell
genOp TFloat  op = "\tf" ++ op ++ "\n"
```

Isso sozinho já cobre `Add`/`Sub`/`Mul`/`Div`/`Neg` no `genExpr` — todas essas funções
já chamam `genOp` genericamente (`genOp t1 "add"` etc.), sem olhar o tipo diretamente,
então não precisam de nenhuma mudança.

**6.3 — Comparações (`fcmpg`/`fcmpl`).** Ache o `genRel` do `TDouble`:

```haskell
genRel TDouble op lv = case op of
                         "lt" -> "\tdcmpg\n\tiflt " ++ lv ++ "\n" -- <  (se dcmpg < 0)
                         "gt" -> "\tdcmpl\n\tifgt " ++ lv ++ "\n" -- >  (se dcmpl > 0)
                         "le" -> "\tdcmpg\n\tifle " ++ lv ++ "\n" -- <= (se dcmpg <= 0)
                         "ge" -> "\tdcmpl\n\tifge " ++ lv ++ "\n" -- >= (se dcmpl >= 0)
                         "eq" -> "\tdcmpg\n\tifeq " ++ lv ++ "\n" -- == (se dcmpg == 0)
                         "ne" -> "\tdcmpg\n\tifne " ++ lv ++ "\n" -- /= (se dcmpg /= 0)
                         _    -> "\tif_icmp" ++ op ++ " " ++ lv ++ "\n"
genRel _       op lv = "\tif_icmp" ++ op ++ " " ++ lv ++ "\n"
```

E acrescente o caso do `TFloat` ANTES do `genRel _` (que precisa continuar sendo o
último, é o caso coringa):

```haskell
genRel TDouble op lv = case op of
                         "lt" -> "\tdcmpg\n\tiflt " ++ lv ++ "\n" -- <  (se dcmpg < 0)
                         "gt" -> "\tdcmpl\n\tifgt " ++ lv ++ "\n" -- >  (se dcmpl > 0)
                         "le" -> "\tdcmpg\n\tifle " ++ lv ++ "\n" -- <= (se dcmpg <= 0)
                         "ge" -> "\tdcmpl\n\tifge " ++ lv ++ "\n" -- >= (se dcmpl >= 0)
                         "eq" -> "\tdcmpg\n\tifeq " ++ lv ++ "\n" -- == (se dcmpg == 0)
                         "ne" -> "\tdcmpg\n\tifne " ++ lv ++ "\n" -- /= (se dcmpg /= 0)
                         _    -> "\tif_icmp" ++ op ++ " " ++ lv ++ "\n"
genRel TFloat  op lv = case op of
                         "lt" -> "\tfcmpg\n\tiflt " ++ lv ++ "\n" -- <  (se fcmpg < 0)
                         "gt" -> "\tfcmpl\n\tifgt " ++ lv ++ "\n" -- >  (se fcmpl > 0)
                         "le" -> "\tfcmpg\n\tifle " ++ lv ++ "\n" -- <= (se fcmpg <= 0)
                         "ge" -> "\tfcmpl\n\tifge " ++ lv ++ "\n" -- >= (se fcmpl >= 0)
                         "eq" -> "\tfcmpg\n\tifeq " ++ lv ++ "\n" -- == (se fcmpg == 0)
                         "ne" -> "\tfcmpg\n\tifne " ++ lv ++ "\n" -- /= (se fcmpg /= 0)
                         _    -> "\tif_icmp" ++ op ++ " " ++ lv ++ "\n"
genRel _       op lv = "\tif_icmp" ++ op ++ " " ++ lv ++ "\n"
```

**6.4 — Carregar variável (`fload`).** Ache:

```haskell
                                                   TInt    -> "\tiload " -- Para int
                                                   TDouble -> "\tdload " -- Para double
                                                   _       -> "\taload " -- Para string
```

Troque por:

```haskell
                                                   TInt    -> "\tiload " -- Para int
                                                   TDouble -> "\tdload " -- Para double
                                                   TFloat  -> "\tfload " -- Para float
                                                   _       -> "\taload " -- Para string
```

**6.5 — Guardar variável (`fstore`), em `Atrib`.** Ache:

```haskell
                                                TInt    -> "\tistore "
                                                TDouble -> "\tdstore "
                                                _       -> "\tastore "
```

Troque por:

```haskell
                                                TInt    -> "\tistore "
                                                TDouble -> "\tdstore "
                                                TFloat  -> "\tfstore "
                                                _       -> "\tastore "
```

**6.6 — `print` (imprimir float).** Ache:

```haskell
                                             TInt    -> "\tinvokevirtual java/io/PrintStream/print(I)V\n"
                                             TDouble -> "\tinvokevirtual java/io/PrintStream/print(D)V\n"
                                             _       -> "\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n"
```

Troque por:

```haskell
                                             TInt    -> "\tinvokevirtual java/io/PrintStream/print(I)V\n"
                                             TDouble -> "\tinvokevirtual java/io/PrintStream/print(D)V\n"
                                             TFloat  -> "\tinvokevirtual java/io/PrintStream/print(F)V\n"
                                             _       -> "\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n"
```

**6.7 — `read` (ler float com `Scanner.nextFloat`).** Ache:

```haskell
                                                                          TInt    -> ("nextInt",    "I",                 "\tistore ")
                                                                          TDouble -> ("nextDouble", "D",                 "\tdstore ")
                                                                          _       -> ("nextLine",   "Ljava/lang/String;", "\tastore ")
```

Troque por:

```haskell
                                                                          TInt    -> ("nextInt",    "I",                 "\tistore ")
                                                                          TDouble -> ("nextDouble", "D",                 "\tdstore ")
                                                                          TFloat  -> ("nextFloat",  "F",                 "\tfstore ")
                                                                          _       -> ("nextLine",   "Ljava/lang/String;", "\tastore ")
```

**6.8 — `return` com valor (`freturn`).** Ache:

```haskell
                                                TInt    -> "\tireturn\n"
                                                TDouble -> "\tdreturn\n"
                                                _       -> "\tareturn\n"
```

Troque por:

```haskell
                                                TInt    -> "\tireturn\n"
                                                TDouble -> "\tdreturn\n"
                                                TFloat  -> "\tfreturn\n"
                                                _       -> "\tareturn\n"
```

**6.9 — As 4 conversões novas (`i2f`, `f2i`, `d2f`, `f2d`).** Ache o par `IntDouble`/`DoubleInt`:

```haskell
genExpr c tg tl ti (IntDouble e) = do
                                (_, e') <- genExpr c tg tl ti e
                                return (TDouble, e' ++ "\ti2d\n")

genExpr c tg tl ti (DoubleInt e) = do
                                (_, e') <- genExpr c tg tl ti e
                                return (TInt, e' ++ "\td2i\n")
```

E acrescente logo abaixo (4 clones do mesmo padrão, só trocando a instrução de conversão
e os tipos):

```haskell
genExpr c tg tl ti (IntFloat e) = do
                                (_, e') <- genExpr c tg tl ti e
                                return (TFloat, e' ++ "\ti2f\n")

genExpr c tg tl ti (FloatInt e) = do
                                (_, e') <- genExpr c tg tl ti e
                                return (TInt, e' ++ "\tf2i\n")

genExpr c tg tl ti (DoubleFloat e) = do
                                (_, e') <- genExpr c tg tl ti e
                                return (TFloat, e' ++ "\td2f\n")

genExpr c tg tl ti (FloatDouble e) = do
                                (_, e') <- genExpr c tg tl ti e
                                return (TDouble, e' ++ "\tf2d\n")
```

**O que NÃO precisou mudar (e por quê):**
- `tamanhoTipo` — já tinha um caso coringa (`tamanhoTipo _ = 1`) que cobre `float`
  corretamente (só `double` ocupa 2 posições; `float`, igual `int`, ocupa 1).
- `Proc` (chamada como comando) — o `pop`/`pop2` que descarta o retorno não usado já
  cai certo no caso coringa `_ -> "\tpop\n"` pra `float` (1 posição, igual `int`/`string`).
- Não criei um `genFloat` (tipo o `genInt`/`genDouble`) porque não existe nenhum literal
  de float — todo valor `float` nasce de uma variável, de uma conta, ou de uma conversão
  (`DoubleFloat`/`IntFloat`), nunca direto de uma constante no código-fonte.

---

## Testando (validação que consegui fazer sem GHC)

**Importante:** não tenho GHC, Alex, Happy nem acesso à internet neste ambiente, então
não consegui rodar `make` de verdade nem gerar/executar um `.class`. O que eu fiz pra
validar:

1. Apliquei essas mesmas mudanças (junto com o do-while da vez passada) numa cópia
   local do seu projeto e chequei que os arquivos resultantes têm parênteses/aspas
   balanceados e a indentação de cada bloco `do`/`case` consistente (a regra de layout
   do Haskell é sensível a isso).
2. Conferi, com `grep`, TODOS os pontos do `Semantico.hs`/`Gerador.hs` que fazem `case`
   sobre `Tipo`, e confirmei que cada um deles ou já tinha um caso coringa que cobre
   `float` corretamente, ou ganhou um caso novo explícito.
3. Rastreei à mão a geração de código pra este programa:

   ```
   float media(float a, float b) {
       return (a + b) / 2.0;
   }
   float x; float y;
   x = 3.5; y = 2.0;
   print(media(x, y));
   ```

   E depois **mecanizei esse mesmo rastreio num script Python** (reimplementando só a
   lógica relevante de `genExpr`/`genOp`/`tipoJVM`) pra conferir contra erro de conta
   manual. Bateu exatamente com o esperado, gerando (entre outras coisas) o corpo de
   `media` como:

   ```
   .method public static media(FF)F
       .limit stack 35
       .limit locals 2

       fload 0
       fload 1
       fadd
       f2d
       ldc2_w 2.0
       ddiv
       d2f
       freturn
   .end method
   ```

   (Repare a soma em `float` puro com `fadd`, depois promovida a `double` com `f2d` pra
   dividir por `2.0`, e o resultado convertido de volta pra `float` com `d2f` antes do
   `freturn` — exatamente a política de coerção descrita lá em cima, incluindo a
   advertência de "conversão de double para float no retorno".)

Isso me dá bastante confiança de que está certo, mas **não substitui rodar `make` de
verdade**. Recomendo testar com esse mesmo programa (ou o seu `Teste.j--`/`Teste1.j--`
adaptado com alguma variável `float`) assim que colar as mudanças, e me chamar se o
`alex`/`happy`/`ghc` acusar algum erro — nesse caso me manda a mensagem exata.

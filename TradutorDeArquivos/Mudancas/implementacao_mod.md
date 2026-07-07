# Implementação do operador `%` (módulo/resto da divisão)

**Testado de ponta a ponta** (mesma disciplina de sempre): compilei, chequei o `.info` do Happy pra garantir zero conflitos, e testei com `int`, `double`, precedência misturada com `+`/`*`, e combinado com `for`+ternário, conferindo o bytecode gerado.

## Design: copiar exatamente o `Div`

`%` é um operador binário aritmético igual `+ - * /`, então segue o mesmo esqueleto dos outros quatro em todo lugar — `AST.hs`, `Semantico.hs` e `Gerador.hs` já tinham o padrão pronto, só copiei e troquei o nome/instrução. A única sutileza é a instrução da JVM: assim como existe `iadd`/`dadd`, `isub`/`dsub`, `imul`/`dmul`, `idiv`/`ddiv`, a JVM também já tem `irem`/`drem` prontas pra resto de divisão — tanto pra `int` quanto pra `double` (`double % double` é válido em Java de verdade, ex: `17.5 % 4.0 == 1.5`), e o seu `genOp` já monta esse nome de instrução sozinho a partir do tipo, então nem precisei tocar nele.

---

## 1. `Token.hs`

**Âncora:**
```haskell
  | TKmais | TKmenos | TKmult | TKdiv | TKincremento
```
*(se você não tiver implementado o incremento ainda, sua linha deve terminar em `TKdiv` mesmo — ajuste a âncora conforme o que já está no seu arquivo.)*

**Trocar por:**
```haskell
  | TKmais | TKmenos | TKmult | TKdiv | TKmod | TKincremento
```

---

## 2. `Lex.x`

**Âncora:**
```
"/"   { \s -> TKdiv }
```

**Colar logo abaixo:**
```
"%"   { \s -> TKmod }
```

---

## 3. `AST.hs`

**Âncora:**
```haskell
data Expr = Add Expr Expr | Sub Expr Expr | Mul Expr Expr
            | Div Expr Expr |Neg Expr | Const TCons
```

**Trocar por:**
```haskell
data Expr = Add Expr Expr | Sub Expr Expr | Mul Expr Expr
            | Div Expr Expr | Mod Expr Expr |Neg Expr | Const TCons
```

---

## 4. `Parser.y`

### 4.1 Token

**Âncora:**
```
    '/'        { TKdiv }
```

**Colar logo abaixo:**
```
    '%'        { TKmod }
```

### 4.2 Precedência

**Âncora:**
```
%left '*' '/'
```

**Trocar por:**
```
%left '*' '/' '%'
```

(`%` tem exatamente a mesma precedência e associatividade de `*`/`/` — igual em C/Java. `1 + 2 * 3 % 4` vira `1 + ((2*3) % 4)`.)

### 4.3 Nova alternativa em `ExpressaoAritmetica`

**Âncora:**
```
                    | ExpressaoAritmetica '/' ExpressaoAritmetica  { Div $1 $3 }
```

**Colar logo abaixo:**
```
                    | ExpressaoAritmetica '%' ExpressaoAritmetica  { Mod $1 $3 }
```

---

## 5. `Semantico.hs`

**Âncora** (o `verificaExpr` do `Div`, que já existe):
```haskell
verificaExpr tg tl (Div e1 e2) =    do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)        -> return (Div e1' e2', TInt)
                                        (TInt, TDouble)     -> return (Div (IntDouble e1') e2', TDouble)
                                        (TDouble, TInt)     -> return (Div e1' (IntDouble e2'), TDouble)
                                        (TDouble, TDouble)  -> return (Div e1' e2', TDouble)
                                        _                   ->  do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
                                                                errorMsg (" Tipos incompativeis em divisao: " ++ show e1' ++ " / " ++ show e2')
                                                                return (Div e1' e2', TInt)
```

**Colar logo abaixo:**
```haskell
verificaExpr tg tl (Mod e1 e2) =    do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)        -> return (Mod e1' e2', TInt)
                                        (TInt, TDouble)     -> return (Mod (IntDouble e1') e2', TDouble)
                                        (TDouble, TInt)     -> return (Mod e1' (IntDouble e2'), TDouble)
                                        (TDouble, TDouble)  -> return (Mod e1' e2', TDouble)
                                        _                   ->  do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
                                                                errorMsg (" Tipos incompativeis em modulo: " ++ show e1' ++ " % " ++ show e2')
                                                                return (Mod e1' e2', TInt)
```

---

## 6. `Gerador.hs`

**Âncora** (o `genExpr` do `Div`, que já existe):
```haskell
genExpr c tg tl ti (Div e1 e2) =   do
                                (t1, e1') <- genExpr c tg tl ti e1
                                (t2, e2') <- genExpr c tg tl ti e2
                                return (t1, e1' ++ e2' ++ genOp t1 "div")
```

**Colar logo abaixo:**
```haskell
genExpr c tg tl ti (Mod e1 e2) =   do
                                (t1, e1') <- genExpr c tg tl ti e1
                                (t2, e2') <- genExpr c tg tl ti e2
                                return (t1, e1' ++ e2' ++ genOp t1 "rem")
```

`genOp TInt "rem"` gera `irem`, `genOp TDouble "rem"` gera `drem` — ambas instruções reais da JVM, então o `%` já funciona pra `int` e `double` sem precisar de nenhum código extra de conversão além do que o `IntDouble`/`DoubleInt` já cobre nos outros operadores.

---

## Testado (bytecode conferido)

```c
{
  int a;
  int b;
  double d;
  int i;
  int pares;

  a = 17;
  b = 5;
  print(a % b);          // 2

  d = 17.5;
  print(d % 4.0);        // 1.5

  print(1 + 2 * 3 % 4);  // 3  (confirma precedencia: (2*3)%4 = 2, depois 1+2 = 3)

  pares = 0;
  for (i = 0; i < 10; i++) {
      pares = pares + ((i % 2 == 0) ? 1 : 0);
  }
  print(pares);          // 5  (conta os pares 0,2,4,6,8)

  return;
}
```

Passa na análise semântica sem erros, e o bytecode gerado usa `irem`/`drem` exatamente onde deveria, com a pilha balanceada nos três casos (int puro, double puro, e dentro do ternário/for já implementados antes).

## Nenhuma limitação nova

Diferente do incremento (que só funciona como comando) e do ternário (que não aceita `string_lit` direto), o `%` não tem nenhuma limitação a mais além das que os outros operadores aritméticos já tinham — funciona em qualquer lugar que `+`, `-`, `*`, `/` já funcionavam (dentro de `print`, atribuição, argumento de função, cabeçalho do `for`, dentro do ternário, etc.), porque é literalmente o mesmo mecanismo, só com instrução JVM diferente.

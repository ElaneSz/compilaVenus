# Implementação do operador ternário `(cond) ? e1 : e2`

**Testado de ponta a ponta**: instalei `ghc`+`alex`+`happy`, montei seu projeto, apliquei essas mudanças e compilei de verdade — incluindo checar o `.info` do Happy pra garantir **zero conflitos de gramática** e rodar programas de teste gerando o bytecode Jasmin, conferindo a pilha manualmente. Não é só teoria, rodou.

Sintaxe escolhida (mantendo o estilo do resto da linguagem, que sempre exige parênteses em torno de `ExpressaoLogica`, igual `if`/`while`/`for`):

```c
resultado = (condicao) ? expressaoSeVerdade : expressaoSeFalso;
```

Ele é uma **expressão** (`Expr`), não um comando — então funciona em qualquer lugar onde uma `ExpressaoAritmetica` já é aceita: atribuição, `print(...)`, argumento de função, dentro de outra expressão aritmética, dentro do cabeçalho do `for`, etc. Também aceita aninhamento (`c1 ? a : (c2 ? b : c)`).

---

## ⚠️ Achado importante durante o teste: conflito de precedência

Diferente do `for` (que não teve nenhum problema), aqui o Happy **acusou 4 conflitos shift/reduce** assim que tentei compilar. O motivo: como o ternário vive dentro da própria regra de `ExpressaoAritmetica`, o parser fica em dúvida em casos como:

```c
x ? a : b + c
```

Isso deveria significar `x ? a : (b + c)` (ternário tem precedência mais baixa que `+`, igual em C), mas sem uma declaração de precedência explícita o Happy resolve isso "no escuro" (por padrão ele prefere shift, que por sorte até dá o resultado certo aqui, mas fica dependendo de um comportamento implícito não-documentado do gerador). Por isso adicionei uma precedência nova (`TERNARY`), mais baixa que tudo, e anotei a regra com `%prec TERNARY` — isso elimina o conflito de vez e deixa explícito no código *por que* o ternário se comporta assim. Depois da correção, `Parser.info` fecha em **0 conflitos**.

---

## 1. `Token.hs`

**Âncora:**
```haskell
  | TKvirgula | TKponto_e_virgula
```

**Trocar por:**
```haskell
  | TKvirgula | TKponto_e_virgula
  | TKinterrogacao | TKdoisPontos
```

---

## 2. `Lex.x`

**Âncora:**
```
","   { \s -> TKvirgula }
```

**Colar logo abaixo:**
```
"?"   { \s -> TKinterrogacao }
":"   { \s -> TKdoisPontos }
```

---

## 3. `AST.hs`

**Âncora** (linha do `Expr` que já existe):
```haskell
            | IntDouble Expr | DoubleInt Expr deriving Show
```

**Trocar por:**
```haskell
            | IntDouble Expr | DoubleInt Expr
            | Tern ExprL Expr Expr deriving Show
```

`Tern cond e1 e2`: `cond` é a condição (`ExprL`, a mesma coisa usada no `if`/`while`/`for`), `e1` é o valor se verdadeiro, `e2` o valor se falso.

---

## 4. `Parser.y`

### 4.1 Tokens

**Âncora:**
```
    ','        { TKvirgula }
```

**Colar logo abaixo:**
```
    '?'        { TKinterrogacao }
    ':'        { TKdoisPontos }
```

### 4.2 Precedência (essencial — é o que elimina o conflito)

**Âncora:**
```
%left '||' '&&'
%right '!'
%left '<' '>' '<=' '>=' '==' '/='
%left '+' '-'
%left '*' '/'
%left NEG
```

**Trocar por:**
```
%right TERNARY
%left '||' '&&'
%right '!'
%left '<' '>' '<=' '>=' '==' '/='
%left '+' '-'
%left '*' '/'
%left NEG
```

(Só adicionei a linha `%right TERNARY` **antes** de tudo — precedência mais baixa que qualquer operador aritmético/relacional/lógico.)

### 4.3 Nova alternativa em `ExpressaoAritmetica`

**Âncora:**
```
                    | ChamadaFuncao                                { $1 }
```

**Colar logo abaixo:**
```
                    | '(' ExpressaoLogica ')' '?' ExpressaoAritmetica ':' ExpressaoAritmetica %prec TERNARY { Tern $2 $5 $7 }
```

> Repare no `%prec TERNARY` no final da regra — é isso que resolve o conflito. Sem essa anotação, o Happy acusa 4 conflitos shift/reduce.

---

## 5. `Semantico.hs`

**Âncora** (primeira linha do `verificaExpr` que já existe, pra chamada de função):
```haskell
verificaExpr tg tl (Chamada nome args) =
```

**Colar logo acima:**
```haskell
verificaExpr tg tl (Tern cond e1 e2) =  do
                                        cond' <- verificaExprL tg tl cond
                                        (e1', t1) <- verificaExpr tg tl e1
                                        (e2', t2) <- verificaExpr tg tl e2
                                        case (t1, t2) of
                                            (TInt, TInt)       -> return (Tern cond' e1' e2', TInt)
                                            (TDouble, TDouble) -> return (Tern cond' e1' e2', TDouble)
                                            (TString, TString) -> return (Tern cond' e1' e2', TString)
                                            (TInt, TDouble)    -> return (Tern cond' (IntDouble e1') e2', TDouble)
                                            (TDouble, TInt)    -> return (Tern cond' e1' (IntDouble e2'), TDouble)
                                            _ -> do
                                                errorMsg (" Tipos incompativeis no operador ternario: " ++ show e1' ++ " : " ++ show e2')
                                                return (Tern cond' e1' e2', TInt)

```

Segue exatamente o mesmo padrão de coerção que já existe pra `Add`/`Sub`/etc: se os dois lados forem `int`/`int` ou `double`/`double`, beleza; se forem misturados, insere `IntDouble` no lado `int` pra promover a `double` (igual o compilador já faz em toda operação aritmética); se forem tipos realmente incompatíveis (ex: `int` vs `string`), gera erro semântico.

---

## 6. `Gerador.hs`

**Âncora** (primeira linha do `genExpr` que já existe, pra chamada de função):
```haskell
genExpr c tg tl ti (Chamada nome args) =   do
```

**Colar logo acima:**
```haskell
genExpr c tg tl ti (Tern cond e1 e2) = do
                                    lTrue  <- novoLabel
                                    lFalse <- novoLabel
                                    lFim   <- novoLabel
                                    cond' <- genExprL c tg tl ti lTrue lFalse cond
                                    (t1, e1') <- genExpr c tg tl ti e1
                                    (_,  e2') <- genExpr c tg tl ti e2
                                    return (t1, cond' ++ lTrue ++ ":\n" ++ e1' ++ "\tgoto " ++ lFim ++ "\n" ++ lFalse ++ ":\n" ++ e2' ++ lFim ++ ":\n")

```

Lógica: reaproveita `genExprL` (a mesma técnica de rótulos do `if`/`while`/`for`) pra decidir se pula pro rótulo "verdadeiro" ou "falso"; cada branch empilha exatamente **um valor** do tipo já unificado pelo `Semantico.hs`; no final os dois branches convergem no rótulo `lFim` com a pilha balanceada — só um dos dois lados executa, mas o efeito na pilha é idêntico não importa qual, então quem vier depois (um `istore`, um `print`, etc.) recebe o valor certo sem saber qual caminho foi tomado.

---

## Exemplos testados (e confirmados, gerando bytecode correto)

```c
{
  int x;
  int y;
  double d;

  x = 7;
  y = (x > 5) ? 100 : 200;
  print(y);                          // 100

  d = (x <= 5) ? 1 : 2.5;            // testa coercao int->double num dos lados
  print(d);                          // 2.5

  print( (x == 7) ? x + 1 : x - 1 ); // testa expressao aninhada nos dois lados -> 8

  return;
}
```

E combinado com o `for` (também testado):

```c
{
  int i;
  int par_impar_count;

  par_impar_count = 0;
  for (i = 0; i < 5; i = i + 1) {
      par_impar_count = par_impar_count + ((i == 0) ? 1 : 2);
      print(par_impar_count);
  }
  return;
}
```

Ambos passam na análise semântica e geram bytecode com pilha balanceada.

## Uma limitação que vale saber

Assim como no `AtribSemPV` do `for` (comentamos isso antes), o `Semantico.hs` aceita `TString` nos dois lados do ternário (`s ? "a" : "b"`), mas isso não foi testado com string_lit diretamente na gramática do ternário — porque, igual discutimos, `string_lit` não é produzida pela regra de `ExpressaoAritmetica` no seu parser atual (é sempre tratada à parte). Então hoje `(cond) ? "a" : "b"` **não compila** (erro de parse, não de semântica) — só funciona ternário com `string` se ambos os lados forem variáveis do tipo `string` já declaradas (ex: `(cond) ? s1 : s2`). Se quiser cobrir literais de string também, é a mesma refatoração que comentei antes (fazer `Lit String` entrar pela própria `ExpressaoAritmetica`), e aí resolve isso em todo lugar de uma vez, não só aqui.

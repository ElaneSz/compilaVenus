# Implementação de `+=` e `-=` — trechos para colar no compilador original

## A ideia central (por que quase nada de novo precisa ser criado)

O `Comando` de atribuição já existe na AST como `Atrib Id Expr` (em `AST.hs`), e tanto o
`Semantico.hs` (`verificaComando`/`verificaExpr`) quanto o `Gerador.hs` (`genCmd`/`genExpr`)
**já sabem lidar perfeitamente com `Add` e `Sub`** (checagem de tipo, coerção int/double,
geração de `iadd`/`dadd`/`isub`/`dsub`, etc).

Então, em vez de criar um novo construtor de `Comando` (tipo `AtribMais` ou `AtribComposta`) e
replicar toda a lógica de tipos/coerção/codegen para ele, a solução é **desaçucarar a sintaxe
já no Parser**: quando o parser lê `x += expr`, ele já monta a árvore como se você tivesse
escrito `x = x + expr` (ou seja, `Atrib "x" (Add (IdVar "x") expr)`). Da perspectiva de
`Semantico.hs` e `Gerador.hs`, isso é **indistinguível** de uma atribuição normal — eles nem
percebem que é um "novo" tipo de instrução.

Resultado: **`Semantico.hs` e `Gerador.hs` não precisam de nenhuma alteração.** Só mexemos em
`Token.hs`, `Lex.x` e `Parser.y` (léxico + gramática), e nenhuma função nova é criada — só
novos construtores de token e duas novas alternativas de regra gramatical reaproveitando
`Add`, `Sub`, `IdVar` e `Atrib`, que já existem.

Abaixo, cada bloco tem uma **âncora** (um trecho exato que já existe no seu arquivo) pra você
usar Ctrl+F e achar onde colar.

---

## 1. `Token.hs` — novos tokens

**Ancora (procure por esta linha exata):**
```haskell
  | TKmais | TKmenos | TKmult | TKdiv
```

**Cole logo abaixo dela:**
```haskell
  -- Operadores de atribuição composta (+= e -=)
  | TKmaisatrib | TKmenosatrib
```

---

## 2. `Lex.x` — reconhecendo `+=` e `-=`

**Âncora (procure por este bloco exato):**
```haskell
-- Operadores aritméticos
"+"   { \s -> TKmais }
"-"   { \s -> TKmenos }
"*"   { \s -> TKmult }
"/"   { \s -> TKdiv }
```

**Cole ANTES desse bloco (mesma convenção já usada no arquivo pros operadores relacionais,
que colocam `<=`, `>=`, `==` antes de `<`, `>`):**
```haskell
-- Operadores de atribuição composta (2 chars, antes dos de 1 char)
"+="  { \s -> TKmaisatrib }
"-="  { \s -> TKmenosatrib }

```
> Nota técnica: o Alex já usa "maximal munch" (sempre casa o lexema mais longo possível), então
> tecnicamente a ordem aqui não mudaria o resultado — `+=` sempre vai vencer `+` sozinho. Colocar
> antes é só para manter a mesma convenção de legibilidade que o arquivo já usa em `<=`/`>=`/`==`.

---

## 3. `Parser.y` — dois pontos de alteração

### 3.1 Declarar os tokens

**Âncora (procure por este bloco exato):**
```haskell
    '+'        { TKmais }
    '-'        { TKmenos }
    '*'        { TKmult }
    '/'        { TKdiv }
```

**Cole logo abaixo:**
```haskell
    '+='       { TKmaisatrib }
    '-='       { TKmenosatrib }
```

(Não é necessário mexer nas linhas de `%left`/`%right` — `+=` e `-=` só aparecem dentro de
`CmdAtrib`, nunca dentro de `ExpressaoAritmetica`, então não entram em nenhum conflito de
precedência novo.)

### 3.2 Nova regra em `CmdAtrib`

**Âncora (procure por este bloco exato):**
```haskell
CmdAtrib : id '=' ExpressaoAritmetica ';' { Atrib $1 $3 }
         | id '=' string_lit ';'          { Atrib $1 (Lit $3) }
```

**Substitua por (adicionando as duas novas alternativas):**
```haskell
CmdAtrib : id '=' ExpressaoAritmetica ';'  { Atrib $1 $3 }
         | id '=' string_lit ';'           { Atrib $1 (Lit $3) }
         | id '+=' ExpressaoAritmetica ';' { Atrib $1 (Add (IdVar $1) $3) }
         | id '-=' ExpressaoAritmetica ';' { Atrib $1 (Sub (IdVar $1) $3) }
```

É só isso. `x += expr;` vira `Atrib "x" (Add (IdVar "x") expr)` e `x -= expr;` vira
`Atrib "x" (Sub (IdVar "x") expr)` — exatamente a árvore que já seria gerada para
`x = x + expr;` / `x = x - expr;`, então toda a checagem de tipo (incluindo coerção
int/double com aviso, igual já acontece hoje) e toda a geração de bytecode continuam
automaticamente valendo, sem tocar em `Semantico.hs` nem em `Gerador.hs`.

---

## Testando

Depois de colar os trechos acima e rodar `make` (que regenera `Lex.hs` via `alex` e
`Parser.hs` via `happy`), este trecho já deve compilar:

```c
int contador;
double valor;

contador = 10;
contador += 5;   // vira: contador = contador + 5;  -> 15
contador -= 3;   // vira: contador = contador - 3;  -> 12

valor = 10.0;
valor += contador;  // TInt sendo somado a TDouble -> coerção automática (IntDouble), sem aviso
print(contador);
print(valor);
```

Um arquivo de teste pronto (`Teste_ComposicaoAtrib.j--`) está anexado junto com este patch,
caso queira só rodar direto.

---

## Bônus: como `*=` e `/=` funcionariam (não implementados, por pedido seu)

### `*=` (multiplicação e atribuição) — mesmo padrão, sem pegadinha
Seguiria **exatamente** a mesma receita de `+=`/`-=`, porque `Mul` já é totalmente suportado
por `Semantico.hs` e `Gerador.hs`:

- `Token.hs`: adicionar `TKmultatrib`
- `Lex.x`: adicionar `"*=" { \s -> TKmultatrib }` (antes da regra de `"*"`)
- `Parser.y`: declarar o token `'*=' { TKmultatrib }` e adicionar a alternativa
  `id '*=' ExpressaoAritmetica ';' { Atrib $1 (Mul (IdVar $1) $3) }` em `CmdAtrib`

Nenhuma outra mudança necessária, pelo mesmo motivo do `+=`/`-=`.

### `/=` (divisão e atribuição) — aqui tem uma pegadinha real nessa linguagem
Se você tentar aplicar a mesma receita literalmente com o símbolo `/=`, vai esbarrar em um
problema que não existe com `+`/`-`/`*`: **o lexema `/=` já está em uso** — em `Lex.x` ele já
é reconhecido como `TKdif`, o operador relacional "diferente de" (`Rdif` na AST, usado em
`if`/`while`, ex: `y /= 0.0` no `Teste1.j--` significa "y diferente de 0.0", não "divida y por
0.0"). Diferente de linguagens tipo C (onde `!=` é "diferente" e `/=` é "divida e atribua"),
aqui quem herda o símbolo `/=` foi o "diferente".

Se você adicionar uma segunda regra no Alex casando também `"/="` (agora para
`TKdivatrib`), as duas regras teriam o mesmo tamanho de match (2 caracteres) — e quando o Alex
empata no tamanho do lexema, ele desempata pela **ordem das regras no arquivo**, não por
contexto. Ou seja, a regra de `TKdif` (que já está antes) sempre ganharia, e a nova regra de
`TKdivatrib` nunca seria alcançada — o compilador nunca enxergaria `/=` como "divida e
atribua", só como "diferente".

Pra implementar de verdade uma divisão-e-atribuição, você precisaria de um símbolo/lexema
diferente pra ela (já que `/=` está ocupado semanticamente por "diferente" nessa linguagem) —
por exemplo, reservar uma sequência que hoje não existe. Fora essa escolha de símbolo, a parte
de trás (gramática + reuso de `Div` no `Atrib`) seria idêntica ao que fizemos com `+=`/`-=`/`*=`.

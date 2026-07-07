# Implementação de incremento pós-fixado `a++`

**Testado de ponta a ponta** (mesma disciplina do `for`, do ternário e dos comentários): compilei de verdade, chequei o `.info` do Happy pra garantir zero conflitos, e rodei um programa de teste cobrindo `int`, `double` e uso dentro do `for`, conferindo a AST anotada e o bytecode gerado.

## A sacada: não precisa de árvore nova nenhuma

`a++` não é um conceito novo pro seu compilador — ele é só **açúcar sintático** pra exatamente o que o `CmdAtrib` já faz. Ou seja, a regra da gramática já traduz `a++` direto pra `Atrib "a" (Add (IdVar "a") (Const (CInt 1)))` no próprio parser, sem precisar de nenhum construtor novo na AST. Isso significa: **`AST.hs`, `Semantico.hs` e `Gerador.hs` ficam 100% intocados.** Só mexe em `Token.hs`, `Lex.x` e `Parser.y`.

De brinde, isso já resolve sozinho o caso de `a++` numa variável `double`: como o `Add` já tem a lógica de coerção `int`→`double` implementada (usada em toda soma do seu compilador, e testada de novo agora), `d++` já gera `d = d + 1.0` certinho, sem eu precisar escrever nada a mais pra isso.

---

## 1. `Token.hs`

**Âncora:**
```haskell
  | TKmais | TKmenos | TKmult | TKdiv
```

**Trocar por:**
```haskell
  | TKmais | TKmenos | TKmult | TKdiv | TKincremento
```

---

## 2. `Lex.x`

**Âncora:**
```
"+"   { \s -> TKmais }
```

**Trocar por:**
```
"++"  { \s -> TKincremento }
"+"   { \s -> TKmais }
```

(`"++"` antes de `"+"` só por convenção — o resto do arquivo já segue esse estilo de colocar o operador de 2 caracteres antes do de 1, tipo `"<="` antes de `"<"`. Na prática nem precisaria, porque o Alex sempre escolhe o casamento mais longo possível de qualquer forma.)

---

## 3. `Parser.y`

### 3.1 Token

**Âncora:**
```
    '+'        { TKmais }
```

**Colar logo abaixo:**
```
    '++'       { TKincremento }
```

### 3.2 Novo comando na lista de `Comando`

**Âncora:**
```
Comando : CmdSe       { $1 }
        | CmdEnquanto { $1 }
        | CmdPara     { $1 }
        | CmdAtrib    { $1 }
        | CmdEscrita  { $1 }
        | Retorno     { $1 }
        | CmdLeitura  { $1 }
        | ChamadaProc { $1 }
```

**Trocar por:**
```
Comando : CmdSe        { $1 }
        | CmdEnquanto  { $1 }
        | CmdPara      { $1 }
        | CmdAtrib     { $1 }
        | CmdIncremento{ $1 }
        | CmdEscrita   { $1 }
        | Retorno      { $1 }
        | CmdLeitura   { $1 }
        | ChamadaProc  { $1 }
```

### 3.3 A regra nova

**Âncora:**
```
CmdAtrib : id '=' ExpressaoAritmetica ';' { Atrib $1 $3 }
         | id '=' string_lit ';'          { Atrib $1 (Lit $3) }
```

**Colar logo abaixo:**
```
CmdIncremento : id '++' ';' { Atrib $1 (Add (IdVar $1) (Const (CInt 1))) }
```

---

## 4. Bônus opcional: `a++` também no cabeçalho do `for`

Testei e o caso mais comum de incremento na vida real — `for (i = 0; i < 10; i++)` — **não funciona só com o que está acima**, porque o `AtribSemPV` (criado pro `for`) não tem essa forma. Se você quiser esse caso também (recomendo, é o uso mais natural), é só mais uma linha:

**Âncora:**
```
AtribSemPV : id '=' ExpressaoAritmetica { Atrib $1 $3 }
           | id '=' string_lit          { Atrib $1 (Lit $3) }
```

**Trocar por:**
```
AtribSemPV : id '=' ExpressaoAritmetica { Atrib $1 $3 }
           | id '=' string_lit          { Atrib $1 (Lit $3) }
           | id '++'                    { Atrib $1 (Add (IdVar $1) (Const (CInt 1))) }
```

Se você não quiser isso, é só não colar essa parte — o resto funciona normal, só que `for (...; ...; i++)` vai dar erro de sintaxe (tem que usar `for (...; ...; i = i + 1)` do jeito de sempre nesse caso).

---

## Como adicionar `--` depois (você já sabia, mas só pra confirmar)

Exatamente como você imaginou: é a mesma receita, trocando `TKincremento`/`"++"` por um `TKdecremento`/`"--"` novo, e trocando `Add` por `Sub` na ação semântica:

```
CmdDecremento : id '--' ';' { Atrib $1 (Sub (IdVar $1) (Const (CInt 1))) }
```

Sem pegadinha nenhuma aqui — `Sub` já existe e já tem a mesma coerção `int`/`double` que o `Add`.

---

## Testado (bytecode conferido manualmente)

```c
{
  int a;
  double d;
  int i;
  int soma;

  a = 5;
  a++;
  print(a);      // 6

  d = 2.5;
  d++;
  print(d);      // 3.5

  soma = 0;
  for (i = 0; i < 5; i++) {
      soma++;
  }
  print(soma);   // 5

  return;
}
```

Passa na análise semântica sem erros, e o bytecode gerado pro `d++` mostra exatamente o `i2d` sendo aplicado antes do `dadd` (a mesma coerção que o `Tern` já usava) — então `double` incrementa certinho, sem eu ter escrito nenhuma linha nova pra isso.

## Limitação que vale saber

`a++` aqui só funciona como **comando** (statement), igual `CmdAtrib` — não dá pra usar como sub-expressão tipo `b = a++ + 3;` ou passar `a++` como argumento de função. Isso é proposital: implementar o valor de retorno do pós-incremento (que em C teria que "lembrar" o valor antigo de `a` antes de somar) exigiria mudar `ExpressaoAritmetica` e o `Gerador.hs` pra lidar com efeito colateral dentro de uma expressão — bem mais complexo, e você não pediu isso. Do jeito que está, cobre o caso de uso de longe mais comum (incrementar contador em loop), que era exatamente o `for(...; ...; i++)` que testei acima.

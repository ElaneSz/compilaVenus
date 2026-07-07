# Implementação de comentários `// linha` e `/* bloco */`

**Testado de ponta a ponta** (mesma disciplina do `for` e do ternário): compilei de verdade com `alex`, rodei uma bateria de casos-limite isolados no lexer, e depois testei um programa `.j--` completo misturando comentários com `for` e ternário, conferindo a AST final e o bytecode gerado.

Diferente do `for` e do ternário, comentário é **só lexer**. Ele nunca deveria virar token — o próprio lexer descarta o texto e segue escaneando, exatamente como já acontece hoje com espaços em branco (`$white+   ;`). Por isso **só mexe no `Lex.x`**; `Parser.y`, `AST.hs`, `Semantico.hs` e `Gerador.hs` ficam intocados.

---

## ⚠️ Achado importante durante o teste: pegadinha clássica do Alex com `\n`

Minha primeira tentativa de regex pro comentário de bloco (a forma "padrão" que qualquer livro de compiladores mostra) **quebrou** especificamente em comentários com quebra de linha dentro:

```c
/* comentario
   em varias
   linhas */
```

Isso porque, **no Alex, uma classe de caractere negada como `[^\*]` exclui `\n` por padrão** — só inclui ele se você pedir explicitamente. Repare que isso é exatamente o motivo de o seu próprio `Lex.x` já ter essa linha lá em cima:

```
$any    = [.\n]
```

O `.` sozinho já exclui newline (convenção clássica de regex), e o autor original já tinha contornado isso unindo `\n` de volta. Eu caí na mesma pegadinha ao escrever a regra do comentário de bloco e só percebi rodando o teste de verdade (o `"/*"` virava dois tokens soltos, `TKdiv` e `TKmult`, ao invés de iniciar um comentário, todo santa vez que havia uma quebra de linha no meio). A correção é sempre unir `\n` de volta explicitamente nas classes negadas: `([^\*] | \n)` em vez de só `[^\*]`.

---

## O arquivo: `Lex.x`

**Âncora** (a regra de espaço em branco que já existe, bem no topo das regras):
```
-- Ignorar espaços e quebras de linha
$white+   ;
```

**Trocar por:**
```
-- Ignorar espaços e quebras de linha
$white+   ;

-- Comentarios (precisam vir antes das regras de operador, pra "//" e "/*"
-- ganharem do "/" de divisao por maximal munch)
"//" [^\n]*                                          ;
"/*" (([^\*] | \n) | \*+ ([^\*\/] | \n))* \*+ "/"     ;
```

É só isso — duas linhas novas, e ambas terminam em `;` (a mesma convenção que o `$white+` já usa: "casou com a regra, mas não produz token nenhum, só descarta e continua escaneando").

### Por que essa posição importa

Essa regra **precisa** vir antes (ou pelo menos não depois, tanto faz a ordem entre si) das regras de operadores aritméticos (`"/"`, `"*"`), porque tanto `"//"` quanto `"/*"` começam com `/`, que também é o operador de divisão. O Alex resolve isso pela regra do **"maximal munch"**: entre todas as regras que casam a partir da posição atual, ele sempre escolhe a que casa o **trecho mais longo** — então, ao ver `//` ou `/* ... */`, ele nunca vai confundir com uma divisão sozinha (`/`), porque o comentário sempre "come" mais caracteres. Não teria problema nenhum mesmo se você colasse essas duas linhas em outro lugar do arquivo, contanto que estejam na mesma seção `:-` (a ordem entre regras só desempata quando o comprimento do casamento é IGUAL, o que nunca acontece aqui).

### Por que a regex do bloco é essa exatamente (e não `"/*" $any* "*/"`)

A tentação óbvia seria escrever algo tipo `"/*" $any* "*/"` (usando o `$any` que já existe no arquivo). O problema é que isso **não** funciona direito: como o Alex sempre casa o trecho mais longo possível, um `.*`-estilo genérico entre `/*` e `*/` vai "comer" até o **último** `*/` do arquivo inteiro, não o primeiro. Ou seja, dois comentários separados tipo:

```c
/* primeiro comentario */
codigo_de_verdade();
/* segundo comentario */
```

virariam **um comentário só gigante**, engolindo `codigo_de_verdade();` no meio (que é exatamente o tipo de bug sorrateiro que só aparece quando você tem *mais de um* comentário no arquivo — fácil de não perceber testando só um comentário isolado).

A regex que usei (`([^\*] | \n) | \*+ ([^\*\/] | \n)`) é a construção clássica que resolve isso: ela só aceita avançar enquanto o texto **não formar um `*/` válido**, então o Alex é forçado a parar exatamente no primeiro fechamento. Testei isso explicitamente com um caso "falso-aninhado":

```c
/* a /* b */ c */
```

E o resultado bateu com o esperado (igual C de verdade, que **não tem comentários aninhados**): o comentário fecha no primeiro `*/`, sobrando `c */` como código de verdade (que o resto do lexer trata normalmente — o `c` vira identificador, e o `*/` sobrando vira `TKmult` seguido de `TKdiv`, já que não há mais nenhum comentário ali).

---

## Casos testados (todos passando)

| Caso | Entrada | Resultado |
|---|---|---|
| Linha simples | `int x; // comentario\nx = 3;` | comentário sumiu, resto tokenizado normal |
| Bloco em uma linha | `int x; /* comentario */ x = 3;` | idem |
| **Bloco em várias linhas** | `/* comentario\nem varias\nlinhas */` | idem (era o caso que quebrava antes da correção) |
| Bloco vazio | `/**/` | idem |
| Bloco cheio de asteriscos | `/** javadoc ** com * varios * asteriscos **/` | idem |
| "Falso-aninhado" | `/* a /* b */ c */` | fecha no primeiro `*/`, `c */` vira código de verdade (comportamento correto, igual C) |
| Divisão de verdade não pode sumir | `x = 10 / 2;` | `/` continua sendo `TKdiv` normalmente |
| Comentário `//` até o fim do arquivo (sem quebra de linha depois) | `int x; // fim sem quebra de linha` | comentário sumiu, sem erro |
| Comentário `//` vazio | `int x; //\nx = 3;` | idem |

E de ponta a ponta, com `for` + ternário + comentários juntos:

```c
{
  // declaracoes principais
  int i;
  int soma; /* acumulador da soma */

  soma = 0; // inicializa

  /*
   * Loop que soma de 0 a 4,
   * usando o novo "for"
   */
  for (i = 0; i < 5; i = i + 1) {
      soma = soma + ((i == 2) ? 10 : i); // usa o ternario tambem
  }

  print(soma); /* deve imprimir 0+1+10+3+4 = 18 */
  return;
}
```

A AST final saiu **completamente limpa** de comentários (como deveria — eles nem chegam a existir como tokens), e o bytecode gerado calcula certinho `soma = 18`.

## Uma observação sobre erro do programador (não é bug, é esperado)

Se você **esquecer de fechar** um comentário de bloco (`/* isso nunca fecha...`), o lexer não vai dar um erro claro tipo "comentário não fechado" — como a regex inteira do comentário nunca chega a casar (falta o `*/`), o Alex cai de volta pras regras normais, então o `/` vira divisão, o próximo `*` vira multiplicação, e o resto do "comentário" é lexado como se fosse código de verdade (provavelmente virando uma sequência de identificadores sem sentido, que o `Parser.y` vai rejeitar com um erro sintático, só que num lugar meio confuso do arquivo). Isso é uma limitação comum de lexers simples feitos com Alex/Lex — resolver direito exigiria um "estado" de lexer separado (Alex tem suporte a isso via "startcodes", mas é uma mudança bem maior de estrutura). Pra um compilador de disciplina, normalmente não vale a pena — só fica sabendo que "comentário sem fechar" vai dar um erro de sintaxe meio esquisito em vez de uma mensagem direta, então se algum teste seu der erro sintático inesperado, checar primeiro se não esqueceu um `*/`.

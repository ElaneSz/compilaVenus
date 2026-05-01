# Tradutor CSV → JSON

Trabalho da disciplina de **Compiladores** - Departamento de Ciência da Computação, UDESC Joinville.

Tradutor de arquivos no formato **CSV para JSON**, implementado em Haskell utilizando os geradores **Alex** (analisador léxico) e **Happy** (analisador sintático).

---

## Exemplo

**Entrada (`teste.csv`)**
```
Nome, Endereco, Cidade, Cadastro Ativo
Cristiano Vasconcellos, "Rua Angelo Sampaio, 1000", Curitiba, true
Gabriela Moreira, "Rua Paulo Malschitzki, 200", Joinvile, true
Paulo Torrens, "Av. do Contorno, 12", Belo Horizonte, false
```

**Saída (`saida.json`)**
```json
[
  {
    "Nome": "Cristiano Vasconcellos",
    "Endereco": "Rua Angelo Sampaio, 1000",
    "Cidade": "Curitiba",
    "Cadastro Ativo": "true"
  },
  {
    "Nome": "Gabriela Moreira",
    "Endereco": "Rua Paulo Malschitzki, 200",
    "Cidade": "Joinvile",
    "Cadastro Ativo": "true"
  },
  {
    "Nome": "Paulo Torrens",
    "Endereco": "Av. do Contorno, 12",
    "Cidade": "Belo Horizonte",
    "Cadastro Ativo": "false"
  }
]
```

---

## Estrutura do Projeto

```
TradutorDeArquivos/
├── TokenCSV.hs     - Definição dos tokens do CSV
├── LexCSV.x        - Analisador léxico (Alex)
├── ParserCSV.y     - Analisador sintático e main (Happy)
├── AST.hs          - Definição da AST do CSV
├── JSON.hs         - Geração do JSON a partir da AST
├── Makefile        - Automação da compilação
├── teste.csv       - Arquivo de entrada de exemplo
└── saida.json      - Arquivo de saída gerado
```

---

## Descrição dos Arquivos

### `TokenCSV.hs`
Define os três tokens reconhecidos pelo analisador léxico, conforme especificado pelo enunciado:

```haskell
data Token
  = NEWLINE        -- quebra de linha '\n'
  | SEP            -- separador ','
  | FIELD String   -- conteúdo de um campo
```

### `LexCSV.x`
Analisador léxico gerado pelo **Alex**. Define as regras de tokenização do CSV:

| Padrão | Token gerado | Observação |
|---|---|---|
| `\n`, `\r\n` | `NEWLINE` | Suporta Unix e Windows |
| `,` | `SEP` | Separador de campos |
| `" [^\"]* "` | `FIELD String` | Campo entre aspas - permite vírgulas e `\n` internos |
| `[^\,\"\n\r]+` | `FIELD String` | Campo sem aspas - `trim` remove espaços das bordas |

> **Observação:** espaços entre a vírgula e o próximo campo (ex: `, "Rua..."`) são tratados pela função `filterTokens` no módulo `JSON.hs`.

### `AST.hs`
Define a Árvore Sintática Abstrata (AST) do CSV:

```haskell
type Cabecalho = [String]
type Registro  = [String]
data CSV       = CSV Cabecalho [Registro]
```

O cabeçalho é uma lista com os nomes dos campos. Cada registro é uma lista com os valores dos campos. A função `toCSV` converte o par retornado pelo parser na AST formal.

### `JSON.hs`
Responsável pela geração do JSON a partir da AST. Contém:

- **`filterTokens`** - descarta tokens `FIELD` compostos apenas de espaços que são gerados quando o CSV tem espaço entre a vírgula e o campo seguinte.
- **`escapeJSON`** - escapa caracteres especiais (`"`, `\`, `\n`) para produzir JSON válido.
- **`toJSON`** - percorre a AST e monta o array JSON completo.
- **`recordToJSON`** - converte um registro em um objeto JSON `{ }`, emparelhando chaves do cabeçalho com os valores do registro via `zipWith`.
- **`fieldToJSON`** - formata um par chave/valor como `"chave": "valor"`.
- **`intercalateStr`** - junta uma lista de strings com um separador, sem separador no último elemento.

### `ParserCSV.y`
Analisador sintático gerado pelo **Happy**. Define a gramática do CSV e o `main` do programa.

**Gramática:**
```
CSV       → Linha newline Registros newline
          | Linha newline Registros
          | Linha newline

Registros → Registros newline Linha
          | Linha

Linha     → Linha sep field
          | field
```

**Fluxo do `main`:**
```
arquivo CSV → alexScanTokens → filterTokens → parseCSV → toCSV → toJSON → arquivo JSON
```

---

## Dependências

- [GHC](https://www.haskell.org/ghc/) - compilador Haskell
- [Alex](https://haskell-alex.readthedocs.io/) - gerador de analisadores léxicos
- [Happy](https://haskell-happy.readthedocs.io/) - gerador de analisadores sintáticos

### Instalação das dependências (Ubuntu / GitHub Codespaces)

```bash
sudo apt-get update
sudo apt-get install -y ghc cabal-install
cabal update
cabal install alex happy --overwrite-policy=always
echo 'export PATH=$HOME/.cabal/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

---

## Como Compilar

```bash
make
```

O `make` executa automaticamente:
1. `alex LexCSV.x` - gera `LexCSV.hs`
2. `happy ParserCSV.y` - gera `ParserCSV.hs`
3. `ghc --make -o TradutorDeArquivos ParserCSV.hs` - compila tudo

Para limpar os arquivos gerados:
```bash
make clean
```

---

## Como Usar

```bash
./TradutorDeArquivos <entrada.csv> <saida.json>
```

**Exemplo:**
```bash
./TradutorDeArquivos teste.csv saida.json
```

O programa imprime o JSON no terminal e salva o resultado no arquivo de saída informado.

---

## Formato CSV Suportado

- A **primeira linha** é o cabeçalho com os nomes dos campos.
- As **linhas seguintes** são registros com os valores de cada campo.
- O **separador** de campos é a vírgula `,`.
- Campos podem estar **entre aspas** - nesse caso podem conter vírgulas e quebras de linha internamente.
- Espaços após as vírgulas são ignorados automaticamente.
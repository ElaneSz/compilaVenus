# -------------------------------------------------------
# Makefile — Tradutor CSV → JSON com Alex + Happy
# -------------------------------------------------------
# Dependências: GHC, Alex, Happy
#   cabal install alex happy   (ou stack install alex happy)
# -------------------------------------------------------

all: TradutorDeArquivos

# 1. Gera LexCSV.hs a partir do LexCSV.x (Alex)
LexCSV.hs: LexCSV.x
	alex LexCSV.x

# 2. Gera ParserCSV.hs a partir do ParserCSV.y (Happy)
ParserCSV.hs: ParserCSV.y
	happy ParserCSV.y

# 3. Compila tudo com GHC
TradutorDeArquivos: LexCSV.hs ParserCSV.hs TokenCSV.hs
	ghc --make -o TradutorDeArquivos ParserCSV.hs

clean:
	rm -f *.hi *.o LexCSV.hs ParserCSV.hs TradutorDeArquivos

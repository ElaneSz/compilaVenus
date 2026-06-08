# Compilador - Makefile

# Configurações
GHC      = ghc
HAPPY    = happy
ALEX     = alex
TARGET   = compilador

# Arquivos gerados
GEN_HS   = Lex.hs Parser.hs

# Flags
GHC_FLAGS = --ghc

.PHONY: all clean run

# Alvo padrão: gera tudo e compila
all: $(TARGET)

# Gera o Lex.hs a partir do Lex.x
Lex.hs: Lex.x
	$(ALEX) Lex.x

# Gera o Parser.hs a partir do Parser.y
Parser.hs: Parser.y
	$(HAPPY) $(GHC_FLAGS) Parser.y


$(TARGET): Lex.hs Parser.hs
	$(GHC) Main.hs Semantico.hs -o $(TARGET)

# Remove arquivos gerados e compilados
clean:
	rm -f $(TARGET) $(GEN_HS) *.hi *.o Parser.info

# echo "{ int x; x = 1 + 2; }" | ./compilador 
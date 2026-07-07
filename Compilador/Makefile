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

# Compila o executável garantindo a inclusão do Semantico, Gerador e AST
$(TARGET): Lex.hs Parser.hs AST.hs Semantico.hs Gerador.hs Main.hs
	$(GHC) Main.hs Semantico.hs Gerador.hs AST.hs -o $(TARGET)


run: $(TARGET)
	cat Teste.j-- | ./$(TARGET)
	@if [ -f Programa.j ]; then \
		java -jar jasmin.jar Programa.j; \
		echo "\n=== Executando o programa na JVM ==="; \
		java Programa; \
	fi

# Remove arquivos gerados e compilados (limpa também arquivos .j eventualmente gerados)
clean:
	rm -f $(TARGET) $(GEN_HS) *.hi *.o Parser.info *.j
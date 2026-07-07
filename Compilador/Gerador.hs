module Gerador where

import Control.Monad.State
import AST
import Data.Map (Map)
import qualified Data.Map as Map
import Semantico (TabelaGlobal, TabelaLocal)

novoLabel :: State Int String
novoLabel = do
            n <- get
            put (n + 1)
            return ("l" ++ show n)

genCab :: String -> State Int String
genCab nome = return (
                        ".class public " ++ nome ++
                        "\n.super java/lang/Object\n\n" ++
                        ".method public <init>()V\n" ++
                        "\taload_0\n" ++
                        "\tinvokenonvirtual java/lang/Object/<init>()V\n" ++
                        "\treturn\n" ++
                        ".end method\n\n"
                     )

genMainCab :: Int -> Int -> State Int String
genMainCab s l = return (
                            ".method public static main([Ljava/lang/String;)V" ++
                            "\n\t.limit stack " ++ show s ++
                            "\n\t.limit locals " ++ show l ++ "\n\n"
                        )

genMainFim :: State Int String
genMainFim = return "\treturn\n.end method\n"

-- Função principal do gerador: roda genProg no estado inicial (contador de labels = 0) e pega só o código gerado
gerar :: String -> Programa -> String
gerar nome p = fst $ runState (genProg nome p) 0

-- Retorna quantos espaços na stack ocupa cada tipo
-- Todos ocupam 1, só double e long que ocupam 2
tamanhoTipo :: Tipo -> Int
tamanhoTipo TDouble = 2
tamanhoTipo _       = 1

-- Função pra calcular o .limit locals quando a gente for definir uma função (vai ser usado no genFuncao)
numLimitLocals :: [Var] -> Int
numLimitLocals vars = sum (map pegaTamanho vars)
                 where pegaTamanho (_ :#: (t, _)) = tamanhoTipo t

-- Pra facilitar na hora de fazer o Chamada, pega o tipo de um parâmetro da função, e retorna ele em "linguagem jvm"
-- Usar com um concatMap com isso nos parametros da função + chamar de novo para o retorno da função
-- pra sair algo do tipo invokestatic NomeDoPrograma/NomeFuncao(II)V
tipoJVM :: Tipo -> String
tipoJVM TInt    = "I"
tipoJVM TDouble = "D"
tipoJVM TString = "Ljava/lang/String;"
tipoJVM TVoid   = "V"

-- Tabela global (nome da funcao -> tipos dos parametros e tipo de retorno), construida a partir da lista de Funcao
-- A gente não vai precisar do nome dos parâmetros aqui, já que eles vão estar na TabelaLocal da função
constroiTabelaGlobal :: [Funcao] -> TabelaGlobal
constroiTabelaGlobal funcs = Map.fromList (map paraAssinatura funcs)
                                where paraAssinatura (nome :->: (vars, ret)) = (nome, (map pegaTipoDaVar vars, ret))
                                      pegaTipoDaVar (_ :#: (t, _)) = t

-- Tabela local de tipos (nome da variavel -> tipo), parecida com constroiTabelaIndices, só que guarda o tipo em vez do indice
-- Vamo precisar pra conseguir usar de fato o getTipoVar
constroiTabelaLocal :: [Var] -> TabelaLocal
constroiTabelaLocal vars = Map.fromList (map paraTipo vars)
                              where paraTipo (nome :#: (t, _)) = (nome, t)

-- [precisa de uma tabela que mapeie nome -> índice] vai precisar dessa tabela para gerar os iload/dload
type TabelaIndices = Map Id Int

constroiTabelaIndices :: [Var] -> TabelaIndices
constroiTabelaIndices vars =    Map.fromList (zip (map getNome vars) (indices vars 0))
                                -- Agora a gente consegue pegar o tamanho certo do frame de cada variável
                                -- Double e long ocupam 2 espaços na pilha, o resto é 1 (mas a gente não tem long)
                                where getNome (nome :#: _) = nome
                                      indices [] _ = []
                                      indices ((_ :#: (t, _)):vs) f = f : indices vs (f + tamanhoTipo t)

-- [função para pegar o tipo de uma variavel pelo nome] -> vamos precisar dela em genExpr para saber se usa iload ou dload
getTipoVar :: TabelaLocal -> Id -> Tipo
getTipoVar tl nome = case Map.lookup nome tl of
                        Just t  -> t
                        Nothing -> TInt -- fallback, nao deve ocorrer apos semantica

genExpr :: String -> TabelaGlobal -> TabelaLocal -> TabelaIndices -> Expr -> State Int (Tipo, String)

genInt :: Int -> String
genInt  i
        | i == -1 = "\ticonst_m1\n" 
        | i >= 0 && i <= 5  = "\ticonst_" ++ show i ++ "\n"
        | i >= -128 && i <= 127   = "\tbipush " ++ show i ++ "\n"
        | i >= -32768 && i <= 32767 = "\tsipush " ++ show i ++ "\n"
        | otherwise = "\tldc " ++ show i ++ "\n"

genDouble :: Double -> String
genDouble d = "\tldc2_w " ++ show d ++ "\n"

genOp :: Tipo -> String -> String
genOp TInt    op = "\ti" ++ op ++ "\n"
genOp TDouble op = "\td" ++ op ++ "\n"
genOp _       op = "\ti" ++ op ++ "\n"

-- Constante inteira
genExpr c tg tl ti (Const (CInt n))    = return (TInt, genInt n)

-- Constante double
genExpr c tg tl ti (Const (CDouble d)) = return (TDouble, genDouble d)

-- String literal
genExpr c tg tl ti (Lit s) = return (TString, "\tldc \"" ++ s ++ "\"\n")

-- Variavel
genExpr c tg tl ti (IdVar nome) =  let tipo = getTipoVar tl nome
                                       idx  = case Map.lookup nome ti of
                                                   Just i  -> i
                                                   Nothing -> 0
                                       instr = case tipo of
                                                   TInt    -> "\tiload " -- Para int
                                                   TDouble -> "\tdload " -- Para double
                                                   _       -> "\taload " -- Para string
                                   in return (tipo, instr ++ show idx ++ "\n")

genExpr c tg tl ti (Add e1 e2) =   do
                                (t1, e1') <- genExpr c tg tl ti e1
                                (t2, e2') <- genExpr c tg tl ti e2
                                return (t1, e1' ++ e2' ++ genOp t1 "add")

genExpr c tg tl ti (Sub e1 e2) =   do
                                (t1, e1') <- genExpr c tg tl ti e1
                                (t2, e2') <- genExpr c tg tl ti e2
                                return (t1, e1' ++ e2' ++ genOp t1 "sub")

genExpr c tg tl ti (Mul e1 e2) =   do
                                (t1, e1') <- genExpr c tg tl ti e1
                                (t2, e2') <- genExpr c tg tl ti e2
                                return (t1, e1' ++ e2' ++ genOp t1 "mul")

genExpr c tg tl ti (Div e1 e2) =   do
                                (t1, e1') <- genExpr c tg tl ti e1
                                (t2, e2') <- genExpr c tg tl ti e2
                                return (t1, e1' ++ e2' ++ genOp t1 "div")

genExpr c tg tl ti (IntDouble e) = do
                                (_, e') <- genExpr c tg tl ti e
                                return (TDouble, e' ++ "\ti2d\n")

genExpr c tg tl ti (DoubleInt e) = do
                                (_, e') <- genExpr c tg tl ti e
                                return (TInt, e' ++ "\td2i\n")

genExpr c tg tl ti (Neg e) =   do
                            (t, e') <- genExpr c tg tl ti e
                            return (t, e' ++ genOp t "neg")

-- Gera o código de cada argumento, consulta a tabela global (tg) para pegar
-- os tipos dos parâmetros e o tipo de retorno da função, monta o descritor JVM
-- (ex: "(ID)D") e devolve o tipo de retorno correto
genExpr c tg tl ti (Chamada nome args) =   do
                                        -- gerar codigo de cada argumento
                                        args' <- mapM (genExpr c tg tl ti) args
                                        let argsCode = concatMap snd args'
                                        -- pega o header da função (tipos dos parâmetros + tipo do retorno)
                                        let (tiposParams, tipoRet) = case Map.lookup nome tg of
                                                                          Just info -> info
                                                                          Nothing -> ([], TInt) -- fallback, não deve acontecer após semântica
                                        let descritor = "(" ++ concatMap tipoJVM tiposParams ++ ")" ++ tipoJVM tipoRet
                                        -- instrucao invokestatic
                                        -- retorna algo do tipo: codigos dos argumentos + \tinvokestatic NomeDaClasse/NomeDaFuncao(II)V\n
                                        return (tipoRet, argsCode ++ "\tinvokestatic " ++ c ++ "/" ++ nome ++ descritor ++ "\n")

genExprR :: String -> TabelaGlobal -> TabelaLocal -> TabelaIndices -> String -> String -> ExprR -> State Int String
--                                                                     lv        lf
genRel :: Tipo -> String -> String -> String
genRel TInt    op lv = "\tif_icmp" ++ op ++ " " ++ lv ++ "\n"
genRel TDouble op lv = "\tdcmpg\n\tifgt " ++ lv ++ "\n" -- simplificado
genRel _       op lv = "\tif_icmp" ++ op ++ " " ++ lv ++ "\n"

genExprR c tg tl ti lv lf (Rlt e1 e2) =    do
                                        (t1, e1') <- genExpr c tg tl ti e1
                                        (t2, e2') <- genExpr c tg tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "lt" lv ++ "\tgoto " ++ lf ++ "\n")

genExprR c tg tl ti lv lf (Rgt e1 e2) =    do
                                        (t1, e1') <- genExpr c tg tl ti e1
                                        (t2, e2') <- genExpr c tg tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "gt" lv ++ "\tgoto " ++ lf ++ "\n")

genExprR c tg tl ti lv lf (Rle e1 e2) =    do
                                        (t1, e1') <- genExpr c tg tl ti e1
                                        (t2, e2') <- genExpr c tg tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "le" lv ++ "\tgoto " ++ lf ++ "\n")

genExprR c tg tl ti lv lf (Rge e1 e2) =    do
                                        (t1, e1') <- genExpr c tg tl ti e1
                                        (t2, e2') <- genExpr c tg tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "ge" lv ++ "\tgoto " ++ lf ++ "\n")

genExprR c tg tl ti lv lf (Req e1 e2) =    do
                                        (t1, e1') <- genExpr c tg tl ti e1
                                        (t2, e2') <- genExpr c tg tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "eq" lv ++ "\tgoto " ++ lf ++ "\n")

genExprR c tg tl ti lv lf (Rdif e1 e2) =   do
                                        (t1, e1') <- genExpr c tg tl ti e1
                                        (t2, e2') <- genExpr c tg tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "ne" lv ++ "\tgoto " ++ lf ++ "\n")

genExprL :: String -> TabelaGlobal -> TabelaLocal -> TabelaIndices -> String -> String -> ExprL -> State Int String
--                                                    lv        lf
genExprL c tg tl ti lv lf (And e1 e2) =    do
                                        l1 <- novoLabel
                                        e1' <- genExprL c tg tl ti l1 lf e1
                                        e2' <- genExprL c tg tl ti lv lf e2
                                        return (e1' ++ l1 ++ ":\n" ++ e2')

genExprL c tg tl ti lv lf (Or e1 e2) = do
                                    l1  <- novoLabel
                                    e1' <- genExprL c tg tl ti lv l1 e1  -- se e1 verdadeiro -> lv direto, falso -> l1
                                    e2' <- genExprL c tg tl ti lv lf e2  -- se e2 verdadeiro -> lv, falso -> lf
                                    return (e1' ++ l1 ++ ":\n" ++ e2')

genExprL c tg tl ti lv lf (Not e) =    do
                                    e' <- genExprL c tg tl ti lf lv e
                                    return e'

genExprL c tg tl ti lv lf (Rel exprR) = genExprR c tg tl ti lv lf exprR

genCmd :: String -> TabelaGlobal -> TabelaLocal -> TabelaIndices -> Comando -> State Int String
genCmd c tg tl ti (Atrib nome e) = do
                                (t, e') <- genExpr c tg tl ti e
                                let idx = case Map.lookup nome ti of
                                              Just i  -> i
                                              Nothing -> 0
                                let instr = case t of
                                                TInt    -> "\tistore "
                                                TDouble -> "\tdstore "
                                                _       -> "\tastore "
                                return (e' ++ instr ++ show idx ++ "\n")

genCmd c tg tl ti (Imp e) = do
                         (t, e') <- genExpr c tg tl ti e
                         let printMethod = case t of
                                             TInt    -> "\tinvokevirtual java/io/PrintStream/print(I)V\n"
                                             TDouble -> "\tinvokevirtual java/io/PrintStream/print(D)V\n"
                                             _       -> "\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n"
                         return ("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n" ++ e' ++ printMethod)

-- BEM feio essa função do read, mas basicamente ela vai configurar o Scanner (até a parte do invokespecial ali), e depois requisitar a linha pro usuário no invokevirtual
-- A gente usa java.util.Scanner (novo objeto a cada leitura, pra manter simples) lendo de System.in,
-- escolhendo o método de leitura (nextInt/nextDouble/nextLine) de acordo com o tipo da variável,
-- e guardando o valor lido na variável com istore/dstore/astore (igual já é feito em Atrib).
genCmd c tg tl ti (Leitura nome) = do
                                   -- pego o tipo e o index da variável
                                   let tipo = getTipoVar tl nome
                                   let idx = case Map.lookup nome ti of
                                                 Just i  -> i
                                                 Nothing -> 0
                                   let (metodo, retornoMetodo, instr) = case tipo of
                                                                          TInt    -> ("nextInt",    "I",                 "\tistore ")
                                                                          TDouble -> ("nextDouble", "D",                 "\tdstore ")
                                                                          _       -> ("nextLine",   "Ljava/lang/String;", "\tastore ")

                                   return ("\tnew java/util/Scanner\n" ++ "\tdup\n" ++ "\tgetstatic java/lang/System/in Ljava/io/InputStream;\n" 
                                           ++ "\tinvokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n" ++ "\tinvokevirtual java/util/Scanner/" 
                                           ++ metodo ++ "()" ++ retornoMetodo ++ "\n" ++ instr ++ show idx ++ "\n")

genCmd c tg tl ti (Ret Nothing) = return "\treturn\n"

genCmd c tg tl ti (Ret (Just e)) = do
                                (t, e') <- genExpr c tg tl ti e
                                let instr = case t of
                                                TInt    -> "\tireturn\n"
                                                TDouble -> "\tdreturn\n"
                                                _       -> "\tareturn\n"
                                return (e' ++ instr)

-- Literalmente mesma lógica do Chamada em genExpr, mas, se a função não for void, 
-- o valor devolvido fica sobrando na pilha e precisa ser descartado com pop (int/string) 
-- ou pop2 (double, que ocupa duas posições na pilha).
genCmd c tg tl ti (Proc nome args) = do
                                  args' <- mapM (genExpr c tg tl ti) args
                                  let argsCode = concatMap snd args'
                                  let (tiposParams, tipoRet) = case Map.lookup nome tg of
                                                                   Just info -> info
                                                                   Nothing   -> ([], TInt) -- fallback, não deve ocorrer depois da semântica
                                  let descritor = "(" ++ concatMap tipoJVM tiposParams ++ ")" ++ tipoJVM tipoRet
                                  let descarte = case tipoRet of 
                                                     TVoid   -> ""
                                                     TDouble -> "\tpop2\n"
                                                     _       -> "\tpop\n"
                                  return (argsCode ++ "\tinvokestatic " ++ c ++ "/" ++ nome ++ descritor ++ "\n" ++ descarte)

genCmd c tg tl ti (While exprL bloco) = do
                                     li <- novoLabel
                                     lv <- novoLabel
                                     lf <- novoLabel
                                     e'  <- genExprL c tg tl ti lv lf exprL
                                     b'  <- genBloco c tg tl ti bloco
                                     return (li ++ ":\n" ++ e' ++ lv ++ ":\n" ++ b' ++ "\tgoto " ++ li ++ "\n" ++ lf ++ ":\n")

genCmd c tg tl ti (If exprL b1 b2) = do
                                  lv  <- novoLabel
                                  lf  <- novoLabel
                                  lf2 <- novoLabel
                                  e'  <- genExprL c tg tl ti lv lf exprL
                                  b1' <- genBloco c tg tl ti b1
                                  b2' <- genBloco c tg tl ti b2
                                  return (e' ++ lv ++ ":\n" ++ b1' ++ "\tgoto " ++ lf2 ++ "\n" ++ lf ++ ":\n" ++ b2' ++ lf2 ++ ":\n")

genBloco :: String -> TabelaGlobal -> TabelaLocal -> TabelaIndices -> Bloco -> State Int String
genBloco c tg tl ti bloco = do
                         cmds <- mapM (genCmd c tg tl ti) bloco
                         return (concat cmds)

-- Gera o código Jasmin de uma função (nome, parâmetros + variáveis locais já juntos, corpo).
-- Monta a TabelaLocal (tipos) e a TabelaIndices (posições) a partir das variáveis da função,
-- pega o descritor da própria função na tabela global e gera o .method.
-- Assim como genMainFim sempre acrescenta "return" ao final da main, aqui, se a função for void,
-- eu coloco um "return" ao final (para o caso de o código não terminar com um "return;" explícito).

genFuncao :: String -> TabelaGlobal -> (Id, [Var], Bloco) -> State Int String
genFuncao c tg (nome, vars, bloco) = do
                                   let tl = constroiTabelaLocal vars
                                   let ti = constroiTabelaIndices vars
                                   let (tiposParams, tipoRet) = case Map.lookup nome tg of
                                                                    Just info -> info
                                                                    Nothing   -> ([], TVoid) -- fallback, não ocorre depois do semântico
                                   let descritor = "(" ++ concatMap tipoJVM tiposParams ++ ")" ++ tipoJVM tipoRet
                                   corpo <- genBloco c tg tl ti bloco
                                   -- Nesse caso, eu acabo gerando dois returns se a função é Void, mas isso não gera problema
                                   -- Isso é só pra garantir que, mesmo sem o return no .j--, não dê problema
                                   let retFinal = if tipoRet == TVoid then "\treturn\n" else ""
                                   -- Limit stack eu só coloquei um valor relativamente alto
                                   return (".method public static " ++ nome ++ descritor ++ "\n\t.limit stack 35" ++ "\n\t.limit locals " ++ show (numLimitLocals vars) ++
                                           "\n\n" ++ corpo ++ retFinal ++ ".end method\n\n")

-- Gera o código Jasmin do bloco principal (main), reaproveitando genMainCab/genMainFim

genMain :: String -> TabelaGlobal -> [Var] -> Bloco -> State Int String
genMain c tg vars bloco = do
                          let tl = constroiTabelaLocal vars
                          let ti = constroiTabelaIndices vars
                          -- Novamente, limit stack só coloquei um valor alto
                          cab <- genMainCab 60 (numLimitLocals vars)
                          corpo <- genBloco c tg tl ti bloco
                          fim <- genMainFim
                          return (cab ++ corpo ++ fim)

-- Gera o código Jasmin do programa inteiro: cabeçalho da classe, depois cada função
-- declarada, e por fim o bloco principal (main).
genProg :: String -> Programa -> State Int String
genProg nome (Prog funcoes corpoFuncoes mainVars corpoMain) = do
                                                              let tg = constroiTabelaGlobal funcoes
                                                              cab <- genCab nome
                                                              funcsCode <- mapM (genFuncao nome tg) corpoFuncoes
                                                              mainCode <- genMain nome tg mainVars corpoMain
                                                              return (cab ++ concat funcsCode ++ mainCode)

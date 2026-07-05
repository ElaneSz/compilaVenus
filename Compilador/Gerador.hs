module Gerador where

import Control.Monad.State
import AST
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

-- gerar :: String -> Programa -> String
-- gerar nome p = fst $ runState (genProg nome p) 0

-- [precisa de uma tabela que mapeie nome -> índice] vai precisar dessa tabela para gerar os iload/dload
type TabelaIndices = Map Id Int

constroiTabelaIndices :: [Var] -> TabelaIndices
constroiTabelaIndices vars =    Map.fromList (zip (map getNome vars) [0..])
                                where getNome (nome :#: _) = nome

-- [função para pegar o tipo de uma variavel pelo nome] -> vamos precisar dela em genExpr para saber se usa iload ou dload
getTipoVar :: TabelaLocal -> Id -> Tipo
getTipoVar tl nome = case Map.lookup nome tl of
                        Just t  -> t
                        Nothing -> TInt -- fallback, nao deve ocorrer apos semantica

genExpr :: String -> TabelaLocal -> TabelaIndices -> Expr -> State Int (Tipo, String)

genInt :: Int -> String
genInt  i
        | i >= -1 && i <= 5  = "\ticonst_" ++ show i ++ "\n"
        | i >= -128 && i <= 127   = "\tbipush " ++ show i ++ "\n"
        | i >= -32768 && i <= 32767 = "\tsipush " ++ show i ++ "\n"
        | otherwise = "\tldc " ++ show i ++ "\n"

genDouble :: Double -> String
genDouble d = "\tldc2_w " ++ show d ++ "\n"

-- Constante inteira
genExpr c tl ti (Const (CInt n))    = return (TInt, genInt n)

-- Constante double
genExpr c tl ti (Const (CDouble d)) = return (TDouble, genDouble d)

-- String literal
genExpr c tl ti (Lit s) = return (TString, "\tldc \"" ++ s ++ "\"\n")

-- Variavel
genExpr c tl ti (IdVar nome) =    let tipo = getTipoVar tl nome
                                    idx  = case Map.lookup nome ti of
                                               Just i  -> i
                                               Nothing -> 0
                                    instr = case tipo of
                                                TInt    -> "\tiload " -- Para int
                                                TDouble -> "\tdload " -- Para double
                                                _       -> "\taload " -- Para string
                                in return (tipo, instr ++ show idx ++ "\n")

genOp :: Tipo -> String -> String
genOp TInt    op = "\ti" ++ op ++ "\n"
genOp TDouble op = "\td" ++ op ++ "\n"
genOp _       op = "\ti" ++ op ++ "\n"

genExpr c tl ti (Add e1 e2) =   do
                                (t1, e1') <- genExpr c tl ti e1
                                (t2, e2') <- genExpr c tl ti e2
                                return (t1, e1' ++ e2' ++ genOp t1 "add")

genExpr c tl ti (Sub e1 e2) =   do
                                (t1, e1') <- genExpr c tl ti e1
                                (t2, e2') <- genExpr c tl ti e2
                                return (t1, e1' ++ e2' ++ genOp t1 "sub")

genExpr c tl ti (Mul e1 e2) =   do
                                (t1, e1') <- genExpr c tl ti e1
                                (t2, e2') <- genExpr c tl ti e2
                                return (t1, e1' ++ e2' ++ genOp t1 "mul")

genExpr c tl ti (Div e1 e2) =   do
                                (t1, e1') <- genExpr c tl ti e1
                                (t2, e2') <- genExpr c tl ti e2
                                return (t1, e1' ++ e2' ++ genOp t1 "div")

genExpr c tl ti (IntDouble e) = do
                                (_, e') <- genExpr c tl ti e
                                return (TDouble, e' ++ "\ti2d\n")

genExpr c tl ti (DoubleInt e) = do
                                (_, e') <- genExpr c tl ti e
                                return (TInt, e' ++ "\td2i\n")

genExpr c tl ti (Neg e) =   do
                            (t, e') <- genExpr c tl ti e
                            return (t, e' ++ genOp t "neg")

genExpr c tl ti (Chamada nome args) =   do
                                        -- gerar codigo de cada argumento
                                        args' <- mapM (genExpr c tl ti) args
                                        let argsCode = concatMap snd args'
                                        -- instrucao invokestatic
                                        -- por enquanto deixei como placeholder... completar quando chegarmos em genProg ^_^
                                        return (TInt, argsCode ++ "\tinvokestatic TODO\n")

genExprR :: String -> TabelaLocal -> TabelaIndices -> String -> String -> ExprR -> State Int String
--                                                    lv        lf
genRel :: Tipo -> String -> String -> String
genRel TInt    op lv = "\tif_icmp" ++ op ++ " " ++ lv ++ "\n"
genRel TDouble op lv = "\tdcmpg\n\tifgt " ++ lv ++ "\n" -- simplificado
genRel _       op lv = "\tif_icmp" ++ op ++ " " ++ lv ++ "\n"

genExprR c tl ti lv lf (Rlt e1 e2) =    do
                                        (t1, e1') <- genExpr c tl ti e1
                                        (t2, e2') <- genExpr c tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "lt" lv ++ "\tgoto " ++ lf ++ "\n")

genExprR c tl ti lv lf (Rgt e1 e2) =    do
                                        (t1, e1') <- genExpr c tl ti e1
                                        (t2, e2') <- genExpr c tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "gt" lv ++ "\tgoto " ++ lf ++ "\n")

genExprR c tl ti lv lf (Rle e1 e2) =    do
                                        (t1, e1') <- genExpr c tl ti e1
                                        (t2, e2') <- genExpr c tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "le" lv ++ "\tgoto " ++ lf ++ "\n")

genExprR c tl ti lv lf (Rge e1 e2) =    do
                                        (t1, e1') <- genExpr c tl ti e1
                                        (t2, e2') <- genExpr c tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "ge" lv ++ "\tgoto " ++ lf ++ "\n")

genExprR c tl ti lv lf (Req e1 e2) =    do
                                        (t1, e1') <- genExpr c tl ti e1
                                        (t2, e2') <- genExpr c tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "eq" lv ++ "\tgoto " ++ lf ++ "\n")

genExprR c tl ti lv lf (Rdif e1 e2) =   do
                                        (t1, e1') <- genExpr c tl ti e1
                                        (t2, e2') <- genExpr c tl ti e2
                                        return (e1' ++ e2' ++ genRel t1 "ne" lv ++ "\tgoto " ++ lf ++ "\n")

genExprL :: String -> TabelaLocal -> TabelaIndices -> String -> String -> ExprL -> State Int String
--                                                    lv        lf
genExprL c tl ti lv lf (And e1 e2) =    do
                                        l1 <- novoLabel
                                        e1' <- genExprL c tl ti l1 lf e1
                                        e2' <- genExprL c tl ti lv lf e2
                                        return (e1' ++ l1 ++ ":\n" ++ e2')

genExprL c tl ti lv lf (Or e1 e2) = do
                                    l1  <- novoLabel
                                    e1' <- genExprL c tl ti lv l1 e1  -- se e1 verdadeiro -> lv direto, falso -> l1
                                    e2' <- genExprL c tl ti lv lf e2  -- se e2 verdadeiro -> lv, falso -> lf
                                    return (e1' ++ l1 ++ ":\n" ++ e2')

genExprL c tl ti lv lf (Not e) =    do
                                    e' <- genExprL c tl ti lf lv e
                                    return e'

genExprL c tl ti lv lf (Rel exprR) = genExprR c tl ti lv lf exprR

genCmd :: String -> TabelaLocal -> TabelaIndices -> Comando -> State Int String
genCmd c tl ti (Atrib nome e) = do
                                (t, e') <- genExpr c tl ti e
                                let idx = case Map.lookup nome ti of
                                              Just i  -> i
                                              Nothing -> 0
                                let instr = case t of
                                                TInt    -> "\tistore "
                                                TDouble -> "\tdstore "
                                                _       -> "\tastore "
                                return (e' ++ instr ++ show idx ++ "\n")

genCmd c tl ti (Imp e) = do
                         (t, e') <- genExpr c tl ti e
                         let printMethod = case t of
                                             TInt    -> "\tinvokevirtual java/io/PrintStream/print(I)V\n"
                                             TDouble -> "\tinvokevirtual java/io/PrintStream/print(D)V\n"
                                             _       -> "\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n"
                         return ("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n" ++ e' ++ printMethod)

genCmd c tl ti (Ret Nothing) = return "\treturn\n"

genCmd c tl ti (Ret (Just e)) = do
                                (t, e') <- genExpr c tl ti e
                                let instr = case t of
                                                TInt    -> "\tireturn\n"
                                                TDouble -> "\tdreturn\n"
                                                _       -> "\tareturn\n"
                                return (e' ++ instr)

genCmd c tl ti (Proc nome args) = do
                                  args' <- mapM (genExpr c tl ti) args
                                  let argsCode = concatMap snd args'
                                  return (argsCode ++ "\tinvokestatic TODO\n")

genCmd c tl ti (While exprL bloco) = do
                                     li <- novoLabel
                                     lv <- novoLabel
                                     lf <- novoLabel
                                     e'  <- genExprL c tl ti lv lf exprL
                                     b'  <- genBloco c tl ti bloco
                                     return (li ++ ":\n" ++ e' ++ lv ++ ":\n" ++ b' ++ "\tgoto " ++ li ++ "\n" ++ lf ++ ":\n")

genCmd c tl ti (If exprL b1 b2) = do
                                  lv  <- novoLabel
                                  lf  <- novoLabel
                                  lf2 <- novoLabel
                                  e'  <- genExprL c tl ti lv lf exprL
                                  b1' <- genBloco c tl ti b1
                                  b2' <- genBloco c tl ti b2
                                  return (e' ++ lv ++ ":\n" ++ b1' ++ "\tgoto " ++ lf2 ++ "\n" ++ lf ++ ":\n" ++ b2' ++ lf2 ++ ":\n")

genBloco :: String -> TabelaLocal -> TabelaIndices -> Bloco -> State Int String
genBloco c tl ti bloco = do
                         cmds <- mapM (genCmd c tl ti) bloco
                         return (concat cmds)


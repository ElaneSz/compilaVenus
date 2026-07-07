module Semantico where

import Data.Map (Map)
import qualified Data.Map as Map
import AST

data Result a = Result (Bool, String, a) deriving Show

instance Functor Result where
  fmap f (Result (b, s, a)) = Result (b, s, f a)

instance Applicative Result where
  pure a = Result (False, "", a)
  Result (b1, s1, f) <*> Result (b2, s2, x) = Result (b1 || b2, s1 <> s2, f x)   

instance Monad Result where 
--  return a = Result (False, "", a)
  Result (b, s, a) >>= f = let Result (b', s', a') = f a in Result (b || b', s++s', a')
  
errorMsg s = Result (True, "Erro:"++s++"\n", ())

warningMsg s = Result (False, "Advertencia:"++s++"\n", ())







-- Tabela global: nome da função -> ([tipos dos parâmetros], tipo de retorno)
type TabelaGlobal = Map Id ([Tipo], Tipo)

-- Tabela local: nome da variável -> tipo
type TabelaLocal = Map Id Tipo

getTipo :: Var -> Tipo
getTipo (_ :#: (t, _)) = t

insereFunc :: Funcao -> TabelaGlobal -> Result TabelaGlobal
insereFunc (nome :->: (vars, ret)) tab =    if Map.member nome tab
                                            then do
                                                errorMsg (" Funcao ja declarada: " ++ nome)
                                                return tab
                                            else return (Map.insert nome (map getTipo vars, ret) tab)

constroiTabelaGlobal :: [Funcao] -> Result TabelaGlobal
constroiTabelaGlobal [] = return Map.empty
constroiTabelaGlobal (f:fs) =   do
                                tab <- constroiTabelaGlobal fs
                                insereFunc f tab

insereVar :: Var -> TabelaLocal -> Result TabelaLocal
insereVar (nome :#: (tipo, _)) tab =    if Map.member nome tab
                                        then do
                                            errorMsg (" Variavel ja declarada: " ++ nome)
                                            return tab
                                        else return (Map.insert nome tipo tab)

constroiTabelaLocal :: [Var] -> Result TabelaLocal
constroiTabelaLocal [] = return Map.empty
constroiTabelaLocal (x:xs) =  do
                              tab <- constroiTabelaLocal xs
                              insereVar x tab

-- Verifica se um bloco garante um "return" em todo caminho de execução.
-- Só olho o último comando do bloco (o resto antes dele não importa pra essa garantia),
-- e no caso de um If, exige que os DOIS ramos (if e else) garantam retorno 
-- já que um if sem "else" vira If _ _ [], e blocoRetorna [] = False cobre exatamente esse caso.
    
-- Do while também entra nesse caso, já que ele vai obrigatóriamente executar ao menos uma vez
blocoRetorna :: Bloco -> Bool
blocoRetorna [] = False
blocoRetorna cmds = comandoRetorna (last cmds)

comandoRetorna :: Comando -> Bool
comandoRetorna (Ret _)      = True
comandoRetorna (If _ b1 b2) = blocoRetorna b1 && blocoRetorna b2
comandoRetorna (DoWhile b _) = blocoRetorna b
comandoRetorna _            = False

verificaExpr :: TabelaGlobal -> TabelaLocal -> Expr -> Result (Expr, Tipo)
verificaExpr tg tl (Const (CInt n))    = return (Const (CInt n), TInt)
verificaExpr tg tl (Const (CDouble d)) = return (Const (CDouble d), TDouble)
verificaExpr tg tl (Lit s)             = return (Lit s, TString)
verificaExpr tg tl (IdVar nome) =   case Map.lookup nome tl of
                                        Just tipo -> return (IdVar nome, tipo)
                                        Nothing   -> do
                                            errorMsg (" Variavel nao declarada: " ++ nome)
                                            return (IdVar nome, TInt)  -- tipo dummy para continuar
verificaExpr tg tl (Add e1 e2) =    do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)        -> return (Add e1' e2', TInt)
                                        (TInt, TDouble)     -> return (Add (IntDouble e1') e2', TDouble)
                                        (TDouble, TInt)     -> return (Add e1' (IntDouble e2'), TDouble)
                                        (TDouble, TDouble)  -> return (Add e1' e2', TDouble)
                                        _                   ->  do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
                                                                errorMsg (" Tipos incompativeis em adicao: " ++ show e1' ++ " + " ++ show e2')
                                                                return (Add e1' e2', TInt)
verificaExpr tg tl (Sub e1 e2) =    do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)        -> return (Sub e1' e2', TInt)
                                        (TInt, TDouble)     -> return (Sub (IntDouble e1') e2', TDouble)
                                        (TDouble, TInt)     -> return (Sub e1' (IntDouble e2'), TDouble)
                                        (TDouble, TDouble)  -> return (Sub e1' e2', TDouble)
                                        _                   ->  do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
                                                                errorMsg (" Tipos incompativeis em subtracao: " ++ show e1' ++ " - " ++ show e2')
                                                                return (Sub e1' e2', TInt)
verificaExpr tg tl (Mul e1 e2) =    do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)        -> return (Mul e1' e2', TInt)
                                        (TInt, TDouble)     -> return (Mul (IntDouble e1') e2', TDouble)
                                        (TDouble, TInt)     -> return (Mul e1' (IntDouble e2'), TDouble)
                                        (TDouble, TDouble)  -> return (Mul e1' e2', TDouble)
                                        _                   ->  do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
                                                                errorMsg (" Tipos incompativeis em multiplicacao: " ++ show e1' ++ " * " ++ show e2')
                                                                return (Mul e1' e2', TInt)
verificaExpr tg tl (Div e1 e2) =    do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)        -> return (Div e1' e2', TInt)
                                        (TInt, TDouble)     -> return (Div (IntDouble e1') e2', TDouble)
                                        (TDouble, TInt)     -> return (Div e1' (IntDouble e2'), TDouble)
                                        (TDouble, TDouble)  -> return (Div e1' e2', TDouble)
                                        _                   ->  do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
                                                                errorMsg (" Tipos incompativeis em divisao: " ++ show e1' ++ " / " ++ show e2')
                                                                return (Div e1' e2', TInt)
verificaExpr tg tl (Neg e) =    do
                                (e', t) <- verificaExpr tg tl e
                                case t of
                                    TInt    -> return (Neg e', TInt)
                                    TDouble -> return (Neg e', TDouble)
                                    _       -> do -- ele casa com qualquer valor que não foi coberto pelos casos anteriores
                                        errorMsg (" Tipos incompativel em negacao: " ++ show e')
                                        return (Neg e', TInt)

verificaExpr tg tl (Chamada nome args) =    case Map.lookup nome tg of
                                                Nothing -> do
                                                    errorMsg (" Funcao nao declarada: " ++ nome)
                                                    return (Chamada nome args, TInt)
                                                Just (tiposParams, tipoRet) -> do
                                                    resultArgs <- mapM (verificaExpr tg tl) args
                                                    let args'     = map fst resultArgs
                                                    let tiposArgs = map snd resultArgs
                                                    -- 1. número de argumentos
                                                    if length tiposArgs /= length tiposParams
                                                        then errorMsg (" Numero de parametros errado: " ++ nome)
                                                    else return ()
                                                    -- 2. tipos dos argumentos
                                                    args'' <- mapM (\(e, tp, ta) -> coerceArg e tp ta) (zip3 args' tiposParams tiposArgs) -- zip3 | para ter (expressão, tipoParam, tipoArg) juntos.
                                                    return (Chamada nome args'', tipoRet)

coerceArg :: Expr -> Tipo -> Tipo -> Result Expr
coerceArg e tipoParam tipoArg = case (tipoParam, tipoArg) of
                                    (TInt, TInt)       -> return e
                                    (TDouble, TDouble) -> return e
                                    (TString, TString) -> return e
                                    (TDouble, TInt)    -> return (IntDouble e) -- converte silenciosamente
                                    (TInt, TDouble)    -> do                   -- converte com advertência
                                        warningMsg (" Conversao de double para int em parametro: " ++ show e)
                                        return (DoubleInt e)
                                    _ -> do
                                        errorMsg " Tipo de parametro incompativel"
                                        return e

verificaExprR :: TabelaGlobal -> TabelaLocal -> ExprR -> Result ExprR
verificaExprR tg tl (Rlt e1 e2) =   do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)       -> return (Rlt e1' e2')
                                        (TInt, TDouble)    -> return (Rlt (IntDouble e1') e2')
                                        (TDouble, TInt)    -> return (Rlt e1' (IntDouble e2'))
                                        (TDouble, TDouble) -> return (Rlt e1' e2')
                                        (TString, TString) -> return (Rlt e1' e2')
                                        _ -> do
                                            errorMsg (" Tipos incompativeis em expressao relacional: " ++ show e1' ++ " < " ++ show e2')
                                            return (Rlt e1' e2')

verificaExprR tg tl (Rgt e1 e2) =   do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)       -> return (Rgt e1' e2')
                                        (TInt, TDouble)    -> return (Rgt (IntDouble e1') e2')
                                        (TDouble, TInt)    -> return (Rgt e1' (IntDouble e2'))
                                        (TDouble, TDouble) -> return (Rgt e1' e2')
                                        (TString, TString) -> return (Rgt e1' e2')
                                        _ -> do
                                            errorMsg (" Tipos incompativeis em expressao relacional: " ++ show e1' ++ " > " ++ show e2')
                                            return (Rgt e1' e2')

verificaExprR tg tl (Rle e1 e2) =   do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)       -> return (Rle e1' e2')
                                        (TInt, TDouble)    -> return (Rle (IntDouble e1') e2')
                                        (TDouble, TInt)    -> return (Rle e1' (IntDouble e2'))
                                        (TDouble, TDouble) -> return (Rle e1' e2')
                                        (TString, TString) -> return (Rle e1' e2')
                                        _ -> do
                                            errorMsg (" Tipos incompativeis em expressao relacional: " ++ show e1' ++ " <= " ++ show e2')
                                            return (Rle e1' e2')

verificaExprR tg tl (Rge e1 e2) =   do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)       -> return (Rge e1' e2')
                                        (TInt, TDouble)    -> return (Rge (IntDouble e1') e2')
                                        (TDouble, TInt)    -> return (Rge e1' (IntDouble e2'))
                                        (TDouble, TDouble) -> return (Rge e1' e2')
                                        (TString, TString) -> return (Rge e1' e2')
                                        _ -> do
                                            errorMsg (" Tipos incompativeis em expressao relacional: " ++ show e1' ++ " >= " ++ show e2')
                                            return (Rge e1' e2')

verificaExprR tg tl (Req e1 e2) =   do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)       -> return (Req e1' e2')
                                        (TInt, TDouble)    -> return (Req (IntDouble e1') e2')
                                        (TDouble, TInt)    -> return (Req e1' (IntDouble e2'))
                                        (TDouble, TDouble) -> return (Req e1' e2')
                                        (TString, TString) -> return (Req e1' e2')
                                        _ -> do
                                            errorMsg (" Tipos incompativeis em expressao relacional: " ++ show e1' ++ " == " ++ show e2')
                                            return (Req e1' e2')

verificaExprR tg tl (Rdif e1 e2) =   do
                                    (e1', t1) <- verificaExpr tg tl e1
                                    (e2', t2) <- verificaExpr tg tl e2
                                    case (t1, t2) of
                                        (TInt, TInt)       -> return (Rdif e1' e2')
                                        (TInt, TDouble)    -> return (Rdif (IntDouble e1') e2')
                                        (TDouble, TInt)    -> return (Rdif e1' (IntDouble e2'))
                                        (TDouble, TDouble) -> return (Rdif e1' e2')
                                        (TString, TString) -> return (Rdif e1' e2')
                                        _ -> do
                                            errorMsg (" Tipos incompativeis em expressao relacional: " ++ show e1' ++ " /= " ++ show e2')
                                            return (Rdif e1' e2')

verificaExprL :: TabelaGlobal -> TabelaLocal -> ExprL -> Result ExprL
-- And, Or -> verificam os dois lados recursivamente
-- Not -> verifica o único operando recursivamente
-- Rel -> chama verificaExprR
verificaExprL tg tl (And e1 e2) =   do
                                    e1' <- verificaExprL tg tl e1
                                    e2' <- verificaExprL tg tl e2
                                    return (And e1' e2')

verificaExprL tg tl (Or e1 e2) =    do
                                    e1' <- verificaExprL tg tl e1
                                    e2' <- verificaExprL tg tl e2
                                    return (Or e1' e2')

verificaExprL tg tl (Not e) =   do
                                e' <- verificaExprL tg tl e
                                return (Not e')

verificaExprL tg tl (Rel exprR) =   do
                                    exprR' <- verificaExprR tg tl exprR
                                    return (Rel exprR')

verificaComando :: TabelaGlobal -> TabelaLocal -> Tipo -> Comando -> Result Comando
-- O Tipo extra é o tipo de retorno da função atual, necessário para verificar Ret

verificaComando tg tl tr (If exprL b1 b2) = do
                                            exprL' <- verificaExprL tg tl exprL
                                            b1'    <- mapM (verificaComando tg tl tr) b1
                                            b2'    <- mapM (verificaComando tg tl tr) b2
                                            return (If exprL' b1' b2')

verificaComando tg tl tr (While exprL b) = do
                                            exprL' <- verificaExprL tg tl exprL
                                            b'    <- mapM (verificaComando tg tl tr) b
                                            return (While exprL' b')

--Essencialmente a mesma coisa que o while

verificaComando tg tl tr (DoWhile b exprL) =   do
                                                b'     <- mapM (verificaComando tg tl tr) b
                                                exprL' <- verificaExprL tg tl exprL
                                                return (DoWhile b' exprL')

verificaComando tg tl tr (Atrib nome e) =   do
                                            case Map.lookup nome tl of
                                                Nothing -> do
                                                    errorMsg (" Variavel nao declarada: " ++ nome)
                                                    return (Atrib nome e)
                                                Just tipoVar -> do
                                                    (e', tipoExpr) <- verificaExpr tg tl e
                                                    case (tipoVar, tipoExpr) of -- parecido com o coerceArg
                                                        (TInt, TInt)       -> return (Atrib nome e')
                                                        (TDouble, TDouble) -> return (Atrib nome e')
                                                        (TString, TString) -> return (Atrib nome e')
                                                        (TDouble, TInt)    -> return (Atrib nome (IntDouble e'))
                                                        (TInt, TDouble)    ->   do
                                                                                warningMsg (" Conversao de double para int na atribuicao de " ++ nome ++ " = " ++ show e')
                                                                                return (Atrib nome (DoubleInt e'))
                                                        _ ->    do
                                                                errorMsg (" Tipos incompativeis na atribuicao de " ++ nome)
                                                                return (Atrib nome e')

verificaComando tg tl retorno (Leitura nomeVar) =   do
                                                    case Map.lookup nomeVar tl of
                                                        Nothing -> do
                                                            errorMsg (" Variavel nao declarada: " ++ nomeVar)
                                                            return (Leitura nomeVar)
                                                        Just _ -> return (Leitura nomeVar)

verificaComando tg tl tr (Imp e) =  do
                                    (e', _) <- verificaExpr tg tl e -- não precisamos do tipo dessa expressão (já que não precisamos fazer coerceArg)
                                    return (Imp e')

verificaComando _ _ tipoRetorno (Ret Nothing) =     do
                                                    case tipoRetorno of
                                                        TVoid -> return (Ret Nothing)
                                                        _     ->    do
                                                                    errorMsg (" Funcao de tipo " ++ show(tipoRetorno) ++ " retornando vazio")
                                                                    return (Ret Nothing)

verificaComando tg tl tr (Ret (Just e)) =   do
                                            (e', tipoExpr) <- verificaExpr tg tl e
                                            case (tr, tipoExpr) of
                                                (TVoid, _)         ->   do
                                                                        errorMsg (" Retornando algo em funcao de tipo void")
                                                                        return (Ret (Just e'))
                                                (TInt, TInt)       -> return (Ret (Just e'))
                                                (TDouble, TDouble) -> return (Ret (Just e'))
                                                (TString, TString) -> return (Ret (Just e'))
                                                (TDouble, TInt)    -> return (Ret (Just (IntDouble e')))
                                                (TInt, TDouble)    ->   do
                                                                        warningMsg (" Conversao de double para int no retorno: " ++ show e')
                                                                        return (Ret (Just (DoubleInt e')))
                                                _ ->    do
                                                        errorMsg (" Tipos incompativeis no retorno")
                                                        return (Ret (Just e'))

-- esse aqui eu fiquei meio confuso de como fazer :(
verificaComando tg tl retorno (Proc funcId args) =   do
                                                     (chamada', _) <- verificaExpr tg tl (Chamada funcId args)
                                                     case chamada' of
                                                        Chamada _ args' -> return (Proc funcId args')
                                                        _               -> return (Proc funcId args)

verificaFuncao :: TabelaGlobal -> (Id, [Var], Bloco) -> Result (Id, [Var], Bloco)
verificaFuncao tg (nomeFunc, vars, comandos) =   do
                                                 tl <- constroiTabelaLocal vars
                                                 let tipoRetorno = case Map.lookup nomeFunc tg of
                                                                    Just (_, retFuncao) -> retFuncao
                                                                    Nothing             -> TVoid
                                                 bloco' <- mapM (verificaComando tg tl tipoRetorno) comandos
                                                 if tipoRetorno /= TVoid && not (blocoRetorna bloco')
                                                    then do
                                                        errorMsg ("Funcao " ++ nomeFunc ++ " deveria retornar " ++ show tipoRetorno ++ " mas nem todo caminho de codigo garante um retorno.")
                                                        return (nomeFunc, vars, bloco')
                                                    else return (nomeFunc, vars, bloco')

verificaMain :: TabelaGlobal -> [Var] -> Bloco -> Result ([Var], Bloco)
verificaMain tg vars comandos =   do
                                  tl <- constroiTabelaLocal vars
                                  bloco' <- mapM (verificaComando tg tl TVoid) comandos
                                  return (vars, bloco')

verificaPrograma :: Programa -> Result Programa
verificaPrograma (Prog funcs corpoFuncs mainVars corpoMain) =   do
                                                                tg <- constroiTabelaGlobal funcs
                                                                corpoFuncs' <- mapM (verificaFuncao tg) corpoFuncs
                                                                (mainVars', corpoMain') <- verificaMain tg mainVars corpoMain
                                                                -- não sei se aqui muda alguma coisa eu usar o mainVars' ou só o mainVars
                                                                return (Prog funcs corpoFuncs' mainVars' corpoMain')


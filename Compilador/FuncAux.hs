module FuncAux where
import AST

-- Pega o Id da Função
geraIdFuncao :: Funcao -> Id
geraIdFuncao (x :->: (a, b)) = x 

-- Pega o retorno do ListaFuncoes e transforma no tipo que o contrutor Prog aceita
geraFuncaoCompleta :: [(Funcao,([Var], Bloco))] -> [(Id,[Var],Bloco)]
geraFuncaoCompleta (((x :->: (a, b)), (vars, bloco)) : xs) = (x, vars, bloco) : geraFuncaoCompleta xs
geraFuncaoCompleta [] = []

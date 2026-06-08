module Main where

import Lex (alexScanTokens)
import Parser (parser)
import Semantico (verificaPrograma, Result(..))

main :: IO ()
main = do
    input <- getContents
    let tokens = alexScanTokens input
    putStrLn "=== Tokens ==="
    mapM_ print tokens
    putStrLn "\n=== AST ==="
    let ast = parser tokens
    print ast
    putStrLn "\n=== Analise Semantica ==="
    let Result (temErro, msgs, ast') = verificaPrograma ast
    if msgs == ""
        then putStrLn "Sem erros ou advertencias"
        else putStrLn msgs
    if temErro
        then putStrLn "Compilacao falhou"
        else do
            putStrLn "Compilacao bem sucedida"
            putStrLn "\n=== AST Anotada ==="
            print ast'
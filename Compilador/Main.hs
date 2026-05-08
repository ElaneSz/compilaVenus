module Main where

import Lex (alexScanTokens)
import Parser (parser)

main :: IO ()
main = do
    input <- getContents
    let tokens = alexScanTokens input
    putStrLn "=== Tokens ==="
    mapM_ print tokens
    putStrLn "\n=== AST ==="
    let ast = parser tokens
    print ast
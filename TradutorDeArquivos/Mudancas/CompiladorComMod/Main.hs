module Main where

import Lex (alexScanTokens)
import Parser (parser)
import Semantico (verificaPrograma, Result(..))
import Gerador (gerar) -- Importa o gerador de código

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
        then putStrLn "Compilacao falhou devido a erros semanticos."
        else do
            putStrLn "Compilacao bem sucedida"
            putStrLn "\n=== AST Anotada ==="
            print ast'
            
            putStrLn "\n=== Geracao de Codigo ==="
            -- Define o nome da classe Java/Jasmin a ser gerada
            let nomeClasse = "Programa" 
            let codigoJasmin = gerar nomeClasse ast'
            
            -- Escreve o resultado em um arquivo .j
            let nomeArquivo = nomeClasse ++ ".j"
            writeFile nomeArquivo codigoJasmin
            putStrLn $ "Codigo Jasmin gerado com sucesso em: " ++ nomeArquivo
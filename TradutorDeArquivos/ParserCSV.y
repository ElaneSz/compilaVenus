{
module Main where

import TokenCSV
import JSON
import AST
import qualified LexCSV as L
}

%name parseCSV
%tokentype { Token }
%error { parseError }

%token
  newline  { NEWLINE }
  sep      { SEP }
  field    { FIELD $$ }

%%

CSV : Linha newline Registros newline  { ($1, $3) }
    | Linha newline Registros          { ($1, $3) }
    | Linha newline                    { ($1, []) }

Registros : Registros newline Linha  { $1 ++ [$3] }
           | Linha                   { [$1]        }

Linha : Linha sep field  { $1 ++ [$3] }
      | field            { [$1]       }

{
parseError :: [Token] -> a
parseError ts = error ("Erro sintatico nos tokens: " ++ show ts)

main :: IO ()
main = do
  contents <- getContents
  let tokens  = L.alexScanTokens contents
  let tokens' = filterTokens tokens
  let pair    = parseCSV tokens'
  let csv     = toCSV pair
  let result  = toJSON csv
  putStrLn result
  writeFile "saida.json" result
}

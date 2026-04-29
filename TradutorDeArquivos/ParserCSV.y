{
module Main where

import TokenCSV
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

type Cabecalho = [String]
type Registro  = [String]
data CSV       = CSV Cabecalho [Registro]

toCSV :: ([String], [[String]]) -> CSV
toCSV (cab, regs) = CSV cab regs

-- Remove tokens FIELD com valor vazio ou so espacos (gerados por espacos apos virgula)
filterTokens :: [Token] -> [Token]
filterTokens [] = []
-- FIELD vazio seguido de FIELD real: descarta o vazio
filterTokens (FIELD s : rest@(FIELD _ : _))
  | all (\c -> c == ' ' || c == '\t') s = filterTokens rest
filterTokens (t:ts) = t : filterTokens ts

escapeJSON :: String -> String
escapeJSON []         = []
escapeJSON ('"' :cs)  = '\\' : '"'  : escapeJSON cs
escapeJSON ('\\':cs)  = '\\' : '\\' : escapeJSON cs
escapeJSON ('\n':cs)  = '\\' : 'n'  : escapeJSON cs
escapeJSON (c   :cs)  = c            : escapeJSON cs

toJSON :: CSV -> String
toJSON (CSV cab regs) =
  "[\n" ++ intercalateStr ",\n" (map (recordToJSON cab) regs) ++ "\n]"

recordToJSON :: Cabecalho -> Registro -> String
recordToJSON keys values =
  "  {\n" ++
  intercalateStr ",\n" (zipWith fieldToJSON keys values) ++
  "\n  }"

fieldToJSON :: String -> String -> String
fieldToJSON k v =
  "    \"" ++ escapeJSON k ++ "\": \"" ++ escapeJSON v ++ "\""

intercalateStr :: String -> [String] -> String
intercalateStr _   []     = ""
intercalateStr _   [x]    = x
intercalateStr sep (x:xs) = x ++ sep ++ intercalateStr sep xs

main :: IO ()
main = do
  contents <- getContents
  let tokens  = L.alexScanTokens contents
  let tokens' = filterTokens tokens
  let pair    = parseCSV tokens'
  let csv     = toCSV pair
  putStrLn (toJSON csv)
}

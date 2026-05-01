module JSON where

import AST
import TokenCSV

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
escapeJSON (c   :cs)  = c           : escapeJSON cs

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
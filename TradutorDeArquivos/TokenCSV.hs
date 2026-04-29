module TokenCSV where

data Token
  = NEWLINE        -- '\n'
  | SEP            -- ','
  | FIELD String   -- conteúdo de um campo (com ou sem aspas)
  deriving (Eq, Show)
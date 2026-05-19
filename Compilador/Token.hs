module Token where

data Token
  -- Palavras reservadas
  = TKint | TKdouble | TKstring | TKvoid
  | TKif | TKelse | TKwhile | TKprint | TKreturn
  | TKread
  -- Operadores aritméticos
  | TKmais | TKmenos | TKmult | TKdiv
  -- Operadores relacionais
  | TKlt | TKgt | TKle | TKge | TKeq | TKdif -- < > <= >= == /=
  -- Operadores lógicos
  | TKand | TKor | TKnot
  -- Atribuição e pontuação
  | TKatrib | TKabreP | TKfechaP | TKabreC | TKfechaC
  | TKvirgula | TKponto_e_virgula
  -- Literais e identificador
  | TKid String
  | TKint_lit Int
  | TKdouble_lit Double
  | TKstring_lit String
  | TKEOF -- fim do arquivo
  deriving (Show, Eq)

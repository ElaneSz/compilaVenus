module AST where

type Cabecalho = [String]
type Registro  = [String]
data CSV       = CSV Cabecalho [Registro]

toCSV :: ([String], [[String]]) -> CSV
toCSV (cab, regs) = CSV cab regs
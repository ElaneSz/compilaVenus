{
module LexCSV where

import TokenCSV
}

%wrapper "basic"

tokens :-

\r\n      { \s -> NEWLINE }
\n        { \s -> NEWLINE }

\,        { \s -> SEP }

\" [^\"]* \"   { \s -> FIELD (init (tail s)) }

[^\,\"\n\r]+   { \s -> FIELD (trim s) }

{
trim :: String -> String
trim = f . f
  where f = reverse . dropWhile (\c -> c == ' ' || c == '\t')

testLex :: IO ()
testLex = do
  s <- getContents
  print (alexScanTokens s)
}

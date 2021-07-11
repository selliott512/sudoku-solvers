### main.jl

Applies backtracking to solve sudokus using a type of brute force exhaustive search.

### other/constraint-backtracking.jl

First constraints each of the 81 cells to the set of allowed values that cell. The constraining is done iteratively until no more constraints are found. Once the constraining is done, which by itself is sufficient for simple and medium difficulty sudokus, backtracking constrained to the allowed values for each cell is used. Additionally the backtracking is done so that the most constrained cells are considered first similar to how a human might solve a sudoku. This should be faster than "backtracking.jl", but in practice the additional complexity makes it slower in some cases.

### other/incomplete-algorithm-x.jl

A half written implementation of Algorithm X. Algorithm X uses exact cover to solve sudokus.

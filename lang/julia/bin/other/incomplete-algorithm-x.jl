#!/usr/bin/env julia

# SPDX-License-Identifier: BSD-3-Clause

# incomplete-algorithm-x.jl - Solve sudokus using algorithm-x.

# This file is not done, but it's a partial implementation of algorithm-x.

function get_constraint_matrix()
    cm = zeros(Bool, 9^3, 4*9^2)

    # Naming convention:
    #
    # prefix "m" - row or column into the constraint matrix.
    # prefix "r" - sudoku row or column from the constraint matrix row.
    # prefix "c" - sudoku row or column from the constraint matrix column.
    #
    # suffix "r" - "row". 1 based.
    # suffix "c" - "column". 1 based.

    # Row-Column Constraints.
    for mc = 1:84
        for mr = 1:729
            cr = mc ÷ 9 + 1
            cc = mc % 9 + 1

            rr = (mr ÷ 81) % 9 + 1
            rc = (mr ÷  9) % 9 + 1

            cr = mc ÷ 9 + 1
            cc = mc % 9 + 1

            cm[mr, mc] = (cr == rr) && (cc == rc)
        end
    end
    return cm
end

function get_constraint_matrix_rows(sud::Array{Int8,2})
    cm_rows = Int16[]
    for sr = 1:9
        for sc = 1:9
            sn = sud[sr, sc]
            if sn > 0
                #  R1C1#1 should be row 1, so 81 + 9 + 1 = 91 -> subtract 90.
                append!(cm_rows, sr * 81 + sc * 9 + sn - 90)
            end
        end
    end
    return cm_rows
end

function read_sudoku(path::String)
    sud = zeros(Int8, 9, 9)
    open(path, "r") do file
        line_num = 0
        for line in eachline(file)
            line_num += 1
            trim_line = replace(line, " " => "")
            if trim_line == ""
                continue
            end
            if length(trim_line) != 9
                error("Line #", line_num, " of \"", path,
                    "\" does not have 9 digts: \"", line, "\".")
            end
            trim_line = replace(trim_line, "." => "0")
            sud[line_num, :] = [parse(Int8, n) for n in trim_line]
        end
    end
    return sud
end

function usage()
    println("algorithm-x sudoku-path")
    println("algorithm-x -h")
end

# Main

cm = get_constraint_matrix()
if length(ARGS) == 0 || ARGS[1] == "-h"
    usage()
    exit(0)
end
sud = read_sudoku(ARGS[1])
cm_rows = get_constraint_matrix_rows(sud)
cm = remove_constraint_matrix_rows(cm, cm_rows)
println(cm_rows)

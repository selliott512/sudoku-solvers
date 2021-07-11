#!/usr/bin/env julia

# SPDX-License-Identifier: BSD-3-Clause

# backtracking.jl - Solve sudokus using backtracking.

# This is a simple brute force sudoku solver, but it's still quite fast in
# most cases.

# Get an array of booleans indicating the fixed values in a sudoku.
function sud_get_fixed(sud::Array{Int8,2})
    z = zeros(Bool, 9, 9)
    for i in eachindex(sud)
        if sud[i] > 0
            z[i] = true
        end
    end
    return z
end

# Return true if a sudoku is solved (no 0s).
function sud_is_solved(sud::Array{Int8,2})
    return min(sud...) > 0
end

# Check the entire thing.
function sud_is_valid(sud::Array{Int8,2})
    for c = 1:9
        for r = 1:9
            if sud[r, c] > 0 && !sud_is_valid(sud, r, c)
                return false
            end
        end
    end
    return true
end

# Check a particular row and column.
function sud_is_valid(sud::Array{Int8,2}, row, col)
    val = sud[row, col]

    # Check if conflicting in current col. This is done first to search in
    # column major order.
    for r = 1:9
        if r == row
            continue
        end
        if sud[r, col] == val
            return false
        end
    end

    # Check if conflicting in current row.
    for c = 1:9
        if c == col
            continue
        end
        if sud[row, c] == val
            return false
        end
    end

    # Check if conflicting in current box.
    row_start = 3 * ((row - 1) ÷ 3) + 1
    col_start = 3 * ((col - 1) ÷ 3) + 1
    for c = col_start:col_start+2
        for r = row_start:row_start+2
            if r == row && c == col
                continue
            end
            if sud[r, c] == val
                return false
            end
        end
    end

    # All checks passed.
    return true
end

# Print a sudoku to stdout.
function sud_print(sud::Array{Int8,2})
    for row = 1:9
        row_str = join([string(val) for val in sud[row, :]])
        row_str = replace(row_str, "0" => ".")
        println(row_str[1:3], " ", row_str[4:6], " ",
                row_str[7:9])
        if row == 3 || row == 6
            println("")
        end
    end
end

# Read a sudoku from a file.
function sud_read(path::String)
    sud = zeros(Int8, 9, 9)
    open(path, "r") do file
        line_num = 0
        sud_row = 0
        for line in eachline(file)
            line_num += 1
            trim_line = replace(line, " " => "")
            if trim_line == "" || startswith(trim_line, "#")
                continue
            end
            sud_row += 1
            if length(trim_line) != 9
                error("Line #", line_num, " of \"", path,
                    "\" does not have 9 digts: \"", line, "\".")
            end
            trim_line = replace(trim_line, "." => "0")
            sud[sud_row, :] = [parse(Int8, n) for n in trim_line]
        end
    end
    return sud
end

# Solve a sudoku write the solution to stdout.
function sud_solve(sud::Array{Int8,2})
    # The original version is needed for error messages.
    sud_cp = copy(sud)

    fixed = sud_get_fixed(sud_cp)

    # Step to first non-fixed cell. In column major order this is the first
    # non-fixed cell after [0, 1].
    row, col = sud_step(fixed, 0, 1, 1)

    # Set row to 0 to it breaks out of the loop for invalid sudokus.
    if !sud_is_valid(sud_cp)
        row = 0
    end

    # If the above stepped past the end then it is a solved sudoku, and we
    # just need to check it.
    found = row == 0
    while row != 0
        val = sud_cp[row, col]
        val += 1
        if val > 9
            sud_cp[row, col] = 0
            # Step one backward.
            row, col = sud_step(fixed, row, col, -1)
            continue
        end
        sud_cp[row, col] = val
        if sud_is_valid(sud_cp, row, col)
            # Step one forward
            row, col = sud_step(fixed, row, col, 1)
            if row == 0
                # Went past the end - must be solved.
                found = true
            end
        end
    end

    errors = []
    if found
        if !sud_is_valid(sud_cp)
            push!(errors, "not valid")
        end
        if !sud_is_solved(sud_cp)
            push!(errors, "not solved")
        end
        if length(errors) > 0
            println(stderr, "Found an invalid solution (",
                join(errors, ", "), "):")
        end
        sud_print(sud_cp)
        if length(errors) > 0
            exit(1)
        end
    else
        println(stderr, "Could not find a solution for:")
        sud_print(sud) # The original sud.
        exit(1)
    end
end

# Solve multiple sodoku puzzles given their paths.
function sud_solves(paths::Array{String,1})
    first = true
    last_path = ""
    sud = zeros(Int8, 9, 9)
    for path in paths
        if first
            first = false
        else
            println("\n")
        end
        # If the path has not been changed then sud can be reused.
        if path != last_path
            sud = sud_read(path)
        end
        sud_solve(sud)
        last_path = path
    end
end

# Step forward or backward to the next non-fixed location. Return zeros if
# such a location can not be found. The step is column major order.
function sud_step(fixed::Array{Bool,2}, row, col, inc)
    while true
        row += inc
        if row < 1
            row = 9
            col -= 1
        elseif row > 9
            row = 1
            col += 1
        end
        if col < 1 || col > 9
            # 0 for an invalid value.
            return 0, 0
        end
        if !fixed[row, col]
            return row, col
        end
    end
end

# Write a usage statement to stdout.
function usage()
    println("backtracking.jl puzzle1.sud [puzzle2.sud ...]")
    println("backtracking.jl -h")
end

# Main

if length(ARGS) == 0 || ARGS[1] == "-h"
    usage()
    exit(0)
end

sud_solves(ARGS)

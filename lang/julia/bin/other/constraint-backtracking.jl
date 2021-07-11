#!/usr/bin/env julia

# SPDX-License-Identifier: BSD-3-Clause

# backtracking.jl - Solve sudokus using constraints followed by backtracking.

# Use constraints to determine which values are possible, then use backtracking.

using Dates
using Printf

# Sort a 2D array of column vectors (dimension 2). This wrapper for sortslices()
# seems to improve performance by having an explicit return value.
function sort_column_vectors(sud_ones::Array{Int64,2})::Array{Int64,2}
    return sortslices(sud_ones, dims=2)
end

# Constrain to the value at row and col.
function sud_apply_constraint(sud::Array{Int16,2}, row::Int64, col::Int64)
    val = sud[row, col]

    # Only attempt to apply constraints from fully determined cells.
    if count_ones(val) != 1
        return false
    end

    # Go until a change is seen.
    change = false

    # Check if conflicting in current col. This is done first to search in
    # column major order.
    for r = 1:9
        if r == row
            continue
        end
        other_val = sud[r, col]
        if val & other_val != 0
            change = true
            sud[r, col] = (~val) & other_val
        end
    end

    # Check if conflicting in current col. This is done first to search in
    # column major order.
    for c = 1:9
        if c == col
            continue
        end
        other_val = sud[row, c]
        if val & other_val != 0
            change = true
            sud[row, c] = (~val) & other_val
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
            other_val = sud[r, c]
            if val & other_val != 0
                change = true
                sud[r, c] = (~val) & other_val
            end
        end
    end

    return change
end

# Constraint until the sudoku no longer changes.
function sud_apply_constraints(sud::Array{Int16,2})
    while true
        changed = false
        for c = 1:9
            for r = 1:9
                if sud_apply_constraint(sud, r, c)
                    changed = true
                end
            end
        end
        if !changed
            break
        end
    end
end

# Get a 3 x 81 array the describes the best order. Each column vector has form
# [order, row, col]. The assumption is that it is best to consider the most
# constrained cells first followed by a consistent order so that each attempt
# is maximally constrained by the existing partial solution.
function sud_get_preferred_order(sud::Array{Int16,2})::Array{Int64,2}
    sud_ones = zeros(Int64, 3, 81)
    i = 1
    for c = 1:9
        for r = 1:9
            sud_ones[:, i] = [(count_ones(sud[r, c]) << 8) | (r + 9c), r, c]
            i += 1
        end
    end
    return sud_ones
end

# Return true if a sudoku is solved (exactly one digit per cell).
function sud_is_solved(sud::Array{Int16,2})::Bool
    for c = 1:9
        for r = 1:9
            val = sud[r, c]
            if (val < 2) || (count_ones(val) != 1) # Only one digit allowed.
                return false
            end
        end
    end
    return true
end

# Check if a sudoku is valid. It is valid if all of the cells are non-zero and
# if all cells that have exactly one digit do not conflict with any other cells.
# Digit cells do not conflict with the 0 digit (bit #0 encoded as 1).
function sud_is_valid(sud::Array{Int16,2})::Bool
    for c = 1:9
        for r = 1:9
            val = sud[r, c]
            if val == 0
                # A value of 0 means no digits are possible.
                return false
            end
            # 2 is bit #1, the lowest digit.
            if val >= 2 && (count_ones(val) == 1) && !sud_is_valid(sud, r, c)
                return false
            end
        end
    end
    return true
end

# Check a particular row and column. Returns false if a conflicting cell is
# found where there are no digits. The other cell being compared to having a
# value of 1 (bit #0 used for partial solutions) is valid. The value at row, col
# must be a specific digit (exactly one bit set, not bit #0).
function sud_is_valid(sud::Array{Int16,2}, row::Int64, col::Int64)::Bool
    val = sud[row, col]

    # Check if conflicting in current col. This is done first to search in
    # column major order.
    for r = 1:9
        if r == row
            continue
        end
        if val == sud[r, col]
            return false
        end
    end

    # Check if conflicting in current row.
    for c = 1:9
        if c == col
            continue
        end
        if val == sud[row, c]
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
            if val == sud[r, c]
                return false
            end
        end
    end

    # All checks passed.
    return true
end

# Print a sudoku to stdout.
function sud_print(sud::Array{Int16,2})
    for row = 1:9
        # "X" for impossible and "?" for multiple values.
        row_str = join([if count_ones(val) == 1
                          string(trailing_zeros(val))
                        else (if val == 0 "X" else "?" end) end
                        for val in sud[row, :]])
        row_str = replace(row_str, "0" => ".")
        println(row_str[1:3], " ", row_str[4:6], " ",
                row_str[7:9])
        if row == 3 || row == 6
            println("")
        end
    end
end

# Print a sudoku to stdout in detail for debugging.
function sud_print_full(sud::Array{Int16,2})
    for row = 1:9
        row_str = join([@sprintf("%4x", val) for val in sud[row, :]])
        println(row_str[1:12], "  ", row_str[13:24], "  ",
                row_str[25:36])
        if row == 3 || row == 6
            println("")
        end
    end
end

# Read a sudoku from a file.
function sud_read(path::String)::Array{Int16,2}
    sud = zeros(Int16, 9, 9)

    # A cell where all values are possible, so bits 1 - 9 are set.
    all_digits::Int16 = (1 << 10) - 2

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
                    "\" does not have 9 digits: \"", line, "\".")
            end
            trim_line = replace(trim_line, "." => "0")
            sud[sud_row, :] = [if n == '0' all_digits else
                                   1 << parse(Int16, n) end
                               for n in trim_line]
        end
    end
    return sud
end

# Solve a sudoku write the solution to stdout.
function sud_solve(sud::Array{Int16,2})
    # Constrain the sudoku as much as possible first.
    sud_apply_constraints(sud)

    # Get a 3 x 81 array consisting of column vectors [ones, row, col] where
    # "ones" is a count of the number of bits sets. Sort in order to work with
    # the most constrained cells first.
    sud_ones = sud_get_preferred_order(sud)

    # Sort to preferred order.
    sud_ones = sort_column_vectors(sud_ones)

    # Our tentative solution to be filled with backtracking values subject to
    # the allowed values found above. Ones are used since 1 corresponds to
    # bit 0, so 0 is initially the solution for each cell.
    sud_sol = ones(Int16, 9, 9)

    # Start here and go forward in column major order. "val" is incremented at
    # the start of each iteration, so it's ok for it to be 0 here. Break out
    # of the loop in the not valid case with "idx" == 0.
    idx = if sud_is_valid(sud) 1 else 0 end

    # Main loop.
    @label main_loop
    while idx >= 1 && idx <= 81
        # Get the row and col for the current index.
        _, row, col = sud_ones[:, idx]
        # println("read ", idx, " ", xxo, " ", row, " ", col)

        # Get the existing set of allowed values, and the current value.
        allowed = sud[row, col]
        val = sud_sol[row, col]

        # Increment "val" to the next allowed value.
        while val <= 1 << 9
            val <<= 1
            if (val & allowed) == 0
                continue
            end
            sud_sol[row, col] = val
            if sud_is_valid(sud_sol, row, col)
                idx += 1
                @goto main_loop
            end
        end

        # Could not find a valid value for the current cell, so backtrack.
        sud_sol[row, col] = 1 # bit #0
        idx -= 1
    end

    errors = []
    if !sud_is_valid(sud_sol)
        push!(errors, "not valid")
    end
    if !sud_is_solved(sud_sol)
        push!(errors, "not solved")
    end
    if length(errors) > 0
        println(stderr, "Found an invalid solution (", join(errors, ", "),
                        "):")
    end
    sud_print(sud_sol)
    if length(errors) > 0
        exit(1)
    end
end

# Solve multiple sodoku puzzles given their paths.
function sud_solves(paths::Array{String,1}, verbose::Bool)
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
        if verbose
            println("Solving ", path)
            before = now()
        end
        sud_solve(sud)
        if verbose
            println("Solved  ", path, " in ", now() - before)
        end
        last_path = path
    end
end

# Write a usage statement to stdout.
function usage()
    println("constraint-backtracking.jl puzzle1.sud [puzzle2.sud ...]")
    println("constraint-backtracking.jl -h")
end

# Main

if length(ARGS) == 0 || ARGS[1] == "-h"
    usage()
    exit(0)
end

if ARGS[1] == "-v"
    verbose = true
    args = ARGS[2:length(ARGS)]
else
    verbose = false
    args = ARGS
end

sud_solves(args, verbose)

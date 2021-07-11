// SPDX-License-Identifier: BSD-3-Clause

package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Solve sudokus using backtracking.

// This is a simple brute force sudoku solver, but it's still quite fast in
// most cases. It's ported from:
//   https://github.com/selliott512/julia-sudoku-solvers

// Get an array of booleans indicating the fixed values in a sudoku.
func sudGetFixed(sud *[9][9]int8) [9][9]bool {
	var z [9][9]bool
	for r := 0; r < 9; r++ {
		for c := 0; c < 9; c++ {
			z[r][c] = sud[r][c] > 0
		}
	}
	return z
}

// Return true if a sudoku is solved (no 0s).
func sudIsSolved(sud *[9][9]int8) bool {
	for r := 0; r < 9; r++ {
		for c := 0; c < 9; c++ {
			if sud[r][c] == 0 {
				return false
			}
		}
	}
	return true
}

// Check the entire thing.
func sudIsValid(sud *[9][9]int8) bool {
	for r := 0; r < 9; r++ {
		for c := 0; c < 9; c++ {
			if sud[r][c] > 0 && !sudCellIsValid(sud, r, c) {
				return false
			}
		}
	}
	return true
}

// Check a particular cell
func sudCellIsValid(sud *[9][9]int8, row int, col int) bool {
	val := sud[row][col]

	// Check if conflicting in current row. This is done first to search in
	// row major order.
	for c := 0; c < 9; c++ {
		if c == col {
			continue
		}
		if sud[row][c] == val {
			return false
		}
	}

	// Check if conflicting in current col.
	for r := 0; r < 9; r++ {
		if r == row {
			continue
		}
		if sud[r][col] == val {
			return false
		}
	}

	// Check if conflicting in current box.
	rowStart := 3 * (row / 3)
	colStart := 3 * (col / 3)
	for r := rowStart; r < rowStart+3; r++ {
		for c := colStart; c < colStart+3; c++ {
			if r == row && c == col {
				continue
			}
			if sud[r][c] == val {
				return false
			}
		}
	}

	// All checks passed.
	return true
}

// Print a sudoku to stdout.
func sudPrint(sud *[9][9]int8) {
	for row := 0; row < 9; row++ {
		var rowBuilder strings.Builder
		for col := 0; col < 9; col++ {
			rowBuilder.WriteString(strconv.Itoa(int(sud[row][col])))
		}
		rowStr := strings.ReplaceAll(rowBuilder.String(), "0", ".")
		fmt.Println(
			rowStr[0:3],
			rowStr[3:6],
			rowStr[6:9])
		if row == 2 || row == 5 {
			fmt.Println()
		}
	}
}

// Read a sudoku from a file.
func sudRead(path string) [9][9]int8 {
	var sud [9][9]int8
	lineNum := 0
	sudRow := 0
	pathHand, err := os.Open(path)
	if err != nil {
		panic(fmt.Sprintf("Unable to open %s for read: %s", path, err))
	}
	defer pathHand.Close()
	scanner := bufio.NewScanner(pathHand)
	for scanner.Scan() {
		line := scanner.Text()
		lineNum++
		trimLine := strings.ReplaceAll(strings.TrimSpace(line), " ", "")
		if trimLine == "" || strings.HasPrefix(trimLine, "#") {
			continue
		}
		if len(trimLine) != 9 {
			panic(fmt.Sprintf(
				"Line #%d of \"%s\" does not have 9 digts: %s",
				lineNum, path, line))
		}
		trimLine = strings.ReplaceAll(trimLine, ".", "0")
		for i, c := range trimLine {
			sud[sudRow][i] = int8(c - '0')
		}
		sudRow++
	}
	return sud
}

// Solve a sudoku write the solution to stdout.
func sudSolve(sud *[9][9]int8) {
	// The original version is needed for error messages.
	sudCP := *sud

	fixed := sudGetFixed(&sudCP)

	// Step to first non-fixed cell. In row major order this is the first
	// non-fixed cell after [0, -1].
	row, col := sudStep(&fixed, 0, -1, 1)

	// Set row to 9 to it breaks out of the loop for invalid sudokus.
	if !sudIsValid(&sudCP) {
		row = 9
	}

	// If the above stepped past the end then it is a solved sudoku, and we
	// just need to check it.
	found := row == 9
	for row != 9 {
		val := sudCP[row][col]
		val++
		if val > 9 {
			sudCP[row][col] = 0
			// Step one backward.
			r, c := sudStep(&fixed, row, col, -1)
			row = r
			col = c
			continue
		}
		sudCP[row][col] = val
		if sudCellIsValid(&sudCP, row, col) {
			// Step one forward
			r, c := sudStep(&fixed, row, col, 1)
			row = r
			col = c
			if row == 9 {
				// Went past the end - must be solved.
				found = true
			}
		}
	}

	errors := make([]string, 0)
	if found {
		if !sudIsValid(&sudCP) {
			errors = append(errors, "not valid")
		}
		if !sudIsSolved(&sudCP) {
			errors = append(errors, "not solved")
		}
		if len(errors) > 0 {
			fmt.Fprintf(os.Stderr, "Found an invalid solution (%s):", strings.Join(errors, ", "))
		}
		sudPrint(&sudCP)
		if len(errors) > 0 {
			os.Exit(1)
		}
	} else {
		fmt.Fprintf(os.Stderr, "Could not find a solution for:")
		sudPrint(sud) // The original sud.
		os.Exit(1)
	}
}

// Solve multiple sodoku puzzles given their paths.
func sudSolves(paths []string) {
	first := true
	lastPath := ""
	var sud [9][9]int8
	for _, path := range paths {
		if first {
			first = false
		} else {
			fmt.Println()
		}
		// If the path has not been changed then sud can be reused.
		if path != lastPath {
			sud = sudRead(path)
		}
		sudSolve(&sud)
		lastPath = path
	}
}

// Step forward or backward to the next non-fixed location. Return zeros if
// such a location can not be found. The step is row major order.
func sudStep(fixed *[9][9]bool, row int, col int, inc int) (int, int) {
	for {
		col += inc
		if col < 0 {
			col = 8
			row--
		} else if col > 8 {
			col = 0
			row++
		}
		if row < 0 || row > 8 {
			// 9 indicating out of range
			return 9, 9
		}
		if !fixed[row][col] {
			return row, col
		}
	}
}

// Write a usage statement to stdout.
func usage() {
	fmt.Println("go-sudoku-solvers puzzle1.sud [puzzle2.sud ...]")
	fmt.Println("  -h  This help message")
}

// Main

func main() {
	if len(os.Args) < 2 || os.Args[1] == "-h" {
		usage()
		os.Exit(0)
	}

	sudSolves(os.Args[1:])
}

// SPDX-License-Identifier: BSD-3-Clause

use std::env;
use std::fs::File;
use std::io::{self, prelude::*};
use std::process;

// Solve sudokus using backtracking.

// This is a simple brute force sudoku solver, but it's still quite fast in
// most cases. It's ported from:
//   https://github.com/selliott512/julia-sudoku-solvers

// Get an array of booleans indicating the fixed values in a sudoku.
fn sud_get_fixed(sud: &[[i8; 9]; 9]) -> [[bool; 9]; 9] {
    let mut z = [[false; 9]; 9];
    for r in 0..9 {
        for c in 0..9 {
            z[r][c] = sud[r][c] > 0;
        }
    }
    return z;
}

// Return true if a sudoku is solved (no 0s).
fn sud_is_solved(sud: &[[i8; 9]; 9]) -> bool {
    for r in 0..9 {
        for c in 0..9 {
            if sud[r][c] == 0 {
                return false;
            }
        }
    }
    true
}

// Check the entire thing.
fn sud_is_valid(sud: &[[i8; 9]; 9]) -> bool {
    for r in 0..9 {
        for c in 0..9 {
            if sud[r][c] > 0 && !sud_cell_is_valid(sud, r, c) {
                return false;
            }
        }
    }
    true
}

// Check a particular cell
fn sud_cell_is_valid(sud: &[[i8; 9]; 9], row: usize, col: usize) -> bool {
    let val = sud[row][col];

    // Check if conflicting in current row. This is done first to search in
    // row major order.
    for c in 0..9 {
        if c == col {
            continue;
        }
        if sud[row][c] == val {
            return false;
        }
    }

    // Check if conflicting in current col.
    for r in 0..9 {
        if r == row {
            continue;
        }
        if sud[r][col] == val {
            return false;
        }
    }

    // Check if conflicting in current box.
    let row_start = 3 * (row / 3);
    let col_start = 3 * (col / 3);
    for r in row_start..row_start + 3 {
        for c in col_start..col_start + 3 {
            if r == row && c == col {
                continue;
            }
            if sud[r][c] == val {
                return false;
            }
        }
    }

    // All checks passed.
    return true;
}

// Print a sudoku to stdout.
fn sud_print(sud: &[[i8; 9]; 9]) {
    for row in 0..9 {
        let mut row_str = String::with_capacity(9);
        for col in 0..9 {
            row_str.push_str(&sud[row][col].to_string());
        }
        row_str = row_str.replace("0", ".");
        println!(
            "{} {} {}",
            row_str.get(0..3).unwrap(),
            &row_str.get(3..6).unwrap(),
            row_str.get(6..9).unwrap()
        );
        if row == 2 || row == 5 {
            println!();
        }
    }
}

// Read a sudoku from a file.
fn sud_read(path: &str) -> [[i8; 9]; 9] {
    let mut sud = [[0_i8; 9]; 9];
    let mut line_num = 0;
    let mut sud_row = 0;
    let path_hand = match File::open(path) {
        Ok(fhand) => fhand,
        Err(error) => panic!("Unable to open {} for read: {:?}", path, error),
    };
    let lines = io::BufReader::new(path_hand).lines();
    for line in lines {
        line_num += 1;
        let line_uw = line.unwrap();
        let trim_line = line_uw.trim().replace(" ", "");
        if trim_line == "" || trim_line.starts_with("#") {
            continue;
        }
        if trim_line.len() != 9 {
            panic!(
                "Line #{} of \"{}\" does not have 9 digts: {}",
                line_num, path, line_uw
            );
        }
        let trim_line = &trim_line.replace(".", "0");
        for (i, c) in trim_line.chars().enumerate() {
            sud[sud_row][i] = c as i8 - '0' as i8;
        }
        sud_row += 1;
    }
    return sud;
}

// Solve a sudoku write the solution to stdout.
fn sud_solve(sud: &[[i8; 9]; 9]) {
    // The original version is needed for error messages.
    let mut sud_cp = sud.clone();

    let fixed = sud_get_fixed(&sud_cp);

    // Step to first non-fixed cell. In row major order this is the first
    // non-fixed cell after [0, -1].
    let (mut row, mut col) = sud_step(&fixed, 0, -1_isize as usize, 1);

    // Set row to 9 to it breaks out of the loop for invalid sudokus.
    if !sud_is_valid(&sud_cp) {
        row = 9;
    }

    // If the above stepped past the end then it is a solved sudoku, and we
    // just need to check it.
    let mut found = row == 9;
    while row != 9 {
        let mut val = sud_cp[row][col];
        val += 1;
        if val > 9 {
            sud_cp[row][col] = 0;
            // Step one backward.
            let (r, c) = sud_step(&fixed, row, col, -1);
            row = r;
            col = c;
            continue;
        }
        sud_cp[row][col] = val;
        if sud_cell_is_valid(&sud_cp, row, col) {
            // Step one forward
            let (r, c) = sud_step(&fixed, row, col, 1);
            row = r;
            col = c;
            if row == 9 {
                // Went past the end - must be solved.
                found = true;
            }
        }
    }

    let mut errors = vec![];
    if found {
        if !sud_is_valid(&sud_cp) {
            errors.push("not valid");
        }
        if !sud_is_solved(&sud_cp) {
            errors.push("not solved");
        }
        if errors.len() > 0 {
            eprintln!("Found an invalid solution ({}):", errors.join(", "));
        }
        sud_print(&sud_cp);
        if errors.len() > 0 {
            process::exit(1);
        }
    } else {
        eprintln!("Could not find a solution for:");
        sud_print(sud); // The original sud.
        process::exit(1);
    }
}

// Solve multiple sodoku puzzles given their paths.
fn sud_solves(paths: &[String]) {
    let mut first = true;
    let mut last_path = "";
    let mut sud = [[0_i8; 9]; 9];
    for path in paths {
        if first {
            first = false;
        } else {
            println!();
        }
        // If the path has not been changed then sud can be reused.
        if path != last_path {
            sud = sud_read(path);
        }
        sud_solve(&sud);
        last_path = path;
    }
}

// Step forward or backward to the next non-fixed location. Return zeros if
// such a location can not be found. The step is row major order.
fn sud_step(fixed: &[[bool; 9]; 9], row: usize, col: usize, inc: isize) -> (usize, usize) {
    let mut irow = row as isize;
    let mut icol = col as isize;
    loop {
        icol += inc;
        if icol < 0 {
            icol = 8;
            irow -= 1;
        } else if icol > 8 {
            icol = 0;
            irow += 1;
        }
        if irow < 0 || irow > 8 {
            // 9 indicating out of range
            return (9, 9);
        }
        if !fixed[irow as usize][icol as usize] {
            return (irow as usize, icol as usize);
        }
    }
}

// Write a usage statement to stdout.
fn usage() {
    println!("rust-sudoku-solvers puzzle1.sud [puzzle2.sud ...]");
    println!("  -h  This help message");
}

// Main

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 || &args[1] == "-h" {
        usage();
        process::exit(0);
    }

    sud_solves(&args[1..]);
}

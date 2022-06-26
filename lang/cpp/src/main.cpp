// SPDX-License-Identifier: BSD-3-Clause

#include <cstddef>
#include <cstdlib>

using namespace std;

// Solve sudokus using backtracking.

// This is a simple brute force sudoku solver, but it's still quite fast in
// most cases. It's ported from:
//   https://github.com/selliott512/julia-sudoku-solvers

// Get an array of booleans indicating the fixed values in a sudoku.
bool[9][9] sud_get_fixed(const char sud[9][9]) {
    const bool[9][9] z = {false};
    for (int r = 0; r < 9; r++) {
        for (int c = 0 ; c < 9; c++) {
            z[r][c] = sud[r][c] > 0;
        }
    }
    return z;
}

// Return true if a sudoku is solved (no 0s).
bool sud_is_solved(const char sud[9][9]) {
    for (int r = 0; r < 9; r++) {
        for (int c = 0 ; c < 9; c++) {
            if (sud[r][c] == 0) {
                return false;
            }
        }
    }
    return true;
}

// Check the entire thing.
bool sud_is_valid(const char sud[9][9]) {
    for (int r = 0; r < 9; r++) {
        for (int c = 0 ; c < 9; c++) {
            if (sud[r][c] > 0 && !sud_cell_is_valid(sud, r, c)) {
                return false;
            }
        }
    }
    return true;
}

// Check a particular cell
bool sud_cell_is_valid(const char sud[9][9], const size_t row, const size_t col) {
    let val = sud[row][col];

    // Check if conflicting in current row. This is done first to search in
    // row major order.
    for (int c = 0 ; c < 9; c++) {
        if (c == col) {
            continue;
        }
        if (sud[row][c] == val) {
            return false;
        }
    }

    // Check if conflicting in current col.
    for (int r = 0; r < 9; r++) {
        if (r == row) {
            continue;
        }
        if (sud[r][col] == val) {
            return false;
        }
    }

    // Check if conflicting in current box.
    let row_start = 3 * (row / 3);
    let col_start = 3 * (col / 3);
    for r in row_start..row_start + 3 {
        for c in col_start..col_start + 3 {
            if (r == row && c == col) {
                continue;
            }
            if (sud[r][c] == val) {
                return false;
            }
        }
    }

    // All checks passed.
    return true;
}

// Print a sudoku to stdout.
void sud_print(const char sud[9][9]) {
    for (int row = 0; row < 9; row++) {
        const string row_str = string(9, ' ');
        for (int col = 0; col < 9; col++) {
            row_str[col] = sud[row][col] + '0';
        }
        row_str.replace('0', '.');
        cout << row_str.substr(0, 3) << ' ' <<
                row_str.substr(3, 3) << ' ' <<
                row_str.substr(6, 3) << endl;
        );
        if (row == 2 || row == 5) {
            cout << endl;
        }
    }
}

// Read a sudoku from a file.
fn sud_read(const char *path) -> [[i8; 9]; 9] {
    unsigned char sud[9][9] = {0};
    int line_num = 0;
    int sud_row = 0;
    let path_hand = match File::open(path) {
        Ok(fhand) => fhand,
        Err(error) => panic!("Unable to open {} for read: {:?}", path, error),
    };
    ifstream fhand(path);
    let lines = io::BufReader::new(path_hand).lines();
    for line in lines {
        line_num += 1;
        let line_uw = line;
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
fn sud_solve(const char sud[9][9]) {
    // The original version is needed for error messages.
    let mut sud_cp = sud.clone();

    let fixed = sud_get_fixed(&sud_cp);

    // Step to first non-fixed cell. In row major order this is the first
    // non-fixed cell after [0, -1].
    let (mut row, mut col) = sud_step(&fixed, 0, -1_isize as size_t, 1);

    // Set row to 9 to it breaks out of the loop for invalid sudokus.
    if (!sud_is_valid(&sud_cp)) {
        row = 9;
    }

    // If the above stepped past the end then it is a solved sudoku, and we
    // just need to check it.
    let mut found = row == 9;
    while (row != 9) {
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
        if (sud_cell_is_valid(&sud_cp, row, col)) {
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
        if (!sud_is_valid(&sud_cp)) {
            errors.push("not valid");
        }
        if (!sud_is_solved(&sud_cp)) {
            errors.push("not solved");
        }
        if (errors.len() > 0) {
            ecout << ("Found an invalid solution ({}):", errors.join(", "));
        }
        sud_print(&sud_cp);
        if (errors.len() > 0) {
            process::exit(1);
        }
    } else {
        ecout << ("Could not find a solution for:");
        sud_print(sud); // The original sud.
        process::exit(1);
    }
}

// Solve multiple sodoku puzzles given their paths.
fn sud_solves(const char *paths[]) {
    let mut first = true;
    let mut last_path = "";
    let mut sud = [[0_i8; 9]; 9];
    for (const char *path : paths) {
        if (first) {
            first = false;
        } else {
            cout << ();
        }
        // If the path has not been changed then sud can be reused.
        if (path != last_path) {
            sud = sud_read(path);
        }
        sud_solve(&sud);
        last_path = path;
    }
}

// Step forward or backward to the next non-fixed location. Return zeros if
// such a location can not be found. The step is row major order.
fn sud_step(fixed: &[[bool; 9]; 9], const size_t row, const size_t col, inc: isize) -> (size_t, size_t) {
    let mut irow = row as isize;
    let mut icol = col as isize;
    while (true) {
        icol += inc;
        if (icol < 0) {
            icol = 8;
            irow -= 1;
        } else if (icol > 8) {
            icol = 0;
            irow += 1;
        }
        if (irow < 0 || irow > 8) {
            // 9 indicating out of range
            return (9, 9);
        }
        if (!fixed[irow][icol]) {
            return (irow, icol);
        }
    }
}

// Write a usage statement to stdout.
void usage() {
    cout << "cpp-sudoku-solvers puzzle1.sud [puzzle2.sud ...]" << endl;
    cout << "  -h  This help message" << endl;
}

// Main

int main(int argc, char *argv[], char *envp[]) {
    if (argc < 2 || !strcmp(args[1], "-h")) {
        usage();
        exit(0);
    }

    sud_solves(&args[1]);
}

import java.io.BufferedReader;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

// SPDX-License-Identifier: BSD-3-Clause

// Solve sudokus using backtracking.

// This is a simple brute force sudoku solver, but it's still quite fast in
// most cases. It's ported from:
//   https://github.com/selliott512/julia-sudoku-solvers

public class Backtracking {
	// Get an array of booleans indicating the fixed values in a sudoku.
	public static boolean[][] sudGetFixed(final byte[][] sud) {
		final boolean[][] z = new boolean[9][9];
		for (int r = 0; r < 9; r++) {
			for (int c = 0; c < 9; c++) {
				z[r][c] = sud[r][c] > 0;
			}
		}
		return z;
	}
	
	// Return true if a sudoku is solved (no 0s).
	public static boolean sudIsSolved(final byte[][] sud) {
		for (int r = 0; r < 9; r++) {
			for (int c = 0; c < 9; c++) {
				if (sud[r][c] == 0) {
					return false;
				}
			}
		}
		return true;
	}

	// Check the entire thing.
	public static boolean sudIsValid(final byte[][] sud) {
		
		for (int r = 0; r < 9; r++) {
			for (int c = 0; c < 9; c++) {
				if (sud[r][c] > 0 && !sudCellIsValid(sud, r, c)) {
					return false;
				}
			}
		}
		return true;
	}
	
	// Check a particular cell
	public static boolean sudCellIsValid(final byte[][] sud, final int row, final int col) {
		final byte val = sud[row][col];

		// Check if conflicting in current row. This is done first to search in
		// row major order.
		for (int c = 0; c < 9; c++) {
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
		final int rowStart = 3 * (row / 3);
		final int colStart = 3 * (col / 3);
		for (int r = rowStart; r < rowStart+3; r++) {
			for (int c = colStart; c < colStart+3; c++) {
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
	public static void sudPrint(final byte[][] sud) {
		for (int row = 0; row < 9; row++) {
			final StringBuilder rowSB = new StringBuilder();
			for (int col = 0; col < 9; col++) {
				if (col == 3 || col == 6) {
					rowSB.append(' ');
				}
				final byte val = sud[row][col];
				rowSB.append(val == 0 ? '.' : val);
			}
			if (row == 3 || row == 6) {
				System.out.println();
			}
			System.out.println(rowSB);
		}
	}
	
	// Read a sudoku from a file.
	public static byte[][] sudRead(final String path) {
		final byte[][] sud = new byte[9][9];
		try (BufferedReader reader = new BufferedReader(new FileReader(path)))
		{
			int lineNum = 0;
			int sudRow = 0;
			String line;
			while ((line = reader.readLine()) != null)
			{
				lineNum++;
				line = line.trim();
				if (line.isEmpty() || line.startsWith("#"))
				{
					continue;
				}
				// Get rid of spaces.
				line = line.replace(" ", "");
				line = line.replace(".", "0");
				if (line.length() != 9)
				{
					sudFatal(String.format("Line #%d of \"%s\" does not have 9 digts: %s",
							lineNum, path, line));
				}
				for (int c = 0; c < line.length(); c++) {
					sud[sudRow][c] = (byte)(line.charAt(c) - '0');
				}
				sudRow++;
			}
		} catch (Exception e) {
			throw new RuntimeException("Unable to open \"" + path + "\" for read: " + e, e);
		}
		return sud;
	}
	
	// Solve a sudoku write the solution to stdout.
	public static void sudSolve(final byte[][] sud) {
		// The original version is needed for error messages.
		final byte[][] sudCP = sudCopy(sud);

		final boolean[][] fixed = sudGetFixed(sudCP);

		// Step to first non-fixed cell. In row major order this is the first
		// non-fixed cell after [0, -1].
		int[] result = sudStep(fixed, 0, -1, 1);
		int row = result[0];
		int col = result[1];
		

		// Set row to 9 to it breaks out of the loop for invalid sudokus.
		if (!sudIsValid(sudCP)) {
			row = 9;
		}

		// If the above stepped past the end then it is a solved sudoku, and we
		// just need to check it.
		boolean found = row == 9;
		while (row != 9) {
			byte val = sudCP[row][col];
			val++;
			if (val > 9) {
				sudCP[row][col] = 0;
				// Step one backward.
				result = sudStep(fixed, row, col, -1);
				int r = result[0];
				int c = result[1];
				row = r;
				col = c;
				continue;
			}
			sudCP[row][col] = val;
			if (sudCellIsValid(sudCP, row, col)) {
				// Step one forward
				result = sudStep(fixed, row, col, 1);
				int r = result[0];
				int c = result[1];
				row = r;
				col = c;
				if (row == 9) {
					// Went past the end - must be solved.
					found = true;
				}
			}
		}
		
		final List<String> errors = new ArrayList<>();
		if (found) {
			if (!sudIsValid(sudCP)) {
				errors.add("not valid");
			}
			if (!sudIsSolved(sudCP)) {
				errors.add("not solved");
			}
			if (!errors.isEmpty()) {
				System.err.printf("Found an invalid solution (%s):\n", String.join(", ", errors));
			}
			sudPrint(sudCP);
			if (!errors.isEmpty()) {
				System.exit(1);
			}
		} else {
			System.err.println("Could not find a solution for:");
			sudPrint(sud); // The original sud.
			System.exit(1);
		}
	}
	
	// Solve multiple sodoku puzzles given their paths.
	public static void sudSolves(final String[] paths) {
		boolean first = true;
		String lastPath = null;
		byte[][] sud = null;
		for (final String path : paths) {
			if (first) {
				first = false;
			} else {
				System.out.println();
			}
			// If the path has not been changed then sud can be reused.
			if (!path.equals(lastPath)) {
				sud = sudRead(path);
			}
			sudSolve(sud);
			lastPath = path;
		}
	}

	//Step forward or backward to the next non-fixed location. Return zeros if
	//such a location can not be found. The step is row major order.
	public static int[] sudStep(final boolean[][] fixed, int row, int col, final int inc) {
		while (true) {
			col += inc;
			if (col < 0) {
				col = 8;
				row--;
			} else if (col > 8) {
				col = 0;
				row++;
			}
			if (row < 0 || row > 8) {
				// 9 indicating out of range
				return new int[] {9, 9};
			}
			if (!fixed[row][col]) {
				return new int[] {row, col};
			}
		}
	}

	private static byte[][] sudCopy(byte[][] sud) {
		final byte[][] sudCP = new byte[sud.length][];
		for (int r = 0; r < sudCP.length; r++) {
			sudCP[r] = Arrays.copyOf(sud[r], sud[r].length);
		}
		return sudCP;
	}
	
	// Write a usage statement to stdout.
	public static void usage() {
		System.out.println("Backtracking puzzle1.sud [puzzle2.sud ...]");
		System.out.println("  -h  This help message");
	}

	// Main
	public static void main(final String[] args) {
		if (args.length < 1 || args[0].equals("-h")) {
			usage();
			System.exit(0);
		}

		sudSolves(args);
	}

	// Simple fatal error message handler.
	public static void sudFatal(final String msg) {
		throw new RuntimeException(msg);
	}

	// Simple fatal error message handler with a cause.
	public static void sudFatal(final String msg, final Throwable cause) {
		throw new RuntimeException(msg, cause);
	}
}

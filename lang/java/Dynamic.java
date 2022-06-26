import java.io.BufferedReader;
import java.io.FileReader;
import java.util.Arrays;

// SPDX-License-Identifier: BSD-3-Clause

// Solve dynamically. That is constrain based on single values values, and then
// any additional single values found from them. Perform a search if needed.

// This is a simple brute force sudoku solver, but it's still quite fast in
// most cases. It's ported from:
//   https://github.com/selliott512/julia-sudoku-solvers

public class Dynamic {
  // A mask that allows all nine values.
  private static final short UNCONSTRAINED = (1 << (10 - 1)) - 1;

  // A reusable buffer of indexes mostly used by sudConstrain().
  private static final int[] RECENT_INDEXES = new int[81];

  // Main
  public static void main(final String[] args) {
    if (args.length < 1 || args[0].equals("-h")) {
      sudUsage();
      System.exit(0);
    }

    sudSolves(args);
  }

  // Constrain sud. Based on ones, or "naked singles" and then use them to
  // constrain sud. Since the constraining process may reveal more ones this is
  // done recursively before returning.
  public static boolean sudConstrain(final short[] sud, final Integer lastIndex) {
    // Inclusive then exclusive so that the number of entries is riEnd - riBegin.
    int riBegin = 0;
    int riEnd = 0;

    if (lastIndex != null) {
      // Simple case - the caller gave us the only index that was changed
      // recently.
      RECENT_INDEXES[riEnd++] = lastIndex;
    } else {
      // Multiple case - add all ones to recentIndexes.
      for (int i = 0; i < 81; i++) {
        if (Integer.bitCount(sud[i]) == 1) {
          RECENT_INDEXES[riEnd++] = i;
        }
      }
    }

    // Recursively constrain to each one listed in recentIndexes while
    // appending each new one found to recentIndexes.
    while (riEnd > riBegin) {
      final int index = RECENT_INDEXES[riBegin++];
      final int invMask = ~sud[index];
      final int row = index / 9;
      final int col = index % 9;

      // The upper left hand corner of the 3x3 block that contains row, col.
      final int blockULRow = 3 * (row / 3);
      final int blockULCol = 3 * (col / 3);

      // A list of indexes that are constrained by "index".
      final int[] otherIndexes = new int[20];

      int other = 0;
      for (int r = 0; r < 9; r++) {
        // The row for index, but not in the block.
        if ((r < blockULRow) || (r >= (blockULRow + 3))) {
          otherIndexes[other++] = 9 * r + col;
        }
      }

      for (int c = 0; c < 9; c++) {
        // The col for index, but not in the block.
        if ((c < blockULCol) || (c >= (blockULCol + 3))) {
          otherIndexes[other++] = 9 * row + c;
        }
      }

      for (int r = blockULRow; r < (blockULRow + 3); r++) {
        for (int c = blockULCol; c < (blockULCol + 3); c++) {
          if ((r != row) || (c != col)) {
            otherIndexes[other++] = 9 * r + c;
          }
        }
      }

      for (final int otherIndex : otherIndexes) {
        final short oldVal = sud[otherIndex];
        final short newVal = (short) (invMask & oldVal);
        if (newVal != oldVal) {
          sud[otherIndex] = newVal;
          // The bit count has decreased by exactly one. Hopefully the JRE uses
          // the POPCNT instruction for the following.
          final int newBitCount = Integer.bitCount(newVal);
          if (newBitCount == 0) {
            // Can't be solved.
            return false;
          }
          if (newBitCount == 1) {
            // Another one to consider. Append to recentIndexes. Note that
            // riEnd should never go past the end of RECENT_INDEXES since
            // there at most 81 ones ever.
            RECENT_INDEXES[riEnd++] = otherIndex;
          }
        }
      }
    }
    return true;
  }

  // Simple fatal error message handler.
  public static void sudFatal(final String msg) {
    throw new RuntimeException(msg);
  }

  // Print a sudoku to stdout.
  public static void sudPrint(final short[] sud) {
    for (int row = 0; row < 9; row++) {
      final StringBuilder rowSB = new StringBuilder();
      for (int col = 0; col < 9; col++) {
        if (col == 3 || col == 6) {
          rowSB.append(' ');
        }
        final short mask = sud[9 * row + col];
        if (mask == 0) {
          rowSB.append('X');
        } else {
          final int count = Integer.bitCount(mask);
          if (count == 1) {
            final int val = Integer.numberOfTrailingZeros(mask) + 1;
            rowSB.append(val);
          } else {
            rowSB.append('?');
          }
        }
      }
      if (row == 3 || row == 6) {
        System.out.println();
      }
      System.out.println(rowSB);
    }
  }

  // Read a sudoku from a file.
  public static short[] sudRead(final String path) {
    final short[] sud = new short[81];
    try (BufferedReader reader = new BufferedReader(new FileReader(path))) {
      int lineNum = 0;
      int sudRow = 0;
      String line;
      while ((line = reader.readLine()) != null) {
        lineNum++;
        line = line.trim();
        if (line.isEmpty() || line.startsWith("#")) {
          continue;
        }
        // Get rid of spaces.
        line = line.replace(" ", "");
        line = line.replace(".", "0");
        if (line.length() != 9) {
          sudFatal(String.format("Line #%d of \"%s\" does not have 9 digts: %s", lineNum, path, line));
        }
        for (int c = 0; c < line.length(); c++) {
          final char chr = line.charAt(c);
          sud[9 * sudRow + c] = (chr == '0') ? UNCONSTRAINED : (short) (1 << (chr - '0' - 1));
        }
        sudRow++;
      }
    } catch (Exception e) {
      throw new RuntimeException("Unable to open \"" + path + "\" for read: " + e, e);
    }
    return sud;
  }

  // Solve a sudoku write the solution to stdout.
  public static boolean sudSolve(final short[] sud, final Integer lastIndex) {
    if (!sudConstrain(sud, lastIndex)) {
      return false;
    }

    // Find the cell with least allowed values where there is more than 1.
    int minBitCount = 10;
    int bestIndex = -1;
    for (int i = 0; i < 81; i++) {
      final int bitCount = Integer.bitCount(sud[i]);
      if (bitCount == 1) {
        // No need to consider this solved cell.
        continue;
      }
      if (bitCount == 2) {
        // There's no need to consider anything further if two allowed
        // states is found.
        bestIndex = i;
        break;
      }
      if (bitCount < minBitCount) {
        // Three or more allowed states.
        minBitCount = bitCount;
        bestIndex = i;
      }
    }

    if (bestIndex == -1) {
      // This must mean the bitCount is all 1, which means it is solved.
      sudPrint(sud);
      return true;
    }

    int mask = sud[bestIndex];
    for (int val = 1; mask != 0; mask >>= 1, val++) {
      if ((1 & mask) == 1) {
        // Recursive search with val.
        final short[] sudCP = Arrays.copyOf(sud, sud.length);
        sudCP[bestIndex] = (short) (1 << (val - 1));
        if (sudSolve(sudCP, bestIndex)) {
          return true;
        }
      }
    }

    return false;
  }

  // Solve multiple sodoku puzzles given their paths.
  public static void sudSolves(final String[] paths) {
    boolean first = true;
    String lastPath = null;
    short[] sud = null;
    int invalidCount = 0;
    for (final String path : paths) {
      if (first) {
        first = false;
      } else {
        System.out.println();
        System.out.println();
      }
      // If the path has not been changed then sud can be reused.
      if (!path.equals(lastPath)) {
        sud = sudRead(path);
      }
      if (!sudSolve(sud, null)) {
        invalidCount++;
        sudPrint(sud);
      }
      lastPath = path;
    }

    if (invalidCount > 0) {
      System.err.println();
      System.err.println();
      System.err.println("" + invalidCount + " of " + paths.length + " of the "
          + "provided sudokus are invalid. In the above output the invalid "
          + "solutions will contain non-digit characters:");
      System.err.println("  X  No value is possible for this cell.");
      System.err.println("  ?  More than one value is still possible for this cell.");
      System.exit(1);
    }
  }

  // Write a usage statement to stdout.
  public static void sudUsage() {
    System.out.println("Dynamic puzzle1.sud [puzzle2.sud ...]");
    System.out.println("  -h  This help message");
  }
}

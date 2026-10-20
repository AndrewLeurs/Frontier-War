#include <iostream>
#include <iterator>
#include <cstdint>
#include <random>
#include <atomic>
#include <thread>
#include <functional>
#include <vector>

#define ROW_LENGTH 10

// Returns a random int between 1 & 64
int randomNumber() {
	static std::random_device rd; // obtain a random number from hardware
	static std::mt19937 gen(rd()); // seed the generator
	static std::uniform_int_distribution<> distr(1, 16); // define the range
	return distr(gen);
}

// Integer Scrambler (SplitMix64)
uint64_t mix(uint64_t x) {
	x += 0x9E3779B97F4A7C15ull;
	x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9ull;
	x = (x ^ (x >> 27)) * 0x94D049BB133111EBull;
	return x ^ (x >> 31);
}

// Cell should be a struct
// Components: Difficulty (randomly assigned), correct_value, face (char)
struct Cell {
	int row = 0;
	int col = 0;
	int index = 0;
	int difficulty = randomNumber();
	std::atomic<int> claim{ 0 };
};

// returns any adjacent cells in the form of a vector for dynamic memory allocation
std::vector<Cell*> neighbors(Cell (&board)[10][10], int row, int col) {
	std::vector<Cell*> result;

	// Check any out of bounds limitations (Cell that's on an edge or corner)
	if (row > 0) {
		result.push_back(&board[row - 1][col]);
	}
	if (row < 9) {
		result.push_back(&board[row + 1][col]);
	}
	if (col > 0) {
		result.push_back(&board[row][col - 1]);
	}
	if (col < 9) {
		result.push_back(&board[row][col + 1]);
	}

	return result;
}

void printBoard(Cell (& board)[10][10]) {
	std::cout << "=== FRONTIER WAR ===\n\n";

	for (int i = 0; i < ROW_LENGTH; i++) {
		for (int j = 0; j < ROW_LENGTH; j++) {
			std::cout << board[i][j].claim << " ";
		}
		std::cout << "\n";
	}
	std::cout << std::flush;
}

// Implements the claiming process for one cell
void cellClaim(Cell* cell, int teamNum, uint64_t startingNum) {
	uint64_t attempt = startingNum;

	while (true) {
		if (cell->claim.load() != 0) {
			break;
		}

		uint64_t hash = mix(attempt + cell->index);

		bool valid = (hash >> (64 - cell->difficulty)) == 0;

		if (valid) {
			int expected = 0;
			bool success = cell->claim.compare_exchange_strong(expected, teamNum);

			if (success) {
				std::cout << "Team " << teamNum << " claimed cell " << cell->index << " with nonce " << attempt << "\n";
			}

			break;
		}

		attempt += 2;
	}
}

// returns a vector with every non-owned cell adjacent to an owned cell
std::vector <Cell*> getFrontier(Cell (&board)[10][10], int teamNum) {
	std::vector <Cell*> result;
	bool added[10][10] = {};
	// Iterate through each cell and add the cells adjacent to cells with claim = teamNum to the return vector
	for (int row = 0; row < 10; row++) {
		for (int col = 0; col < 10; col++) {
			// Pass over any non-team cells
			if (board[row][col].claim.load() != teamNum)
				continue;

			for (Cell* cell : neighbors(board, row, col)) {
				if (cell->claim.load() == 0 && !added[cell->row][cell->col]) {
					result.push_back(cell);
					added[cell->row][cell->col] = true;
				}
			}
		}
	}

	return result;
}

// returns a pointer to the lowest-difficulty cell adjacent to a currently owned cell
Cell* chooseLowestCell(Cell (&board)[10][10], int teamNum) {
	Cell* lowest = nullptr;
	// Iterate through each cell in vector returned from getFrontier
	for (Cell* cell : getFrontier(board, teamNum)) {
		// Another thread may have claimed this cell
		if (cell->claim.load() != 0) {
			continue;
		}

		// Return lowest difficulty cell
		if (lowest == nullptr || cell->difficulty < lowest->difficulty) {
			lowest = cell;
		}
	}

	return lowest;
}

// Write a program for each thread that searches the 4 surrounding cells
void threadAlgo(Cell (&board)[10][10], int teamNum, uint64_t startingNum) {
	// Loops until chooseLowestCell returns null ptr (not exactly the same as the board being completely claimed, but good enough for now)
	while (true) {
		Cell *target = chooseLowestCell(board, teamNum);

		if (target == nullptr) {
			break;
		}

		cellClaim(target, teamNum, startingNum);
	}
}

bool gameOver(Cell(&board)[10][10]) {
	bool boardFull = true;

	for (int i = 0; i < ROW_LENGTH; i++) {
		for (int j = 0; j < ROW_LENGTH; j++) {
			if (board[i][j].claim.load() == 0) {
				boardFull = false;
				return boardFull;
			}
		}
	}

	return boardFull;
}

int main() {
	Cell board[10][10];

	// Initialize all board elements to '0'
	for (int i = 0; i < ROW_LENGTH; i++) {
		for (int j = 0; j < ROW_LENGTH; j++) {
			board[i][j].row = i;
			board[i][j].col = j;
			board[i][j].index = i * ROW_LENGTH + j;
		}
	}

	// Set starting points
	board[0][0].claim.store(1);
	board[9][9].claim.store(2);
	
	printBoard(board);

	// Test code
	std::thread t11(threadAlgo, std::ref(board), 1, 0);
	std::thread t12(threadAlgo, std::ref(board), 1, 1);
	std::thread t21(threadAlgo, std::ref(board), 2, 0);
	std::thread t22(threadAlgo, std::ref(board), 2, 1);

	t11.join();
	t12.join();
	t21.join();
	t22.join();

	printBoard(board);
}
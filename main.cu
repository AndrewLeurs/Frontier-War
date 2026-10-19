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

// Integer Scrambler
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
	for (int i = 0; i < ROW_LENGTH; i++) {
		for (int j = 0; j < ROW_LENGTH; j++) {
			std::cout << board[i][j].claim << " ";
		}
		std::cout << "\n";
	}
	std::cout << "\n";
}

// Implements the claiming process for one cell
void cellClaim(Cell* cell, int teamNum) {
	uint64_t attempt = 0;

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
				std::cout << "Team " << teamNum
					<< " claimed cell "
					<< cell->index
					<< " with nonce "
					<< attempt << "\n";

			}

			break;
		}

		attempt++;
	}
}

// returns a vector with every non-owned cell adjacent to an owned cell
std::vector <Cell*> getFrontier(Cell (&board)[10][10], int teamNum) {
	std::vector <Cell*> result;
	// Iterate through each cell and add the cells adjacent to cells with claim = teamNum to the return vector
	for (int row = 0; row < 10; row++) {
		for (int col = 0; col < 10; col++) {
			for (neighbors(board, row, col)) {
				if (Cell)
			}
		}
	}
}

// returns the lowest-difficulty cell adjacent to a currently owned cell
Cell chooseNextCell(Cell currentCell) {

}

// Write a program for each thread that searches the 4 surrounding cells
void threadSearch(Cell (&board)[10][10], int row, int col, int teamNum) {
	// Look at the 4 adjacent cells and see which ones have not been claimed
	std::vector<Cell*> adjacent = neighbors(board, row, col);

	for (Cell* cell : adjacent) {
		if (cell->claim.load() != 0)
			continue;

		cellClaim(cell, teamNum);
	}

	// move to a cell on the border (probably will have to make a new function for that)
}

int main() {
	Cell board[10][10];

	// Initialize all board elements to '*'
	for (int i = 0; i < ROW_LENGTH; i++) {
		for (int j = 0; j < ROW_LENGTH; j++) {
			board[i][j].row = i;
			board[i][j].col = j;
			board[i][j].index = i * ROW_LENGTH + j;
		}
	}
	
	printBoard(board);

	std::thread t1(threadSearch, std::ref(board), 4, 5, 1);
	std::thread t2(threadSearch, std::ref(board), 4, 5, 2);

	t1.join();
	t2.join();

	printBoard(board);
}
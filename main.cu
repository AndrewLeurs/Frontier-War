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
	static std::uniform_int_distribution<> distr(1, 64); // define the range
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
	int index = row * 10 + col;
	int difficulty = randomNumber();
	int correctValue = mix(index) >> (64 - difficulty);
	char face = '*';
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
			std::cout << board[i][j].face;
		}
		std::cout << "\n";
	}
}

// Write a program for each thread that searches the 4 surrounding cells
void threadSearch(Cell (&board)[10][10], int row, int col) {
	// Look at the 4 adjacent cells and see which ones have not been claimed
	std::vector<Cell*> adjacent = neighbors(board, row, col);

	for (Cell* cell : adjacent) {
		if (cell->claim.load() == 0) {
			// TODO: Search for a valid nonce and attempt to claim this cell
		}
	}
	// Try to find correct value for selected cell by checking and incrementing
	// If nonce = correctValue, cell.claimed = true, change face
}

void doWork(std::atomic<int>& i, int expected, int desired) {
	bool success = i.compare_exchange_strong(expected, desired);
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

	Cell c1;
	Cell c2;

	std::thread t1(doWork, std::ref(c1.claim), 0, 1);
	std::thread t2(doWork, std::ref(c1.claim), 0, 2);
	std::thread t3(doWork, std::ref(c2.claim), 0, 1);
	std::thread t4(doWork, std::ref(c2.claim), 0, 2);

	t1.join();
	t2.join();
	t3.join();
	t4.join();

	std::cout << "Cell 1 claim: " << c1.claim.load() << "\n";
	std::cout << "Cell 2 claim: " << c2.claim.load() << "\n";

	return 0;
}
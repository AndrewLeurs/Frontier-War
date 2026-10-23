#include <iostream>
#include <iterator>
#include <cstdint>
#include <random>
#include <atomic>
#include <thread>
#include <functional>
#include <vector>
#include <SFML/Graphics.hpp>
#include <chrono>

#define ROW_LENGTH 10

// Returns a random int between 1 & whatever I decide
int randomNumber() {
	static std::random_device rd; // obtain a random number from hardware
	static std::mt19937 gen(rd()); // seed the generator
	static std::uniform_int_distribution<> distr(12, 28); // define the range
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
    std::atomic<bool>  isBeingAttempted = false;
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

void displayBoard(sf::RenderWindow& window, Cell (&board)[10][10]) {
    // Load the font
    static sf::Font font;
    static bool fontLoaded = false;

    if (!fontLoaded) {
        if (!font.openFromFile("Basic-Regular.ttf")) {
            std::cerr << "Failed to load font!\n";
            return;
        }

        fontLoaded = true;
    }

    float cellSize = 60.f;
    float spacing = 5.f;
    float startX = 300.f;
    float startY = 75.f;

    for (int row = 0; row < 10; row++) {
        for (int col = 0; col < 10; col++) {
            // Calculate the square's position
            float x = startX + col * (cellSize + spacing);
            float y = startY + row * (cellSize + spacing);

            // Draw the square
            sf::RectangleShape square({cellSize, cellSize});
            square.setPosition({x, y});

            int owner = board[row][col].claim.load();

            if (owner == 0) {
                square.setFillColor(sf::Color(100, 100, 100));
            } else if (owner == 1) {
                square.setFillColor(sf::Color::Blue);
            } else if (owner == 2) {
                square.setFillColor(sf::Color::Red);
            }

            if (board[row][col].isBeingAttempted) {
                square.setOutlineColor(sf::Color::Yellow);
                square.setOutlineThickness(4.f);
            }
            else {
                square.setOutlineThickness(0.f);
            }

            window.draw(square);

            // Convert the difficulty number to text
            sf::Text difficultyText(font);
            difficultyText.setString(
                std::to_string(board[row][col].difficulty)
            );
            difficultyText.setCharacterSize(20);
            difficultyText.setFillColor(sf::Color::White);

            // Center the text inside the square
            sf::FloatRect textBounds = difficultyText.getLocalBounds();

            difficultyText.setOrigin({
                textBounds.position.x + textBounds.size.x / 2.f,
                textBounds.position.y + textBounds.size.y / 2.f
            });

            difficultyText.setPosition({
                x + cellSize / 2.f,
                y + cellSize / 2.f
            });

            window.draw(difficultyText);
        }
    }
}

void displayInfoPanel(
    sf::RenderWindow& window,
    Cell (&board)[10][10],
    const sf::Font& font,
    long long elapsedSeconds
) {
    int team1Count = 0;
    int team2Count = 0;
    int unclaimedCount = 0;

    // Count the cells owned by each team
    for (int row = 0; row < 10; row++) {
        for (int col = 0; col < 10; col++) {
            int owner = board[row][col].claim.load();

            if (owner == 1) {
                team1Count++;
            } else if (owner == 2) {
                team2Count++;
            } else {
                unclaimedCount++;
            }
        }
    }

    // Draw the panel background
    sf::RectangleShape panel({240.f, 300.f});
    panel.setPosition({25.f, 75.f});
    panel.setFillColor(sf::Color(45, 45, 45));
    panel.setOutlineColor(sf::Color(100, 100, 100));
    panel.setOutlineThickness(2.f);

    window.draw(panel);

    // Helper for drawing text
    auto drawLine = [&](const std::string& text,
                        unsigned int size,
                        sf::Vector2f position,
                        sf::Color color) {
        sf::Text label(font);
        label.setString(text);
        label.setCharacterSize(size);
        label.setFillColor(color);
        label.setPosition(position);

        window.draw(label);
    };

    // Panel heading
    drawLine("FRONTIER WAR", 24, {45.f, 95.f},
             sf::Color::White);

    // Team statistics
    drawLine("Team 1", 20, {45.f, 155.f},
             sf::Color::Blue);

    drawLine(std::to_string(team1Count) + " cells", 18,
             {45.f, 185.f}, sf::Color::White);

    drawLine("Team 2", 20, {45.f, 230.f},
             sf::Color::Red);

    drawLine(std::to_string(team2Count) + " cells", 18,
             {45.f, 260.f}, sf::Color::White);

    // Remaining cells
    drawLine("Unclaimed", 20, {45.f, 310.f},
             sf::Color(200, 200, 200));

    drawLine(std::to_string(unclaimedCount) + " cells", 18,
             {45.f, 340.f}, sf::Color::White);

    // Format elapsed time as MM:SS
    long long minutes = elapsedSeconds / 60;
    long long seconds = elapsedSeconds % 60;

    std::string timeString =
        (minutes < 10 ? "0" : "") + std::to_string(minutes)
        + ":"
        + (seconds < 10 ? "0" : "") + std::to_string(seconds);

    drawLine("Elapsed Time", 20, {45.f, 390.f},
             sf::Color::White);

    drawLine(timeString, 24, {45.f, 420.f},
             sf::Color(255, 220, 80));
}

// Implements the claiming process for one cell
void cellClaim(Cell* cell, int teamNum, uint64_t startingNum) {
	uint64_t attempt = startingNum;
    cell->isBeingAttempted = true;

	while (true) {
		if (cell->claim.load() != 0) {
			break;
		}

		uint64_t hash = mix(attempt + cell->index);

		bool valid = (hash >> (64 - cell->difficulty)) == 0;

		if (valid) {
			int expected = 0;
			bool success = cell->claim.compare_exchange_strong(expected, teamNum);

            if(success){
                cell->isBeingAttempted = false;
                std::this_thread::sleep_for(std::chrono::milliseconds(500));
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

    // Initialize all board elements
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

    // Create the SFML window
    sf::RenderWindow window(
        sf::VideoMode({1050, 800}),
        "Frontier War"
    );

    auto startTime = std::chrono::steady_clock::now();

    std::chrono::steady_clock::time_point endTime;
    bool gameFinished = false;

    // Launch the worker threads
    std::thread t11(threadAlgo, std::ref(board), 1, 0);
    std::thread t12(threadAlgo, std::ref(board), 1, 1);
    std::thread t21(threadAlgo, std::ref(board), 2, 0);
    std::thread t22(threadAlgo, std::ref(board), 2, 1);

    sf::Font infoFont;

    if (!infoFont.openFromFile("Basic-Regular.ttf")) {
        std::cerr << "Failed to load Basic-Regular.ttf\n";
        return 1;
    }

    // Main loop: handle events and display the board
    while (window.isOpen()) {

        // Handle window events
        while (const auto event = window.pollEvent()) {
            if (event->is<sf::Event::Closed>()) {
                window.close();
            }
        }

        // Clear the previous frame
        window.clear(sf::Color(30, 30, 30));

        // Check whether the game has ended
        if (!gameFinished && gameOver(board)) {
            endTime = std::chrono::steady_clock::now();
            gameFinished = true;
        }

        // Calculate elapsed time
        auto currentTime = gameFinished
            ? endTime
            : std::chrono::steady_clock::now();

        long long elapsedSeconds =
            std::chrono::duration_cast<std::chrono::seconds>(
                currentTime - startTime
            ).count();

        // Draw the info panel
        displayInfoPanel(window, board, infoFont, elapsedSeconds);

        // Draw the current board state
        displayBoard(window, board);

        // Display the completed frame
        window.display();
    }

    // Wait for worker threads to finish
    t11.join();
    t12.join();
    t21.join();
    t22.join();

    return 0;
}

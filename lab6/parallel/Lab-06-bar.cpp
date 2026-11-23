#include <atomic>
#include <barrier>
#include <charconv>
#include <iostream>
#include <latch>
#include <random>
#include <stdexcept>
#include <string_view>
#include <thread>
#include <vector>

static int positive(std::string_view s, int limit)
{
    int value = 0;
    const auto [end, error] = std::from_chars(s.data(), s.data() + s.size(), value);
    if (error != std::errc{} || end != s.data() + s.size() || value < 1 || value > limit)
        throw std::invalid_argument("parameter outside supported range");
    return value;
}

int main(int argc, char **argv)
{
    try {
        if (argc != 4)
            throw std::invalid_argument("usage: Lab-06-bar THREADS MATRICES SIZE");
        const int workers = positive(argv[1], 256);
        const int count = positive(argv[2], 10000000);
        const int size = positive(argv[3], 10000);
        const auto cells = static_cast<std::size_t>(size) * size;
        constexpr std::size_t max_values = 10000000;
        if (cells > max_values || static_cast<std::size_t>(count) > max_values / cells ||
            static_cast<std::size_t>(workers) > max_values / cells)
            throw std::invalid_argument("matrix data or worker buffers exceed 10 million entries");
        std::mt19937 rng(42);
        std::uniform_int_distribution<int> value(-2000, 2000);
        std::vector<int> matrices(cells * count);
        for (auto &entry : matrices)
            entry = value(rng);
        std::vector<std::vector<long long>> partial(workers, std::vector<long long>(cells));
        std::vector<std::atomic<long long>> total(cells);
        std::barrier phase(static_cast<std::ptrdiff_t>(workers));
        std::latch start(1);
        bool abort_start = false;
        std::vector<std::jthread> threads;
        threads.reserve(workers);
        try {
            for (int id = 0; id < workers; ++id) {
                threads.emplace_back([&, id] {
                    start.wait();
                    if (abort_start)
                        return;
                    for (int m = id; m < count; m += workers) {
                        for (std::size_t k = 0; k < cells; ++k)
                            partial[id][k] += matrices[static_cast<std::size_t>(m) * cells + k];
                    }
                    phase.arrive_and_wait();
                    for (std::size_t k = 0; k < cells; ++k)
                        total[k].fetch_add(partial[id][k], std::memory_order_relaxed);
                    phase.arrive_and_wait();
                });
            }
        } catch (...) {
            abort_start = true;
            start.count_down();
            throw;
        }
        start.count_down();
        for (auto &thread : threads)
            thread.join();
        std::cout << "threads=" << workers << " matrices=" << count << " size=" << size << " seed=42\n";
        for (std::size_t k = 0; k < cells; ++k) {
            long long reference = 0;
            for (int m = 0; m < count; ++m)
                reference += matrices[static_cast<std::size_t>(m) * cells + k];
            const auto result = total[k].load(std::memory_order_relaxed);
            if (reference != result)
                throw std::logic_error("parallel result differs from serial reference");
            std::cout << result << ((k + 1) % size ? ' ' : '\n');
        }
        std::cout << "serial check: OK\n";
        return 0;
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}

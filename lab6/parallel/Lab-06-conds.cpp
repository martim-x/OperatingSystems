#include <charconv>
#include <chrono>
#include <deque>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <random>
#include <stdexcept>
#include <string_view>
#include <thread>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#else
#include <pthread.h>
#endif

using Clock = std::chrono::steady_clock;
using namespace std::chrono_literals;

static void check(bool ok)
{
    if (!ok) std::terminate();
}

struct Mutex {
#ifdef _WIN32
    CRITICAL_SECTION native;
    Mutex() { InitializeCriticalSection(&native); }
    ~Mutex() { DeleteCriticalSection(&native); }
    void lock() { EnterCriticalSection(&native); }
    void unlock() { LeaveCriticalSection(&native); }
#else
    pthread_mutex_t native = PTHREAD_MUTEX_INITIALIZER;
    ~Mutex() { check(pthread_mutex_destroy(&native) == 0); }
    void lock() { check(pthread_mutex_lock(&native) == 0); }
    void unlock() { check(pthread_mutex_unlock(&native) == 0); }
#endif
};

struct Condition {
#ifdef _WIN32
    CONDITION_VARIABLE native = CONDITION_VARIABLE_INIT;
    void wait(Mutex &m) { check(SleepConditionVariableCS(&native, &m.native, INFINITE) != 0); }
    void wake() { WakeConditionVariable(&native); }
#else
    pthread_cond_t native = PTHREAD_COND_INITIALIZER;
    ~Condition() { check(pthread_cond_destroy(&native) == 0); }
    void wait(Mutex &m) { check(pthread_cond_wait(&native, &m.native) == 0); }
    void wake() { check(pthread_cond_signal(&native) == 0); }
#endif
};

struct Stats {
    unsigned long long count = 0, last_count = 0;
    double delay_ms = 0, ended = 0;
    Clock::time_point first{}, last{};
    void record(Clock::time_point now, double delay)
    {
        if (!count) first = now;
        last = now;
        ++count;
        delay_ms += delay;
    }
};

class Buffer {
    const std::size_t capacity;
    const Clock::time_point start = Clock::now();
    Mutex mutex;
    Condition nonempty, nonfull;
    std::deque<unsigned long long> queue;
    bool stopping = false, producer_done = false;
    Stats produced, consumed;
    unsigned long long removed = 0, last_removed = 0;
    double last_report = 0;

    static double seconds(Clock::duration d) { return std::chrono::duration<double>(d).count(); }

public:
    explicit Buffer(std::size_t cap) : capacity(cap) {}

    void produce(int lo, int hi)
    {
        std::mt19937 rng(42);
        std::uniform_int_distribution<int> delay(lo, hi);
        for (;;) {
            {
                std::lock_guard lock(mutex);
                while (queue.size() == capacity && !stopping) {
                    std::cout << "producer waits (full)\n";
                    nonfull.wait(mutex);
                    std::cout << "producer wakes\n";
                }
                if (stopping) break;
                queue.push_back(produced.count + 1);
                produced.record(Clock::now(), 0);
                std::cout << "added=" << produced.count << " buffer=" << queue.size() << '\n';
                nonempty.wake();
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(delay(rng)));
        }
        std::lock_guard lock(mutex);
        producer_done = true;
        produced.ended = seconds(Clock::now() - start);
        nonempty.wake();
    }

    void consume(int lo, int hi)
    {
        std::mt19937 rng(43);
        std::uniform_int_distribution<int> delay(lo, hi);
        for (;;) {
            unsigned long long item;
            {
                std::lock_guard lock(mutex);
                while (queue.empty() && !producer_done) {
                    std::cout << "consumer waits (empty)\n";
                    nonempty.wait(mutex);
                    std::cout << "consumer wakes\n";
                }
                if (queue.empty()) break;
                item = queue.front();
                queue.pop_front();
                ++removed;
                std::cout << "removed=" << item << " buffer=" << queue.size() << '\n';
                nonfull.wake();
            }
            const auto begin = Clock::now();
            std::this_thread::sleep_for(std::chrono::milliseconds(delay(rng)));
            const auto end = Clock::now();
            std::lock_guard lock(mutex);
            consumed.record(end, seconds(end - begin) * 1000);
        }
        std::lock_guard lock(mutex);
        consumed.ended = seconds(Clock::now() - start);
    }

    void stop()
    {
        std::lock_guard lock(mutex);
        stopping = true;
        nonfull.wake();
    }

    void report()
    {
        std::lock_guard lock(mutex);
        const double elapsed = seconds(Clock::now() - start);
        const auto added = produced.count - produced.last_count;
        const auto taken = removed - last_removed;
        const double period = elapsed - last_report;
        std::cout << std::fixed << std::setprecision(2)
                  << "stats elapsed=" << elapsed << "s produced=" << produced.count
                  << " consumed=" << removed << " buffer=" << queue.size()
                  << " fill=" << 100.0 * queue.size() / capacity << "%\n"
                  << "  producer count=" << added << " mean_interval_ms="
                  << (produced.count > 1 ? seconds(produced.last - produced.first) * 1000 / (produced.count - 1) : 0)
                  << " speed=" << added / period << "/s total_s=" << (producer_done ? produced.ended : elapsed) << '\n'
                  << "  consumer count=" << taken << " mean_processing_ms="
                  << (consumed.count ? consumed.delay_ms / consumed.count : 0)
                  << " speed=" << taken / period << "/s total_s=" << (consumed.ended ? consumed.ended : elapsed) << '\n';
        produced.last_count = produced.count;
        last_removed = removed;
        last_report = elapsed;
    }

    int finish()
    {
        std::cout << "final produced=" << produced.count << " consumed=" << consumed.count
                  << " buffer=" << queue.size() << '\n';
        return queue.empty() && produced.count == consumed.count ? 0 : 1;
    }
};

static int number(std::string_view s, int lo, int hi)
{
    int v = 0;
    const auto [end, err] = std::from_chars(s.data(), s.data() + s.size(), v);
    if (err != std::errc{} || end != s.data() + s.size() || v < lo || v > hi)
        throw std::invalid_argument("integer argument is outside the supported range");
    return v;
}

int main(int argc, char **argv)
{
    try {
        if (argc != 6 && (argc != 8 || std::string_view(argv[6]) != "--seconds"))
            throw std::invalid_argument("usage: Lab-06-conds CAPACITY PROD_MIN_MS PROD_MAX_MS CONS_MIN_MS CONS_MAX_MS [--seconds N]");
        const int cap = number(argv[1], 1, 10000);
        const int p0 = number(argv[2], 0, 10000), p1 = number(argv[3], p0, 10000);
        const int c0 = number(argv[4], 0, 10000), c1 = number(argv[5], c0, 10000);
        const auto duration = std::chrono::seconds(argc == 8 ? number(argv[7], 1, 3600) : 15);
        std::cout << std::unitbuf << "user=User-6d4ec851 buffer=0 capacity=" << cap << '\n';
        Buffer buffer(cap);
        const auto start = Clock::now();
        std::jthread producer([&] { buffer.produce(p0, p1); });
        std::jthread consumer;
        try {
            consumer = std::jthread([&] { buffer.consume(c0, c1); });
            for (auto tick = 5s; tick <= duration; tick += 5s) {
                std::this_thread::sleep_until(start + tick);
                buffer.report();
            }
            std::this_thread::sleep_until(start + duration);
            buffer.stop();
            producer.join();
            consumer.join();
        } catch (...) {
            buffer.stop();
            throw;
        }
        return buffer.finish();
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}

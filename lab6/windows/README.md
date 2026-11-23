# Lab 06 for Windows

The directory contains four Win32 C programs:

- `Lab-06a.c`: main thread plus workers A/B; `CRITICAL_SECTION` protects each worker's entire inclusive 30..60 interval.
- `Lab-06b.c`: main process plus A/B child processes, each in a new console; a named mutex protects the same interval.
- `Lab-06c.c`: same process layout; a named semaphore with initial/max count 1 protects the interval.
- `Lab-06d.c`: main plus A/B child processes, each in a new console; children wait on an initially nonsignaled manual-reset event. The parent signals after finishing iterations 1..15, just before iteration 16. All three perform 1000 iterations.

Default delay is 100 ms per iteration. Build from this directory with `build.cmd` in a Visual Studio Developer Command Prompt, or let the script locate the installed Visual Studio toolchain. Outputs go under ignored `tools/`.

Run a program directly, for example `tools\Lab-06b.exe`. `--test-delay-ms N` is a test-only override (0..1000 ms); omit it for the required 100 ms default. `--log-file PATH` is an optional structured trace used by the integration test.

Build and run all four zero-delay integration checks with:

```text
build.cmd
python test_lab06.py
```

The test-only delay override is explicit in the command and displayed in each console; it does not change the default behavior.

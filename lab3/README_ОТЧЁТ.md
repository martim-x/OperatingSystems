# Operating Systems — Laboratory Work No. 3
## PROCESS MANAGEMENT

**Discipline:** Operating Systems  
**Lab:** #3 — Process Management  
**Student:** Marushko T.F., 3rd year, Group 2  
**Platforms:** Linux (Arch Linux ARM, GCC 16.1.1) & Windows 11 ARM (MSVC 19.42)

---

## 1. THEORY

### 1.1 Process Concept
A **process** is a program in execution. It consists of:
- **Code segment** (text): executable instructions
- **Data segment**: global/static variables
- **Heap**: dynamic memory allocation
- **Stack**: function calls, local variables
- **Process Control Block (PCB)**: kernel data structure containing PID, state, priority, registers, memory pointers, open files, etc.

**Process vs Program**: A program is a passive executable file on disk. A process is an active entity with its own address space and resources.

### 1.2 Process Creation
| OS | System Call | Wrapper |
|----|-------------|---------|
| Linux | `clone()` / `fork()` | `fork()`, `vfork()` |
| Windows | `NtCreateProcess()` | `CreateProcess()` |

**Linux**: `fork()` creates a child process as a copy of the parent. `exec()` replaces the process image with a new program.
**Windows**: `CreateProcess()` creates a new process and loads the executable in one call.

### 1.3 Process Termination
- **Normal**: `exit()` / `ExitProcess()`, return from `main`
- **Abnormal**: signal (Linux), exception (Windows), `abort()`, `TerminateProcess()`

### 1.4 Inter-Process Communication (IPC)
| Mechanism | Linux | Windows | Type |
|-----------|-------|---------|------|
| Anonymous Pipe | `pipe()` | `CreatePipe()` | Byte stream, parent-child |
| Named Pipe | `mkfifo()` | `CreateNamedPipe()` | Byte stream, any processes |
| Signals | `signal()`, `sigaction()` | Console Ctrl handlers | Async notification |
| Shared Memory | `shmget()` / `mmap()` | `CreateFileMapping()` | Fastest, requires sync |
| Sockets | `socket()` | `WSASocket()` | Network, local (Unix domain) |

### 1.5 Process Inspection Tools
| Tool | Linux | Windows |
|------|-------|---------|
| Process list | `ps`, `top`, `htop` | Task Manager, `tasklist` |
| Process tree | `ps -ef`, `pstree` | Process Explorer |
| Process details | `/proc/<PID>/` | Process Explorer, `GetProcessInfo` |
| Handles | `ls -l /proc/<PID>/fd/` | Process Explorer → Handle view |

---

## 2. WHAT WAS DONE

### 2.1 Linux Implementation (Level 4–5, 7–8, 9–10)

| Program | Description | Level |
|---------|-------------|-------|
| **Lab-03x** | Child process: loop with 500ms delay, prints PID. Iterations from argv or ITER_NUM env. Supports `--pause` / `PAUSE_ON_EXIT=1` for inspection. | 4–5 |
| **Lab-03a** | Parent forks 2 children running Lab-03x: 1st gets iterations via arg (5), 2nd via ITER_NUM=8. Parent waits with `waitpid()`. | 4–5 |
| **Lab-03d-client** | Finds numbers coprime to M in range [L, R]. Outputs `CHUNK PID count 0 numbers...` to stdout (redirected to pipe). | 7–8 |
| **Lab-03d-server** | Creates pipe, splits range into K parts, forks K clients, collects results via pipe, prints merged list + time. | 7–8 |
| **Lab-03sig** | Installs SIGINT handler that re-arms itself. Prints status every second. Unkillable by Ctrl+C (only SIGTERM/SIGKILL). | 9–10 |

**Key features:**
- All programs support `PAUSE_ON_EXIT=1` or `--pause` to wait for Enter before exit
- This allows viewing processes in `ps`, `htop`, Process Explorer, Task Manager
- Clean code without excessive comments

### 2.2 Windows Implementation (Level 4–5, 7–8, 9–10)

| Program | Description | Level |
|---------|-------------|-------|
| **Lab-03x** | Child: loop with 500ms delay, `ExitProcess`. Iterations from argv or ITER_NUM. Supports `--pause` / `PAUSE_ON_EXIT=1`. | 4–5 |
| **Lab-03a** | Three `CreateProcess` variants: (1) lpApplicationName with arg (fails, error 2), (2) lpCommandLine only, (3) both with leading space. | 4–5 |
| **Lab-03b** | Environment variants: (1) global ITER_NUM, (2) argv arg, (3) local ITER_NUM via `SetEnvironmentVariable`. | 4–5 |
| **Lab-03c** | Lists all processes via Tool Help Library (`CreateToolhelp32Snapshot`): name, PID, PPID. | 4–5 |
| **Lab-03d-client** | Coprime search, outputs to stdout (redirected to inheritable pipe handle). | 7–8 |
| **Lab-03d-server** | `CreatePipe` with inheritable handles, `STARTUPINFO.hStdOutput`, `WaitForMultipleObjects`. | 7–8 |
| **Lab-03hello-parent** | Passes "Hello, my dear child!" via `STARTUPINFO.lpTitle` + `CREATE_NEW_CONSOLE`. | 9–10 |
| **Lab-03hello-child** | Reads console title via `GetConsoleTitle`, prints it. | 9–10 |

**Key Windows findings (empirical):**
- `lpApplicationName` alone with arguments → error 2 (file not found)
- Only `lpCommandLine` or `lpApplicationName` + `lpCommandLine` (with leading space) work
- `lpTitle` only works with `CREATE_NEW_CONSOLE`
- Inheritable pipe handles passed via `STARTUPINFO.hStdOutput` + `STARTF_USESTDHANDLES`

---

## 3. DIRECTORY STRUCTURE

```
lab3/
├── linux/
│   ├── Lab-03x.c
│   ├── Lab-03a.c
│   ├── Lab-03d-client.c
│   ├── Lab-03d-server.c
│   ├── Lab-03sig.c
│   ├── build/              # Compiled binaries (gitignored)
│   ├── скрины/             # Screenshots per level
│   │   ├── уровень_4-5/
│   │   ├── уровень_7-8/
│   │   └── уровень_9-10/
│   └── выводы/             # Text outputs per level
│       ├── уровень_4-5/
│       ├── уровень_7-8/
│       └── уровень_9-10/
├── windows/
│   ├── Lab-03x.c
│   ├── Lab-03a.c
│   ├── Lab-03b.c
│   ├── Lab-03c.c
│   ├── Lab-03d-client.c
│   ├── Lab-03d-server.c
│   ├── Lab-03hello-parent.c
│   ├── Lab-03hello-child.c
│   ├── console_ru.h        # UTF-8 → OEM 866 for Cyrillic
│   ├── build.cmd           # MSVC build script
│   ├── скрины/             # Screenshots per level
│   └── выводы/             # Text outputs per level
├── README.md               # This file
├── lab3_EN.md              # English version of full report
└── REBUILD_PLAN.md         # Rebuild plan with estimation
```

---

## 4. BUILD & RUN

### Linux
```bash
cd lab3/linux
mkdir -p build
gcc -O2 -Wall -o build/Lab-03x Lab-03x.c
gcc -O2 -Wall -o build/Lab-03a Lab-03a.c
gcc -O2 -Wall -o build/Lab-03d-client Lab-03d-client.c
gcc -O2 -Wall -o build/Lab-03d-server Lab-03d-server.c
gcc -O2 -Wall -o build/Lab-03sig Lab-03sig.c

# Run examples
./build/Lab-03x 5
ITER_NUM=7 ./build/Lab-03x
PAUSE_ON_EXIT=1 ./build/Lab-03a
./build/Lab-03d-client 10 1 30
./build/Lab-03d-server 3 10 1 100
./build/Lab-03sig
```

### Windows (Developer Command Prompt, ARM64)
```cmd
cd lab3\windows
build.cmd

# Run examples
Lab-03x.exe 5
set ITER_NUM=7 && Lab-03x.exe
Lab-03a.exe 3
Lab-03b.exe 3
Lab-03c.exe
Lab-03d-client.exe 10 1 30
Lab-03d-server.exe 3 10 1 100
Lab-03hello-parent.exe
```

**For Process Explorer / Task Manager inspection:**
```bash
# Linux
PAUSE_ON_EXIT=1 ./build/Lab-03a
# In another terminal: ps -ef | grep Lab-03x

# Windows
set PAUSE_ON_EXIT=1 && Lab-03a.exe 3
# Open Process Explorer / Task Manager, find Lab-03x.exe processes
```

---

## 5. DEFENSE QUESTIONS & ANSWERS

### 5.1 Self-Control Questions (from lab specification)

**Q1: What is a process? How does a process differ from a program?**
- **Process**: Active entity, program in execution, has PCB, address space, resources, state.
- **Program**: Passive executable file on disk, static code + data.

**Q2: What resources are available to a process?**
- Memory (code, data, heap, stack), open files, sockets, signals, timers, CPU time, synchronization objects, environment variables, current directory, resource limits.

**Q3: What are child and parent processes? How are they related?**
- Parent creates child via `fork()`/`CreateProcess()`. Child inherits: file descriptors (Linux), handles (Windows with inheritance), environment, current directory. Parent gets child's PID, can wait for termination, receives exit code.

**Q4: What is a system call? Why is it needed?**
- Controlled transition from user mode to kernel mode. Provides hardware access, resource management, security/isolation. User programs cannot execute privileged instructions directly.

**Q5: What system calls create processes in Windows/Linux?**
- Linux: `clone()` (low-level), `fork()`, `vfork()`
- Windows: `NtCreateProcess()` / `NtCreateProcessEx()` (native), `CreateProcess()` (WinAPI)

**Q6: What WinAPI/POSIX functions relate to these system calls?**
- Linux: `fork()`, `vfork()`, `exec()` family, `clone()` (glibc wrapper), `posix_spawn()`
- Windows: `CreateProcess()`, `CreateProcessAsUser()`, `CreateProcessWithLogonW()`, `ShellExecuteEx()`

**Q7: How many new processes from `fork(); fork(); fork();`?**
- 2³ = 8 total processes (1 original + 7 children). Each fork doubles the count.

**Q8: What is `exec` for?**
- Replaces current process image with new program. Loads code/data from executable, resets stack/heap, keeps PID, open FDs (unless FD_CLOEXEC), signal handlers reset to default.

**Q9: What is IPC? (Level 7–8)**
- Mechanisms for processes to exchange data and synchronize. Categories: pipes (anonymous/named), shared memory, message queues, signals, sockets, semaphores, mutexes.

**Q10: What IPC groups/mechanisms do you know? (Level 7–8)**
- **Pipes**: anonymous (parent-child), named (any processes)
- **Shared Memory**: fastest, requires synchronization
- **Message Queues**: structured data, kernel-buffered
- **Signals**: async notification, limited data
- **Sockets**: bidirectional, network-transparent
- **Semaphores/Mutexes**: synchronization primitives

**Q11: Which IPC for maximum speed? (Level 7–8)**
- **Shared memory** — direct memory access, no kernel copy overhead. Requires explicit synchronization (semaphores/mutexes).

**Q12: Which IPC for fault tolerance? (Level 7–8)**
- **Message queues** or **pipes** — kernel-buffered, sender/receiver lifecycles independent, data persists until read.

**Q13: What signals exist in Linux? Examples? (Level 9–10)**
- `SIGINT` (Ctrl+C, terminate), `SIGTERM` (graceful shutdown), `SIGKILL` (force kill, uncatchable), `SIGSEGV` (segfault), `SIGCHLD` (child state change), `SIGPIPE` (broken pipe), `SIGALRM` (timer), `SIGHUP` (hangup), `SIGUSR1/2` (user-defined).

**Q14: How to handle a signal in a process? (Level 9–10)**
- `signal(sig, handler)` — simple, but handler resets (historical). `sigaction()` — preferred, persistent handler, can block signals during handler, pass siginfo.

**Q15: Kernel structures describing a process? (Level 9–10)**
- Linux: `task_struct` (sched.h) — PID, state, mm_struct, files_struct, signal_struct, cred, etc.
- Windows: `EPROCESS` (ntoskrnl) — PID, token, object table, VAD tree, thread list, PEB pointer.

**Q16: How to view these structures? (Level 9–10)**
- Linux: `/proc/<PID>/` (status, maps, fd, environ), `ps`, `top`, `crash`/`gdb` on kernel dump
- Windows: Process Explorer (handles, threads, memory), WinDbg (`!process`, `!thread`), `GetProcessInformation` API

---

## 6. SCREENSHOTS & OUTPUTS

All screenshots organized by level in `скрины/уровень_*/` and text outputs in `выводы/уровень_*/`.

**Linux (12 screenshots):**
- Level 4–5: build, Lab-03x arg/env/error, Lab-03a parallel, ps tree, /proc status, /proc dir, final ls
- Level 7–8: client, server K=3, server K=4
- Level 9–10: Lab-03sig SIGINT demo

**Windows (12 screenshots):**
- Level 4–5: build, Lab-03x arg/env/error, Lab-03a 3 variants, Lab-03b env variants, Lab-03c process list
- Level 7–8: client, server K=3, server K=4
- Level 9–10: hello-parent/child demo, final exe list

---

## 7. CONCLUSION

Lab 3 completed at **maximum level (9–10)** on both platforms.

**Linux**: 5 programs — process creation (fork/exec), IPC (pipe), signal handling. All tested with `PAUSE_ON_EXIT` for live inspection.

**Windows**: 8 programs — CreateProcess variants, environment inheritance, Tool Help Library, pipe via STARTUPINFO, lpTitle trick. All tested with Process Explorer / Task Manager.

**Standardized format**: Clean code, pause mechanism, unified directory structure, bilingual README.
$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Ct {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CreateProcessW(string app, string cmd, IntPtr pa, IntPtr ta, bool inherit,
        uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll")] public static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll")] public static extern bool FreeConsole();
    [DllImport("kernel32.dll")] public static extern bool GenerateConsoleCtrlEvent(uint evt, uint group);
    [DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll")] public static extern bool GetExitCodeProcess(IntPtr h, out uint code);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);

    public static string Run(string cmdline, string workdir, int waitMs) {
        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(si);
        PROCESS_INFORMATION pi;
        if (!CreateProcessW(null, cmdline, IntPtr.Zero, IntPtr.Zero, false, 0x00000210, IntPtr.Zero, workdir, ref si, out pi))
            return "CREATE-FAIL " + Marshal.GetLastWin32Error();
        System.Threading.Thread.Sleep(waitMs);
        FreeConsole();
        bool att = AttachConsole((uint)pi.dwProcessId);
        bool sent = att && GenerateConsoleCtrlEvent(1, (uint)pi.dwProcessId);
        System.Threading.Thread.Sleep(300);
        FreeConsole();
        uint w = WaitForSingleObject(pi.hProcess, 20000);
        uint code = 0;
        GetExitCodeProcess(pi.hProcess, out code);
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        return "attach=" + att + " ctrlc=" + sent + " wait=" + w + " exit=" + code;
    }
}
"@

$res = [Ct]::Run('cmd.exe /c "C:\lab4\Lab-04pi.exe 4 2000 > C:\lab4\pi.txt 2>&1"', "C:\lab4", 6000)
Set-Content -Path "C:\lab4\pi_test.log" -Value $res -Encoding UTF8

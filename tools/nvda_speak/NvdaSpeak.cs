using System;
using System.Runtime.InteropServices;

// Tiny CLI bridge between Godot (which has no native FFI) and NVDA's
// official controller client DLL. Godot calls this via OS.execute and reads
// the exit code to decide whether NVDA actually spoke the line, falling
// back to its own pre-recorded voice clips if not.
//
// Exit codes: 0 = spoken via NVDA, 1 = NVDA not running, 2 = bad arguments,
// 3 = NVDA running but the speak call itself failed.
class NvdaSpeak
{
    [DllImport("nvdaControllerClient64.dll")]
    static extern int nvdaController_testIfRunning();

    [DllImport("nvdaControllerClient64.dll")]
    static extern int nvdaController_speakText([MarshalAs(UnmanagedType.LPWStr)] string text);

    static int Main(string[] args)
    {
        if (args.Length < 1 || string.IsNullOrWhiteSpace(args[0]))
        {
            return 2;
        }
        string text = string.Join(" ", args);
        if (nvdaController_testIfRunning() != 0)
        {
            return 1;
        }
        return nvdaController_speakText(text) == 0 ? 0 : 3;
    }
}

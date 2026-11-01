using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Toolkit.Desktop;

public interface IProcessTransport
{
    Task<ProcessResult> ExecuteAsync(ProcessStartInfo startInfo, Action<OutputLine> onLine, CancellationToken cancellationToken);
}

public sealed class ProcessTransport(Func<string, CancellationToken, Task<string>>? answerPrompt = null) : IProcessTransport
{
    public async Task<ProcessResult> ExecuteAsync(ProcessStartInfo startInfo, Action<OutputLine> onLine, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        using var process = new Process { StartInfo = startInfo };
        var output = new StringBuilder();
        var sync = new object();
        var hadErrors = false;
        var cancelled = false;
        if (!process.Start()) throw new IOException("Windows could not start the command worker.");
        if (!startInfo.RedirectStandardOutput)
        {
            // A real console keeps native program input (including WinGet) intact.
            // Never terminate installers or repairs when the desktop token is cancelled.
            await process.WaitForExitAsync().ConfigureAwait(false);
            return new(process.ExitCode, "", false, false);
        }
        startInfo.Environment.TryGetValue("TOOLKIT_DESKTOP_CHANNEL", out var channel);
        var prefix = string.IsNullOrEmpty(channel) ? null : "@@TOOLKIT_PROMPT:" + channel + ":";
        if (prefix == null) process.StandardInput.Close();
        using var lifetime = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        void StopWorker()
        {
            try { if (!process.HasExited) process.Kill(); }
            catch (InvalidOperationException) { } catch (System.ComponentModel.Win32Exception) { }
        }
        async Task Drain(StreamReader reader, bool error)
        {
            while (await reader.ReadLineAsync().ConfigureAwait(false) is { } raw)
            {
                if (!error && prefix != null && raw.StartsWith(prefix, StringComparison.Ordinal))
                {
                    if (answerPrompt == null) throw new InvalidOperationException("This command is waiting for an answer, but the desktop answer box is unavailable.");
                    if (raw.Length > 100_000) throw new InvalidDataException("The command question is too long.");
                    var question = Encoding.UTF8.GetString(Convert.FromBase64String(raw[prefix.Length..]));
                    var answer = await answerPrompt(question, lifetime.Token).ConfigureAwait(false);
                    if (answer.Length > 16_000 || answer.Contains('\n') || answer.Contains('\r'))
                        throw new InvalidDataException("Enter a single line as the answer.");
                    // Encoding transports text only. Nothing here evaluates an answer as PowerShell.
                    await process.StandardInput.WriteLineAsync(Convert.ToBase64String(Encoding.UTF8.GetBytes(answer))).ConfigureAwait(false);
                    await process.StandardInput.FlushAsync().ConfigureAwait(false);
                    raw = question + ": " + answer;
                }
                // Clear-Host can emit terminal controls; WPF displays plain text.
                var text = Regex.Replace(raw, @"\x1B\[[0-?]*[ -/]*[@-~]", "").Replace("\0", "");
                if (text.Length == 0) continue;
                lock (sync)
                {
                    hadErrors |= error;
                    if (output.Length < 1_000_000) output.AppendLine((error ? "[stderr] " : "") + text);
                }
                onLine(new(text, error));
            }
        }
        var stdout = Drain(process.StandardOutput, false);
        var stderr = Drain(process.StandardError, true);
        // Task.WhenAll waits for both streams. Stop promptly if either reader fails
        // so a worker waiting on input cannot hold the other stream open forever.
        var guardOut = stdout.ContinueWith(t => { if (t.IsFaulted) StopWorker(); }, TaskScheduler.Default);
        var guardError = stderr.ContinueWith(t => { if (t.IsFaulted) StopWorker(); }, TaskScheduler.Default);
        using var registration = cancellationToken.Register(() =>
        {
            cancelled = true;
            StopWorker();
        });
        var exited = process.WaitForExitAsync();
        var drained = Task.WhenAll(stdout, stderr);
        await Task.WhenAny(exited, drained).ConfigureAwait(false);
        if (drained.IsFaulted || drained.IsCanceled) StopWorker();
        await exited.ConfigureAwait(false);
        lifetime.Cancel();
        try { await drained.ConfigureAwait(false); }
        catch (OperationCanceledException) when (cancelled) { }
        await Task.WhenAll(guardOut, guardError).ConfigureAwait(false);
        return new(process.ExitCode, output.ToString(), hadErrors, cancelled);
    }
}

public interface ICommandRunner
{
    Task<RunResult> RunAsync(string id, Action<OutputLine> onLine, CancellationToken cancellationToken);
}

public sealed class CommandRunner : ICommandRunner
{
    private readonly Catalog _catalog;
    private readonly string _root;
    private readonly string _workerPath;
    private readonly string _reportFolder;
    private readonly IProcessTransport _transport;
    private readonly Func<bool> _isAdministrator;
    private readonly string _consoleLogFolder;
    private int _running;

    public CommandRunner(Catalog catalog, string root, string? workerPath = null, IProcessTransport? transport = null,
        Func<bool>? isAdministrator = null, string? reportFolder = null, string? consoleLogFolder = null)
    {
        _catalog = catalog; _root = root;
        _workerPath = workerPath ?? Path.Combine(AppContext.BaseDirectory, "Worker.ps1");
        _transport = transport ?? new ProcessTransport();
        _isAdministrator = isAdministrator ?? ToolkitEnvironment.IsAdministrator;
        _reportFolder = reportFolder ?? ToolkitEnvironment.ReportsFolder;
        _consoleLogFolder = consoleLogFolder ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ToolkitDesktop", "Console");
    }

    public async Task<RunResult> RunAsync(string id, Action<OutputLine> onLine, CancellationToken cancellationToken)
    {
        ExecutionPolicy.EnsureConnected(id);
        if (Interlocked.CompareExchange(ref _running, 1, 0) != 0) throw new InvalidOperationException("A command is already running.");
        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            var tool = _catalog.Tools.SingleOrDefault(t => t.Id == id)
                ?? throw new InvalidOperationException("This ID is missing from the original command catalog.");
            if (!_isAdministrator()) throw new InvalidOperationException("Start Toolkit.Desktop.exe and approve the Windows Administrator prompt before running commands.");
            await Task.Run(() => ToolkitEnvironment.VerifySources(_root, _catalog.SourceHashes), cancellationToken);
            if (!File.Exists(_workerPath)) throw new FileNotFoundException("The desktop command worker is missing. Rebuild the desktop app.");
            var console = ExecutionPolicy.NeedsConsole(id);
            var transcript = Path.Combine(_consoleLogFolder, $"{id}-{Guid.NewGuid():N}.txt");
            var start = DateTimeOffset.Now;
            var info = new ProcessStartInfo(ToolkitEnvironment.PowerShellPath)
            {
                UseShellExecute = console, CreateNoWindow = !console,
                RedirectStandardOutput = !console, RedirectStandardError = !console, RedirectStandardInput = !console,
                WorkingDirectory = _root
            };
            foreach (var arg in new[] { "-NoLogo", "-NoProfile" }) info.ArgumentList.Add(arg);
            if (!console)
            {
                info.ArgumentList.Add("-NonInteractive");
                info.StandardOutputEncoding = info.StandardErrorEncoding = info.StandardInputEncoding = new UTF8Encoding(false);
                info.Environment["TOOLKIT_DESKTOP_CHANNEL"] = Guid.NewGuid().ToString("N");
            }
            foreach (var arg in new[] { "-ExecutionPolicy", "Bypass", "-File", _workerPath, "-ToolkitRoot", _root, "-ToolId", id })
                info.ArgumentList.Add(arg);
            if (console)
            {
                foreach (var arg in new[] { "-ConsoleMode", "-TranscriptPath", transcript }) info.ArgumentList.Add(arg);
                onLine(new("Continue in the Toolkit console window. Answer its prompts there, then press Enter to return here."));
            }
            // Only the existing three diagnostic checks offer cancellation; never interrupt a repair or installer.
            var result = await _transport.ExecuteAsync(info, onLine, ExecutionPolicy.IsCancellableCheck(id) ? cancellationToken : CancellationToken.None);
            if (console)
            {
                string consoleOutput;
                try
                {
                    using var reader = new StreamReader(transcript, detectEncodingFromByteOrderMarks: true);
                    var buffer = new char[1_000_000];
                    var length = reader.ReadBlock(buffer, 0, buffer.Length);
                    consoleOutput = new string(buffer, 0, length) + "\nConsole record: " + transcript;
                }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
                {
                    consoleOutput = "No console record was available. The window may have been closed before the command finished.";
                }
                result = result with { Output = consoleOutput };
                if (result.ExitCode != 0) return new("Console ended · review result", result.Output + $"\nConsole exit code: {result.ExitCode}.");
                return new("Console closed · review output", result.Output);
            }
            if (result.Cancelled) return new("Stopped", result.Output + "\nStopped by you. This check is incomplete; any partial report is not a completed result.");
            if (result.ExitCode != 0) return new("Command failed", result.Output + $"\nPowerShell exited with code {result.ExitCode}.");
            if (id is "171" or "172" or "173" or "174" or "175")
            {
                try
                {
                    var report = ReportReader.Read(result.Output, id, _reportFolder, start);
                    var status = result.HadErrors || report.Findings.Any(f => f.Status == "ERROR") ? "Finished · review errors"
                        : report.Findings.Any(f => f.Status is "WARNING" or "NO DATA") ? "Finished · review findings" : "Report saved";
                    if (id is "173" or "174") status = "Workflow returned · review output";
                    return new(status, result.Output, report);
                }
                catch (Exception ex) when (ex is IOException or JsonException or InvalidDataException or ArgumentException or UnauthorizedAccessException)
                {
                    return new("Report unavailable", result.Output + "\n" + ex.Message + "\nA successful process exit alone does not establish a diagnostic result.");
                }
            }
            if (result.HadErrors || Regex.IsMatch(result.Output, @"(?m)^ERROR:")) return new("Finished · review errors", result.Output);
            if (Regex.IsMatch(result.Output, @"(?m)^Cancelled\.?\s*$")) return new("Cancelled", result.Output);
            if (ExecutionPolicy.IsWindowLauncher(id) || tool.Preview.TrimStart().StartsWith("Start-Process", StringComparison.Ordinal))
            {
                var title = _catalog.Tools.Single(tool => tool.Id == id).DisplayTitle;
                return new("Window requested", result.Output + $"\nRequested: {title}. Check the Windows window or settings page.");
            }
            if (id == "052")
            {
                var hasMemory = new[] { "RAM_GB", "Available_GB", "Used_Percent" }.All(field => Regex.IsMatch(result.Output, $@"(?m)^\s*{field}\s*:\s*\d"));
                return new(hasMemory ? "Output received" : "No memory data returned", result.Output);
            }
            return new("Returned · review output", result.Output);
        }
        finally { Interlocked.Exchange(ref _running, 0); }
    }
}

public static class ReportReader
{
    public static DiagnosticResult Read(string output, string id, string reportFolder, DateTimeOffset started)
    {
        var expectedMode = id switch { "171" or "173" => "General-Diagnostics", "172" or "174" => "Deep-Diagnostics", "175" => "Toolkit-Self-Test", _ => throw new InvalidDataException("Unknown diagnostic workflow.") };
        var paths = Regex.Matches(output, @"(?m)^SAVED:\s*(.+?)\s*$").Select(m => m.Groups[1].Value.Trim()).ToList();
        var path = paths.LastOrDefault(p => p.EndsWith(".json", StringComparison.OrdinalIgnoreCase));
        if (path == null || !ToolkitEnvironment.IsWithin(path, reportFolder)) throw new InvalidDataException("No valid saved JSON report was returned by the toolkit.");
        var textPath = Path.ChangeExtension(path, ".txt");
        if (!Path.GetFileName(path).StartsWith(expectedMode + "-", StringComparison.Ordinal) || !File.Exists(textPath)
            || !paths.Contains(textPath, StringComparer.OrdinalIgnoreCase)) throw new InvalidDataException("The expected TXT/JSON report pair was not produced.");
        if (new FileInfo(path).Length > 5_000_000) throw new InvalidDataException("The diagnostic report is unexpectedly large.");
        using var json = JsonDocument.Parse(File.ReadAllText(path));
        var root = json.RootElement;
        if (!root.TryGetProperty("Schema", out var schema) || schema.GetString() != "Toolkit-Diagnostic-2"
            || !root.TryGetProperty("Mode", out var mode) || mode.GetString() != expectedMode)
            throw new InvalidDataException("The returned report has an unexpected format or workflow.");
        if (!root.TryGetProperty("Generated", out var generated) || !generated.TryGetDateTimeOffset(out var date)
            || date < started.AddSeconds(-5) || date > DateTimeOffset.Now.AddMinutes(1))
            throw new InvalidDataException("The returned report is not from this run.");
        if (!root.TryGetProperty("Findings", out var rows) || rows.ValueKind != JsonValueKind.Array)
            throw new InvalidDataException("The report contains no diagnostic findings.");
        var findings = rows.Deserialize<List<Finding>>() ?? [];
        if (findings.Count == 0 || findings.Count > 512 || findings.Any(f => f.Status is not ("PASS" or "WARNING" or "ERROR" or "NO DATA")))
            throw new InvalidDataException("The diagnostic findings could not be classified.");
        return new(textPath, path, findings);
    }
}

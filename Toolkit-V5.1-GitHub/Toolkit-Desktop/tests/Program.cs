using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Toolkit.Desktop;

internal static class Program
{
    private static int _checks;
    private static string _desktop = "";
    private static string _temp = "";

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            var root = ToolkitEnvironment.FindRoot() ?? throw new Exception("Toolkit source not found.");
            _desktop = Path.Combine(Directory.GetParent(root)!.FullName, "Toolkit-Desktop");
            _temp = Path.Combine(Path.GetTempPath(), "ToolkitDesktopChecks-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_temp);
            var catalog = Catalog.Load();
            if (!args.Contains("--layout-only")) BackendChecks(catalog, root).GetAwaiter().GetResult();
            var application = new App(); application.InitializeComponent();
            SynchronizationContext.SetSynchronizationContext(new DispatcherSynchronizationContext(Dispatcher.CurrentDispatcher));
            NativeChecks(catalog);
            Console.WriteLine($"PASS: {_checks} checks. Original toolkit actions were not executed. No test windows were shown.");
            return 0;
        }
        catch (Exception ex) { Console.Error.WriteLine(ex); return 1; }
        finally
        {
            // Delete only this test's GUID-named temporary fixture directory.
            var expectedParent = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar);
            if (_temp.Length > 0 && Directory.Exists(_temp)
                && Path.GetDirectoryName(Path.GetFullPath(_temp)) == expectedParent
                && Path.GetFileName(_temp).StartsWith("ToolkitDesktopChecks-", StringComparison.Ordinal))
                Directory.Delete(_temp, true);
        }
    }

    private static void Check(bool condition, string label)
    {
        if (!condition) throw new Exception("FAILED: " + label);
        _checks++; Console.WriteLine("PASS: " + label);
    }
    private static async Task Reject(Func<Task> action, string label)
    {
        try { await action(); } catch (Exception ex) when (ex is InvalidOperationException or InvalidDataException or IOException) { Check(true, label); return; }
        throw new Exception("FAILED (accepted): " + label);
    }

    private static async Task BackendChecks(Catalog catalog, string root)
    {
        Check(catalog.Tools.Count == 231 && catalog.Categories.Count == 21, "All 231 commands and 21 source categories load");
        Check(catalog.Tools.All(t => t.Connected) && catalog.Tools.Count(t => t.Section == "main") == 180 && catalog.Tools.Count(t => t.Section == "repair") == 51, "All 180 main and 51 Repair Kit commands are connected");
        Check(catalog.Tools.All(t => t.ConnectionLabel == "Connected"), "No existing command remains unconnected");
        Check(catalog.Filter("all", "3").Single().Id == "003" && catalog.Filter("all", "R1").Single().Id == "R01", "Short main and repair IDs resolve exactly");
        Check(catalog.Filter("all", "A").Single().Id == "171" && catalog.Filter("all", "d").Single().Id == "174" && catalog.Filter("workflows", "").Count() == 4, "Existing A–D shortcuts resolve exactly");
        Check(catalog.Filter("connected", "").Count() == 231 && catalog.Filter("repair", "").Count() == 51, "Connected and Repair Kit filters");
        Check(catalog.Filter("main-5", "").All(t => t.CategoryKey == "main-5") && catalog.Filter("all", "zx-not-a-command").Count() == 0, "Category filter and empty search");
        Check(catalog.Tools.Single(t => t.Id == "052").Preview.Contains("Get-CimInstance") && catalog.Tools.Single(t => t.Id == "171").Preview.Contains("Invoke-ToolkitDiagnostics"), "Command previews come from executable source definitions");
        ToolkitEnvironment.VerifySources(root, catalog.SourceHashes); Check(true, "Compiled source hashes match original toolkit");
        var worker = Path.Combine(_desktop, "Worker.ps1");
        var blockedWorker = FixtureStart(worker);
        blockedWorker.ArgumentList.Add("-ToolId"); blockedWorker.ArgumentList.Add("000");
        blockedWorker.ArgumentList.Add("-ToolkitRoot"); blockedWorker.ArgumentList.Add(root);
        var rejectedWorker = await new ProcessTransport().ExecuteAsync(blockedWorker, _ => { }, default);
        Check(rejectedWorker.ExitCode != 0 && rejectedWorker.Output.Contains("ParameterArgumentValidationError"), "PowerShell worker rejects invalid IDs before loading toolkit");
        var addedShortcuts = new[] { "002", "004", "005", "007", "008", "011" };
        foreach (var id in addedShortcuts)
        {
            // A nonexistent source root guarantees that this parameter probe cannot load toolkit actions.
            var parameterProbe = FixtureStart(worker);
            parameterProbe.ArgumentList.Add("-ToolId"); parameterProbe.ArgumentList.Add(id);
            parameterProbe.ArgumentList.Add("-ToolkitRoot"); parameterProbe.ArgumentList.Add(Path.Combine(_temp, "absent-toolkit"));
            var probe = await new ProcessTransport().ExecuteAsync(parameterProbe, _ => { }, default);
            Check(probe.ExitCode != 0 && !probe.Output.Contains("ParameterArgumentValidationError")
                && (probe.Output.Contains("Administrator access is required") || probe.Output.Contains("Toolkit source folder was not found")),
                id + " accepted by the actual worker parameter guard without loading toolkit");
        }
        var transport = new FakeTransport();
        var runner = new CommandRunner(catalog, root, worker, transport, () => true);
        foreach (var id in new[] { "000", "181", "R00", "R52", "RA", "003;whoami", "3", "003\n", "r01" })
            await Reject(() => runner.RunAsync(id, _ => { }, default), "Execution blocked: " + id);
        Check(transport.Calls == 0, "Blocked IDs never start a process");
        await Reject(() => new CommandRunner(catalog, root, worker, transport, () => false).RunAsync("052", _ => { }, default), "Administrator requirement enforced");
        var stale = new Catalog { Tools = catalog.Tools, SourceHashes = new() { ["src/Toolkit.ps1"] = "different" } };
        await Reject(() => new CommandRunner(stale, root, worker, transport, () => true).RunAsync("052", _ => { }, default), "Changed source is blocked before execution");
        transport.Next = new(0, "RAM_GB : 8\nAvailable_GB : 3\nUsed_Percent : 62.5", false, false);
        Check((await runner.RunAsync("052", _ => { }, default)).Status == "Output received", "052 recognizes actual memory fields");
        var args = transport.Last!.ArgumentList.ToArray();
        Check(args.Contains("-NonInteractive") && args.Contains(worker) && args.Last() == "052" && !args.Contains("-ElevatedCall"), "Worker arguments use a fixed file and ID without console preapproval");
        Check(!transport.Last.UseShellExecute && transport.Last.CreateNoWindow && transport.Last.RedirectStandardOutput, "Worker is hidden with redirected streams");
        transport.Next = new(0, "COMPLETED", false, false);
        Check((await runner.RunAsync("052", _ => { }, default)).Status == "No memory data returned", "Exit zero alone is not memory success");
        transport.Next = new(0, "Error fixture", true, false);
        Check((await runner.RunAsync("003", _ => { }, default)).Status == "Finished · review errors", "003 errors are not reported as a window launch");
        transport.Next = new(0, "No pipeline rows", false, false);
        Check((await runner.RunAsync("003", _ => { }, default)).Status == "Window requested", "003 records invocation without claiming visual verification");
        foreach (var id in addedShortcuts)
        {
            transport.Next = new(0, "No pipeline rows", false, false);
            var shortcut = await runner.RunAsync(id, _ => { }, default);
            Check(transport.Last!.ArgumentList.Last() == id && shortcut.Status == "Window requested" && shortcut.Report == null
                && shortcut.Output.Contains(catalog.Tools.Single(t => t.Id == id).DisplayTitle),
                id + " routes to its original action and records a window request");
        }
        transport.Next = new(0, "ERROR: fixture launch failed", false, false);
        Check((await runner.RunAsync("007", _ => { }, default)).Status == "Finished · review errors", "Settings launch errors are not reported as a window request");
        Check(catalog.Tools.Where(t => ExecutionPolicy.IsWindowLauncher(t.Id)).All(t => !ExecutionPolicy.IsCancellableCheck(t.Id))
            && new[] { "052", "171", "175" }.All(ExecutionPolicy.IsCancellableCheck), "Stop check applies to diagnostic workers, not window shortcuts");
        transport.Next = new(0, "COMPLETED", false, false);
        Check((await runner.RunAsync("171", _ => { }, default)).Status == "Report unavailable", "Missing report is not diagnostic success");
        transport.Next = new(7, "failed", true, false);
        Check((await runner.RunAsync("052", _ => { }, default)).Status == "Command failed", "Nonzero worker exit is surfaced");
        transport.Next = new(0, "partial", false, true);
        Check((await runner.RunAsync("171", _ => { }, default)).Status == "Stopped", "Cancelled diagnostics remain incomplete");

        foreach (var tool in catalog.Tools)
        {
            transport.Next = new(0, "Fixture returned", false, false);
            await runner.RunAsync(tool.Id, _ => { }, default);
            var route = transport.Last!.ArgumentList.ToList();
            Check(route[route.IndexOf("-ToolId") + 1] == tool.Id && route[route.IndexOf("-ToolkitRoot") + 1] == root
                && !route.Contains("-ElevatedCall") && !route.Contains("-Command"), tool.Id + " dispatches the exact existing ID without preapproval");
            if (transport.Last.UseShellExecute || !transport.Last.CreateNoWindow || !transport.Last.RedirectStandardInput
                || !transport.Last.RedirectStandardOutput || !transport.Last.RedirectStandardError
                || !route.Contains("-NonInteractive") || route.Contains("-ConsoleMode"))
                throw new Exception("Wrong transport mode for " + tool.Id);
        }
        Check(catalog.Tools.Count(t => ExecutionPolicy.NeedsTerminalInput(t.Id)) == 13, "Interactive actions expose terminal input inside the app window");
        transport.Next = new(0, "Cancelled.\n", false, false);
        Check((await runner.RunAsync("R48", _ => { }, default)).Status == "Cancelled", "Declined changes remain cancelled");
        transport.Next = new(0, "COMPLETED", false, false);
        Check((await runner.RunAsync("R04", _ => { }, default)).Status == "Returned · review output", "Repair completion is not labelled proof of success");

        var held = new HeldTransport();
        var busyRunner = new CommandRunner(catalog, root, worker, held, () => true);
        var active = busyRunner.RunAsync("052", _ => { }, default);
        await held.Entered.Task.WaitAsync(TimeSpan.FromSeconds(20));
        await Reject(() => busyRunner.RunAsync("052", _ => { }, default), "Duplicate concurrent execution is blocked");
        held.Completion.SetResult(new(0, "", false, false)); await active;

        var reports = Path.Combine(_temp, "reports with spaces"); Directory.CreateDirectory(reports);
        foreach (var id in new[] { "171", "172", "173", "174", "175" })
        {
            var saved = WriteReport(reports, id, DateTimeOffset.Now, "Toolkit-Diagnostic-2");
            var parsed = ReportReader.Read(saved, id, reports, DateTimeOffset.Now.AddSeconds(-1));
            Check(parsed.Findings.Select(f => f.Status).SequenceEqual(new[] { "PASS", "WARNING", "ERROR", "NO DATA" }), id + " retains all four finding statuses");
            transport.Next = new(0, saved, false, false);
            var reportRunner = new CommandRunner(catalog, root, worker, transport, () => true, reports);
            var result = await reportRunner.RunAsync(id, _ => { }, default);
            Check(result.Report != null && result.Status == (id is "173" or "174" ? "Workflow returned · review output" : "Finished · review errors"), id + " connects saved report without claiming repair success");
        }
        var old = WriteReport(reports, "171", DateTimeOffset.Now.AddDays(-1), "Toolkit-Diagnostic-2");
        await Reject(() => Task.Run(() => ReportReader.Read(old, "171", reports, DateTimeOffset.Now)), "Stale reports rejected");
        var wrong = WriteReport(reports, "171", DateTimeOffset.Now, "Wrong-Schema");
        await Reject(() => Task.Run(() => ReportReader.Read(wrong, "171", reports, DateTimeOffset.Now)), "Unknown report schema rejected");
        var outside = WriteReport(_temp, "171", DateTimeOffset.Now, "Toolkit-Diagnostic-2");
        await Reject(() => Task.Run(() => ReportReader.Read(outside, "171", reports, DateTimeOffset.Now)), "Report paths outside report directory rejected");
        Check(!ToolkitEnvironment.IsWithin(reports + "-other\\file.json", reports), "Sibling path with shared prefix is not inside report folder");
        await TransportChecks();
        await PromptChecks();
    }

    private static string WriteReport(string directory, string id, DateTimeOffset generated, string schema)
    {
        var mode = id switch { "171" or "173" => "General-Diagnostics", "172" or "174" => "Deep-Diagnostics", _ => "Toolkit-Self-Test" };
        var stem = Path.Combine(directory, mode + "-fixture");
        File.WriteAllText(stem + ".txt", "Synthetic test fixture");
        File.WriteAllText(stem + ".json", JsonSerializer.Serialize(new
        {
            Schema = schema, Mode = mode, Generated = generated.ToString("o"),
            Findings = new[] { "PASS", "WARNING", "ERROR", "NO DATA" }.Select(status => new Finding { Id = status, Check = "Fixture", Status = status, Summary = "Synthetic fixture" })
        }));
        return $"SAVED: {stem}.txt\nSAVED: {stem}.json\n";
    }

    private static ProcessStartInfo FixtureStart(string script)
    {
        var info = new ProcessStartInfo(ToolkitEnvironment.PowerShellPath)
        {
            UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true,
            RedirectStandardOutput = true, RedirectStandardError = true,
            StandardOutputEncoding = new UTF8Encoding(false), StandardErrorEncoding = new UTF8Encoding(false)
        };
        foreach (var arg in new[] { "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script }) info.ArgumentList.Add(arg);
        return info;
    }
    private static async Task TransportChecks()
    {
        var fixture = Path.Combine(_temp, "unicode fixture.ps1");
        File.WriteAllText(fixture, "[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)\n[Console]::WriteLine('Fixture café → 中文')\n[Console]::Error.WriteLine('fixture stderr')\nexit 0", new UTF8Encoding(true));
        var result = await new ProcessTransport().ExecuteAsync(FixtureStart(fixture), _ => { }, default);
        Check(result.Output.Contains("café → 中文") && result.Output.Contains("fixture stderr") && result.HadErrors, "Real process transport captures Unicode stdout and stderr");
        File.WriteAllText(fixture, "[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)\nClear-Host\nWrite-Host 'SAVED: fixture output' -ForegroundColor Green\n[pscustomobject]@{RAM_GB=8;Available_GB=3;Used_Percent=62.5}|Format-List|Out-Host\nexit 0", new UTF8Encoding(true));
        var console = await new ProcessTransport().ExecuteAsync(FixtureStart(fixture), _ => { }, default);
        Check(console.ExitCode == 0 && !console.HadErrors && console.Output.Contains("SAVED: fixture output") && console.Output.Contains("Available_GB"), "Existing console output pattern works through a hidden redirected worker");
        File.WriteAllText(fixture, "[Console]::WriteLine('fixture ready')\nStart-Sleep -Seconds 30", new UTF8Encoding(true));
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using var stop = new CancellationTokenSource();
        var pending = new ProcessTransport().ExecuteAsync(FixtureStart(fixture), line => { if (line.Text.Contains("fixture ready")) entered.TrySetResult(); }, stop.Token);
        await entered.Task.WaitAsync(TimeSpan.FromSeconds(20)); stop.Cancel();
        var cancelled = await pending.WaitAsync(TimeSpan.FromSeconds(15));
        Check(cancelled.Cancelled, "Stop terminates the fixture worker and drains its output");

        File.WriteAllText(fixture, "[Console]::WriteLine('terminal ready')\n$line=[Console]::In.ReadLine()\n[Console]::WriteLine('terminal received:'+ $line)\nexit 0", new UTF8Encoding(true));
        var transport = new ProcessTransport();
        var terminalReady = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var terminalInfo = FixtureStart(fixture);
        terminalInfo.Environment["TOOLKIT_DESKTOP_CHANNEL"] = Guid.NewGuid().ToString("N");
        var terminal = transport.ExecuteAsync(terminalInfo, line => { if (line.Text.Contains("terminal ready")) terminalReady.TrySetResult(); }, default);
        await terminalReady.Task.WaitAsync(TimeSpan.FromSeconds(20));
        Check(await transport.SendInputAsync("fixture input"), "In-window terminal input reaches redirected PowerShell stdin");
        var terminalResult = await terminal.WaitAsync(TimeSpan.FromSeconds(20));
        Check(terminalResult.ExitCode == 0 && terminalResult.Output.Contains("terminal received:fixture input"), "Terminal input returns through the same output stream");
    }

    private static async Task PromptChecks()
    {
        var bridge = Path.Combine(_desktop, "PromptBridge.ps1").Replace("'", "''");
        var fixture = Path.Combine(_temp, "prompt fixture.ps1");
        var questions = new[] { "Type YES to run, anything else to cancel", "Type SCAN to include both checks; anything else skips",
            "Type INSTALL to run only Fixture, or anything else to cancel", "Advanced repair. Type DEEP REPAIR to permit confirmation step",
            "Full path to downloaded file", "Press Enter" };
        var answers = new[] { "no", "SCAN", "INSTALL", "DEEP REPAIR", "C:\\fixture space\\café 中文 $(throw 'must stay text').zip", "" };
        File.WriteAllText(fixture, "[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)\n. '" + bridge + "'\n"
            + string.Join("\n", questions.Select((q, i) => "$value=Read-Host '" + q.Replace("'", "''") + "'; [Console]::WriteLine('ANSWER" + i + ":'+[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($value)))")), new UTF8Encoding(true));
        var info = FixtureStart(fixture);
        info.StandardInputEncoding = new UTF8Encoding(false);
        info.Environment["TOOLKIT_DESKTOP_CHANNEL"] = Guid.NewGuid().ToString("N");
        var index = 0;
        var result = await new ProcessTransport((question, _) =>
        {
            Check(question == questions[index], "Existing question arrives verbatim: " + index);
            return Task.FromResult(answers[index++]);
        }).ExecuteAsync(info, _ => { }, default).WaitAsync(TimeSpan.FromSeconds(40));
        Check(result.ExitCode == 0 && !result.HadErrors && index == questions.Length, "Sequential questions complete through a real Windows PowerShell 5.1 process");
        for (var i = 0; i < answers.Length; i++)
            Check(result.Output.Contains("ANSWER" + i + ":" + Convert.ToBase64String(Encoding.UTF8.GetBytes(answers[i]))), "Answer " + i + " retains exact case, Unicode, spaces and literal characters");
        Check(!result.Output.Contains("@@TOOLKIT_PROMPT:"), "Internal prompt messages stay out of the output display");

        // Confirmation fixture writes only a marker in its private test directory.
        var marker = Path.Combine(_temp, "confirmed.marker");
        File.WriteAllText(fixture, ". '" + bridge + "'\n$ok=Read-Host 'Type YES to run, anything else to cancel'\n"
            + "if($ok -cne 'YES'){Write-Host 'Cancelled.';exit 0}\n[IO.File]::WriteAllText('" + marker.Replace("'", "''") + "','fixture only')", new UTF8Encoding(true));
        foreach (var answer in new[] { "", "yes", "NO", "YES" })
        {
            var confirmed = await new ProcessTransport((_, _) => Task.FromResult(answer)).ExecuteAsync(info, _ => { }, default);
            Check(confirmed.ExitCode == 0 && File.Exists(marker) == (answer == "YES"), "Confirmation preserves exact YES gate for '" + answer + "'");
        }
        var pendingQuestion = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using var stop = new CancellationTokenSource();
        var waiting = new ProcessTransport(async (_, token) =>
        {
            pendingQuestion.TrySetResult(); await Task.Delay(Timeout.Infinite, token); return "never";
        }).ExecuteAsync(info, _ => { }, stop.Token);
        await pendingQuestion.Task.WaitAsync(TimeSpan.FromSeconds(30)); stop.Cancel();
        Check((await waiting.WaitAsync(TimeSpan.FromSeconds(15))).Cancelled, "Stopping a fixture waiting for input releases the prompt and worker");

        var missingHandler = await CaptureFailure(() => new ProcessTransport().ExecuteAsync(info, _ => { }, default));
        Check(missingHandler is InvalidOperationException, "Missing answer handler stops the worker instead of silently answering");
        // Production Worker routing is exercised only against disposable stub scripts.
        if (ToolkitEnvironment.IsAdministrator())
        {
            var root = Path.Combine(_temp, "stub toolkit");
            Directory.CreateDirectory(Path.Combine(root, "src"));
            Directory.CreateDirectory(Path.Combine(root, "repair-kit", "src"));
            File.WriteAllText(Path.Combine(root, "src", "Toolkit.ps1"), "param([string]$ToolId)\nWrite-Host ('MAIN:'+ $ToolId)\n$value=Read-Host 'Fixture answer'\nWrite-Host ('REPLY:'+ $value)\nexit 0");
            File.WriteAllText(Path.Combine(root, "repair-kit", "src", "RepairKit.ps1"), "param([string]$ToolId)\nWrite-Host ('REPAIR:'+ $ToolId)\n$value=Read-Host 'Fixture answer'\nWrite-Host ('REPLY:'+ $value)\nexit 0");
            foreach (var id in new[] { "003", "018", "081", "171", "174", "R01", "R40", "R51" })
            {
                var worker = FixtureStart(Path.Combine(_desktop, "Worker.ps1"));
                foreach (var arg in new[] { "-ToolkitRoot", root, "-ToolId", id }) worker.ArgumentList.Add(arg);
                worker.Environment["TOOLKIT_DESKTOP_CHANNEL"] = Guid.NewGuid().ToString("N");
                var routed = await new ProcessTransport((_, _) => Task.FromResult("fixture reply")).ExecuteAsync(worker, _ => { }, default);
                Check(routed.ExitCode == 0 && routed.Output.Contains((id.StartsWith('R') ? "REPAIR:" : "MAIN:") + id)
                    && routed.Output.Contains("REPLY:fixture reply"), "Actual worker routes " + id + " to the correct stub script and passes its answer");
            }
            Check(true, "Previously separate-console command 018 routes through the in-window worker");
        }
        else Console.WriteLine("NOT RUN: production-worker stub routing needs an Administrator test process.");
    }

    private static async Task<Exception?> CaptureFailure(Func<Task> action)
    {
        try { await action().WaitAsync(TimeSpan.FromSeconds(30)); return null; }
        catch (Exception ex) { return ex; }
    }

    private static void NativeChecks(Catalog catalog)
    {
        var bindings = new StringWriter();
        var listener = new TextWriterTraceListener(bindings);
        PresentationTraceSources.DataBindingSource.Listeners.Add(listener);
        PresentationTraceSources.DataBindingSource.Switch.Level = SourceLevels.Warning;
        var fake = new FakeCommandRunner();
        var vm = new MainViewModel(catalog, fake, true);
        var window = new MainWindow(vm);
        var handle = new WindowInteropHelper(window).EnsureHandle();
        Check(window.Icon != null && SendMessage(handle, 0x007F, IntPtr.Zero, IntPtr.Zero) != IntPtr.Zero
            && SendMessage(handle, 0x007F, new IntPtr(1), IntPtr.Zero) != IntPtr.Zero,
            "The compiled WPF window supplies both small and large native icons");
        var monitor = new TestMonitorInfo { Size = Marshal.SizeOf<TestMonitorInfo>() };
        Check(GetWindowRect(handle, out var bounds) && GetMonitorInfo(MonitorFromWindow(handle, 2), ref monitor)
            && bounds.Left >= monitor.Work.Left && bounds.Top > monitor.Work.Top
            && bounds.Right <= monitor.Work.Right && bounds.Bottom <= monitor.Work.Bottom,
            "Native startup bounds fit the monitor work area with a visible gap above the title bar before Show");
        Check(window.WindowStartupLocation == WindowStartupLocation.Manual
            && window.Width <= 1500 && window.Height <= 900
            && window.Width >= window.MinWidth && window.Height >= window.MinHeight,
            "Startup uses the fitted three-panel size and cannot be recentered off-screen");
        var surface = (FrameworkElement)window.Content; window.Content = null;
        surface.DataContext = vm;
        var host = new Grid { Background = new SolidColorBrush(Color.FromRgb(8, 14, 11)) };
        host.Children.Add(surface);
        System.Windows.Documents.TextElement.SetFontFamily(surface, new FontFamily("Segoe UI"));
        System.Windows.Documents.TextElement.SetFontSize(surface, 13);
        void Layout(int width, int height)
        {
            host.Width = width; host.Height = height;
            host.Measure(new Size(width, height)); host.Arrange(new Rect(0, 0, width, height)); host.UpdateLayout();
            Dispatcher.CurrentDispatcher.Invoke(() => { }, DispatcherPriority.ApplicationIdle);
        }
        Layout(1280, 810);
        var button = (Button)window.FindName("RunButton");
        var mainPanel = (Border)window.FindName("MainPanel");
        var sidePanels = (Grid)window.FindName("SidePanels");
        var outputPanel = (Border)window.FindName("OutputPanel");
        var repairList = (ListBox)window.FindName("RepairKitList");
        var repairCategoryList = (ComboBox)window.FindName("RepairKitCategoryList");
        Check(mainPanel.ActualWidth > sidePanels.ActualWidth * 1.25
            && Grid.GetRow((Border)window.FindName("DetailsPanel")) == 0
            && Grid.GetRow(outputPanel) == 2,
            "The main workspace fills three fifths with a stacked runner and lower panel on the right");
        Check(repairList.Items.Count == 51 && repairCategoryList.Items.Count == 7, "The lower Repair Kit screen exposes all actions and six categories");
        repairCategoryList.SelectedItem = vm.RepairCategories.First(category => category.Key != "repair"); Layout(1280, 810);
        Check(repairList.Items.Count == catalog.Tools.Count(tool => tool.CategoryKey == vm.SelectedRepairCategory!.Key), "Repair Kit categories filter the lower action list");
        repairCategoryList.SelectedItem = vm.RepairCategories.First(category => category.Key == "repair"); Layout(1280, 810);
        Check(vm.CatalogSummary == "231 COMMANDS  /  231 CONNECTED" && vm.Navigation.Single(n => n.Key == "connected").Count == "231", "Header and navigation show all 231 connected commands");
        Check(button.IsEnabled && vm.SelectedTool?.Id == "003", "Native WPF initially selects connected Documents action");
        var rotateButton = (Button)window.FindName("RotateLayoutButton");
        rotateButton.RaiseEvent(new RoutedEventArgs(Button.ClickEvent)); Layout(1280, 810);
        Check(Grid.GetRow(mainPanel) == 0 && Grid.GetRow(sidePanels) == 2 && Math.Abs(mainPanel.ActualWidth - ((FrameworkElement)window.FindName("WorkspaceGrid")).ActualWidth) < 1,
            "Rotate layout stacks the main screen above the two right-side screens");
        Check(mainPanel.ActualHeight > sidePanels.ActualHeight && sidePanels.ActualHeight >= 200
            && Math.Abs(sidePanels.ActualWidth - ((FrameworkElement)window.FindName("WorkspaceGrid")).ActualWidth) < 1
            && Grid.GetColumn(outputPanel) == 2,
            "Rotated layout gives the main screen more height and places runner and output side by side below");
        var rotatedDirectory = Path.Combine(_desktop, "artifacts"); Directory.CreateDirectory(rotatedDirectory);
        Render(host, Path.Combine(rotatedDirectory, "desktop-rotated.png"), 1280, 810, 1);
        rotateButton.RaiseEvent(new RoutedEventArgs(Button.ClickEvent)); Layout(1280, 810);
        repairList.SelectedItem = catalog.Tools.Single(tool => tool.Id == "R48"); Layout(1280, 810);
        Check(vm.SelectedTool?.Id == "R48" && button.Content.ToString()!.Contains("R48"), "Repair Kit selection updates the shared guarded command runner");
        vm.SelectedTool = catalog.Tools.Single(tool => tool.Id == "003"); Layout(1280, 810);
        vm.SelectedTool = catalog.Tools.Single(t => t.Id == "001"); Layout(1232, 780);
        Check(button.IsEnabled && button.Content.ToString()!.Contains("001"), "Existing change command can be selected for its original confirmation flow");
        foreach (var tool in catalog.Tools) { vm.SelectedTool = tool; if (!vm.RunCommand.CanExecute(null)) throw new Exception("Unexpected disabled command " + tool.Id); }
        Check(true, "Every existing command is accessible through the UI");
        vm.Query = "no-matching-tool-fixture"; Layout(1232, 780);
        Check(vm.NoMatches && vm.SelectedTool == null && !button.IsEnabled, "Native empty search clears selection and disables Run");
        foreach (var id in new[] { "002", "004", "005", "007", "008", "011" })
        {
            vm.Query = id; Layout(1232, 780);
            Check(vm.VisibleTools.Count == 1 && vm.SelectedTool?.Id == id && button.IsEnabled && button.Content.ToString()!.Contains(id),
                "Native search and Run button connect " + id);
        }
        vm.Query = "052"; Layout(1232, 780);
        Check(vm.SelectedTool?.Id == "052" && button.IsEnabled, "Native search finds and enables RAM action");
        Check(fake.Calls == 0, "Browsing, searching and rendering never execute commands");
        vm.RunSelectedAsync().GetAwaiter().GetResult(); Layout(1232, 780);
        Check(fake.Calls == 1 && vm.History.Count == 1 && vm.SelectedRun?.Status == "Fixture completed", "Run records a fixture's real completion in session history");
        Check(vm.SelectedRun?.Output == "fixture output" && !vm.Busy, "Output and busy state updated on completion");
        fake.Ask = () => vm.RequestAnswerAsync("Type YES to continue (anything else cancels)", default);
        vm.Query = "R48";
        var pending = vm.RunSelectedAsync(); Layout(1280, 810);
        Check(vm.HasPrompt && vm.Answer == "" && !pending.IsCompleted && vm.Busy && !vm.HistoryEnabled,
            "Native answer box starts empty and waits for explicit input with the active output retained");
        Check(!vm.RunCommand.CanExecute(null) && !vm.StopCommand.CanExecute(null), "Repair cannot be duplicated or stopped while running");
        var promptDirectory = Path.Combine(_desktop, "artifacts"); Directory.CreateDirectory(promptDirectory);
        Render(host, Path.Combine(promptDirectory, "desktop-prompt.png"), 1280, 810, 1);
        Layout(1000, 640); Render(host, Path.Combine(promptDirectory, "desktop-prompt-compact.png"), 1000, 640, 1);
        Check(((TextBox)window.FindName("OutputBox")).ActualHeight >= 40, "Compact prompt retains readable, scrollable command output above the question");
        vm.Answer = "NO"; vm.SendAnswerCommand.Execute(null);
        PumpUntil(pending);
        Check(fake.LastAnswer == "NO" && !vm.HasPrompt && !vm.Busy && vm.Answer == "", "Native answer submits once and clears before another question");
        // Render a fresh window, with no fabricated system findings in the preview.
        vm.Dispose(); var previewVm = new MainViewModel(catalog, new FakeCommandRunner(), true);
        surface.DataContext = previewVm; Layout(1232, 780);
        var directory = Path.Combine(_desktop, "artifacts"); Directory.CreateDirectory(directory);
        Layout(1280, 810); Render(host, Path.Combine(directory, "desktop-preview.png"), 1280, 810, 1);
        Layout(1000, 640);
        Render(host, Path.Combine(directory, "desktop-compact.png"), 1000, 640, 1);
        Check(surface.ActualWidth == 964 && surface.ActualHeight == 616, "Compiled WPF view lays out at compact size");
        Layout(1280, 810); Render(host, Path.Combine(directory, "desktop-150-percent.png"), 1280, 810, 1.5);
        Check(File.Exists(Path.Combine(directory, "desktop-150-percent.png")), "Compiled WPF view renders at 150 percent DPI");
        listener.Flush(); Check(bindings.ToString().Length == 0, "No WPF data-binding warnings during native view checks");
        PresentationTraceSources.DataBindingSource.Listeners.Remove(listener); listener.Dispose();
        previewVm.Dispose(); window.Close();
        Console.WriteLine("Off-screen native WPF previews: Toolkit-Desktop/artifacts/");
    }
    private static void Render(FrameworkElement surface, string path, int width, int height, double scale)
    {
        var bitmap = new RenderTargetBitmap((int)(width * scale), (int)(height * scale), 96 * scale, 96 * scale, PixelFormats.Pbgra32);
        bitmap.Render(surface); var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var file = File.Create(path); encoder.Save(file);
    }

    private static void PumpUntil(Task task)
    {
        var frame = new DispatcherFrame(); var started = Stopwatch.StartNew();
        var timer = new DispatcherTimer(TimeSpan.FromMilliseconds(25), DispatcherPriority.Background,
            (_, _) => { if (task.IsCompleted || started.Elapsed > TimeSpan.FromSeconds(15)) frame.Continue = false; }, Dispatcher.CurrentDispatcher);
        Dispatcher.PushFrame(frame); timer.Stop();
        if (!task.IsCompleted) throw new TimeoutException("Native prompt did not finish.");
        task.GetAwaiter().GetResult();
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct TestRect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    private struct TestMonitorInfo { public int Size; public TestRect Monitor, Work; public uint Flags; }
    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetMonitorInfo(IntPtr monitor, ref TestMonitorInfo info);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetWindowRect(IntPtr hwnd, out TestRect rect);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr SendMessage(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);

    private sealed class FakeTransport : IProcessTransport
    {
        public int Calls; public ProcessStartInfo? Last;
        public ProcessResult Next = new(0, "", false, false);
        public Task<ProcessResult> ExecuteAsync(ProcessStartInfo info, Action<OutputLine> onLine, CancellationToken token) { Calls++; Last = info; return Task.FromResult(Next); }
        public Task<bool> SendInputAsync(string line) => Task.FromResult(false);
    }
    private sealed class HeldTransport : IProcessTransport
    {
        public TaskCompletionSource Entered = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource<ProcessResult> Completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public Task<ProcessResult> ExecuteAsync(ProcessStartInfo info, Action<OutputLine> onLine, CancellationToken token) { Entered.SetResult(); return Completion.Task; }
        public Task<bool> SendInputAsync(string line) => Task.FromResult(false);
    }
    private sealed class FakeCommandRunner : ICommandRunner
    {
        public int Calls;
        public Func<Task<string>>? Ask; public string? LastAnswer;
        public async Task<RunResult> RunAsync(string id, Action<OutputLine> onLine, CancellationToken token)
        {
            ExecutionPolicy.EnsureConnected(id); Calls++; onLine(new("fixture output"));
            if (Ask != null) LastAnswer = await Ask();
            return new RunResult("Fixture completed", "fixture output");
        }
        public Task<bool> SendTerminalInputAsync(string line) => Task.FromResult(false);
    }
}

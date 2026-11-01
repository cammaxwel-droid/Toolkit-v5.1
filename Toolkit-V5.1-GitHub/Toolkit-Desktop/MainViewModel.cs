using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;

namespace Toolkit.Desktop;

public sealed class UiCommand(Action execute, Func<bool>? canExecute = null) : ICommand
{
    public event EventHandler? CanExecuteChanged;
    public bool CanExecute(object? parameter) => canExecute?.Invoke() ?? true;
    public void Execute(object? parameter) { if (CanExecute(parameter)) execute(); }
    public void Refresh() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}

public sealed class MainViewModel : Observable
{
    private readonly Catalog _catalog;
    private readonly ICommandRunner _runner;
    private readonly Dispatcher _dispatcher;
    private readonly DispatcherTimer _timer;
    private readonly bool _canExecute;
    private CancellationTokenSource? _cancellation;
    private readonly Stopwatch _elapsed = new();
    private RunRecord? _activeRun;
    public bool IsAdministrator { get; }
    public string AdministratorLabel => IsAdministrator ? "ADMINISTRATOR" : "ADMIN REQUIRED";
    public ObservableCollection<NavigationItem> Navigation { get; } = [];
    public ObservableCollection<RunRecord> History { get; } = [];
    public UiCommand RunCommand { get; }
    public UiCommand StopCommand { get; }
    public UiCommand CopyCommand { get; }
    public UiCommand OpenTextCommand { get; }
    public UiCommand OpenJsonCommand { get; }
    public UiCommand ClearSearchCommand { get; }
    public UiCommand SendAnswerCommand { get; }
    private TaskCompletionSource<string>? _answerRequest;
    public bool HasPrompt => _answerRequest != null;
    private string _prompt = "";
    public string Prompt { get => _prompt; private set => Set(ref _prompt, value); }
    private string _answer = "";
    public string Answer { get => _answer; set => Set(ref _answer, value); }
    public int ConnectedCount => _catalog.Tools.Count(tool => tool.Connected);
    public string CatalogSummary => $"{_catalog.Tools.Count} COMMANDS  /  {ConnectedCount} CONNECTED";
    private string _query = "";
    public string Query
    {
        get => _query;
        set
        {
            if (!Set(ref _query, value)) return;
            if (value.Length > 0) { _navigation = Navigation[0]; Changed(nameof(SelectedNavigation)); }
            RefreshFilter();
        }
    }
    private NavigationItem? _navigation;
    public NavigationItem? SelectedNavigation
    {
        get => _navigation;
        set { if (value != null && Set(ref _navigation, value)) { _query = ""; Changed(nameof(Query)); RefreshFilter(); } }
    }
    private List<ToolAction> _visibleTools = [];
    public List<ToolAction> VisibleTools => _visibleTools;
    public string MatchLabel => $"{VisibleTools.Count} MATCHES";
    public bool NoMatches => VisibleTools.Count == 0;
    private ToolAction? _selectedTool;
    public ToolAction? SelectedTool
    {
        get => _selectedTool;
        set { Set(ref _selectedTool, value); Changed(nameof(RunLabel)); Changed(nameof(HasSelection)); RunCommand?.Refresh(); CopyCommand?.Refresh(); }
    }
    public bool HasSelection => SelectedTool != null;
    private bool _busy;
    public bool Busy { get => _busy; private set { Set(ref _busy, value); Changed(nameof(RunLabel)); Changed(nameof(HistoryEnabled)); RunCommand.Refresh(); StopCommand.Refresh(); } }
    public bool HistoryEnabled => !Busy;
    public string RunLabel => Busy ? "Command running…" : SelectedTool == null ? "Select a command" : SelectedTool.Connected ? $"Run {SelectedTool.Id}  →" : "Not connected yet";
    private string _status = "Ready";
    public string Status { get => _status; set => Set(ref _status, value); }
    private string _notice = "";
    public string Notice { get => _notice; set { Set(ref _notice, value); Changed(nameof(HasNotice)); } }
    public bool HasNotice => Notice.Length > 0;
    private RunRecord? _selectedRun;
    public RunRecord? SelectedRun
    {
        get => _selectedRun;
        set { Set(ref _selectedRun, value); Changed(nameof(HasRun)); Changed(nameof(EmptyOutput)); OpenTextCommand.Refresh(); OpenJsonCommand.Refresh(); }
    }
    public bool HasRun => SelectedRun != null;
    public string EmptyOutput => "C:\\TOOLKIT> ready\n\nChoose a connected command, review its details, then select Run.\nOutput appears here. Nothing runs when you browse or search.";
    private int _outputTab;
    public int OutputTab { get => _outputTab; set => Set(ref _outputTab, value); }

    public MainViewModel(Catalog catalog, ICommandRunner runner, bool isAdministrator, bool sourceAvailable = true)
    {
        _catalog = catalog; _runner = runner; _dispatcher = Dispatcher.CurrentDispatcher;
        IsAdministrator = isAdministrator; _canExecute = isAdministrator && sourceAvailable;
        RunCommand = new(async () => await RunSelectedAsync(), () => !Busy && _canExecute && SelectedTool?.Connected == true);
        StopCommand = new(() => { _cancellation?.Cancel(); Status = "Stopping check…"; }, () => Busy && _activeRun != null && ExecutionPolicy.IsCancellableCheck(_activeRun.Id));
        CopyCommand = new(CopyPreview, () => SelectedTool != null);
        OpenTextCommand = new(() => OpenReport(false), () => SelectedRun?.HasReport == true);
        OpenJsonCommand = new(() => OpenReport(true), () => SelectedRun?.HasReport == true);
        ClearSearchCommand = new(() => Query = "");
        SendAnswerCommand = new(() => { _answerRequest?.TrySetResult(Answer); SendAnswerCommand!.Refresh(); },
            () => _answerRequest != null && !_answerRequest.Task.IsCompleted);
        Navigation.Add(new("all", "All commands", "231", "Main toolkit and Repair Kit"));
        Navigation.Add(new("connected", "Connected commands", ConnectedCount.ToString(), "Commands currently available in this desktop build"));
        Navigation.Add(new("workflows", "Guided workflows", "A–D", "171–174; existing diagnostics and individually confirmed repairs"));
        Navigation.Add(new("repair", "Repair Kit", "51", "The existing R01–R51 commands"));
        foreach (var c in catalog.Categories.Where(c => c.Section == "main"))
            Navigation.Add(new(c.Key, c.Name, catalog.Tools.Count(t => t.CategoryKey == c.Key).ToString(), c.Hint));
        _navigation = Navigation[0]; RefreshFilter(); SelectedTool = _visibleTools.First(t => t.Id == "003");
        if (!sourceAvailable) Notice = "Keep Toolkit-Desktop beside the original Toolkit-V5.1 folder. The toolkit source was not found.";
        else if (!isAdministrator) Notice = "Browsing is available. To run commands, open Toolkit.Desktop.exe and approve its Windows Administrator prompt.";
        _timer = new DispatcherTimer(TimeSpan.FromSeconds(1), DispatcherPriority.Background, (_, _) =>
        {
            if (Busy && _activeRun != null) Status = $"{(HasPrompt ? "Waiting for your answer" : ExecutionPolicy.NeedsConsole(_activeRun.Id) ? "Continue in console" : "Running")} {_activeRun.Id} · {_elapsed.Elapsed:mm\\:ss} elapsed";
        }, _dispatcher);
        _timer.Stop();
    }

    private void RefreshFilter()
    {
        var previous = SelectedTool?.Id;
        _visibleTools = _catalog.Filter(SelectedNavigation?.Key ?? "all", Query).ToList();
        Changed(nameof(VisibleTools)); Changed(nameof(MatchLabel)); Changed(nameof(NoMatches));
        SelectedTool = _visibleTools.FirstOrDefault(t => t.Id == previous) ?? _visibleTools.FirstOrDefault();
    }

    public async Task<string> RequestAnswerAsync(string question, CancellationToken token)
    {
        var request = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
        await _dispatcher.InvokeAsync(() =>
        {
            if (_answerRequest != null) throw new InvalidOperationException("A command is already waiting for an answer.");
            _answerRequest = request; Prompt = question; Answer = "";
            SelectedRun = _activeRun; OutputTab = 0;
            Changed(nameof(HasPrompt)); SendAnswerCommand.Refresh();
        });
        using var cancelled = token.Register(() => request.TrySetCanceled(token));
        try { return await request.Task.ConfigureAwait(false); }
        finally
        {
            await _dispatcher.InvokeAsync(() =>
            {
                _answerRequest = null; Prompt = ""; Answer = "";
                Changed(nameof(HasPrompt)); SendAnswerCommand.Refresh();
            });
        }
    }

    public async Task RunSelectedAsync()
    {
        if (!RunCommand.CanExecute(null) || SelectedTool == null) return;
        var tool = SelectedTool;
        var run = new RunRecord { Id = tool.Id, Title = tool.DisplayTitle };
        _activeRun = run; History.Insert(0, run);
        if (History.Count > 50) History.RemoveAt(History.Count - 1);
        SelectedRun = run; OutputTab = 0; Notice = "";
        _cancellation = new CancellationTokenSource(); Busy = true;
        _elapsed.Restart(); _timer.Start(); Status = $"Running {tool.Id}…";
        try
        {
            var result = await _runner.RunAsync(tool.Id, line =>
            {
                _dispatcher.Invoke(() => run.Append(line));
            }, _cancellation.Token);
            run.Output = result.Output; run.Status = result.Status; run.Report = result.Report;
            Status = $"{tool.Id} · {result.Status} · {_elapsed.Elapsed:mm\\:ss}";
        }
        catch (OperationCanceledException) { run.Status = "Stopped"; run.Output += "\nStopped before completion."; Status = "Stopped"; }
        catch (Exception ex) { run.Status = "Could not run"; run.Output += "\n" + ex.Message; Status = "Could not run command"; Notice = ex.Message; }
        finally
        {
            _timer.Stop(); _elapsed.Stop(); Busy = false; _activeRun = null;
            _cancellation.Dispose(); _cancellation = null;
            OpenTextCommand.Refresh(); OpenJsonCommand.Refresh();
        }
    }

    private void CopyPreview()
    {
        if (SelectedTool == null) return;
        try { Clipboard.SetText(SelectedTool.Preview); Status = $"Copied command preview for {SelectedTool.Id}"; }
        catch (Exception ex) { Notice = "The clipboard is unavailable: " + ex.Message; }
    }

    private void OpenReport(bool json)
    {
        var report = SelectedRun?.Report;
        if (report == null) return;
        var path = json ? report.JsonPath : report.TextPath;
        try
        {
            if (!ToolkitEnvironment.IsWithin(path, ToolkitEnvironment.ReportsFolder) || !File.Exists(path))
                throw new IOException("This report is no longer in the Toolkit-Reports folder.");
            // Reports are opened as text, regardless of the machine's .json association.
            var info = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "notepad.exe")) { UseShellExecute = false };
            info.ArgumentList.Add(path); Process.Start(info);
        }
        catch (Exception ex) { Notice = "Could not open report: " + ex.Message; }
    }

    public void Dispose() { _timer.Stop(); }
}

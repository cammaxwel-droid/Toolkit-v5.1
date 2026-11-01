using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;

namespace Toolkit.Desktop;

public abstract class Observable : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    protected void Changed([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new(name));
    protected bool Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value; Changed(name); return true;
    }
}

public sealed record Category(string Key, string Name, string Hint, string Section);
public sealed record NavigationItem(string Key, string Name, string Count, string Hint);

public sealed class ToolAction
{
    public string Id { get; set; } = "";
    public string CategoryKey { get; set; } = "";
    public string CategoryName { get; set; } = "";
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public string Risk { get; set; } = "VIEW";
    public bool Admin { get; set; }
    public string Preview { get; set; } = "";
    public string Section { get; set; } = "main";
    public bool Connected => ExecutionPolicy.IsConnected(Id);
    public string ConnectionLabel => Connected ? "Connected" : "Not connected yet";
    public bool ShowRunNote => ExecutionPolicy.NeedsConsole(Id) || Risk is "CHANGE" or "REPAIR" || Id is "171" or "172" or "175";
    public string Shortcut => Id switch { "171" => "A", "172" => "B", "173" => "C", "174" => "D", _ => "" };
    public string DisplayTitle => Id switch
    {
        "171" => "General Diagnostics", "172" => "Deep Diagnostics",
        "173" => "General Repair (guided)", "174" => "Deep Repair (guided)", _ => Title
    };
    public string RunNote => ExecutionPolicy.NeedsConsole(Id)
        ? "Opens the existing command in a console window. Answer its prompts there; press Enter when finished to return here."
        : Id switch
    {
        "002" => "Opens Windows File Explorer.",
        "003" => "Opens your Windows Documents folder in File Explorer.",
        "004" => "Opens your Downloads folder in File Explorer.",
        "005" => "Opens your Desktop folder in File Explorer.",
        "007" => "Opens Windows taskbar settings.",
        "008" => "Opens Windows Task Manager.",
        "011" => "Opens Windows display settings.",
        "052" => "Reads a memory snapshot. Windows settings stay unchanged.",
        "175" => "Checks command availability and report-folder writing. Saves TXT and JSON reports.",
        "171" => "Runs the existing general diagnostic checks and saves TXT and JSON reports. This may take a few minutes.",
        "172" => "Runs the existing deep diagnostics. Answer the optional SCAN question below the output; checks may take time.",
        _ => "Uses the existing Toolkit command. Its questions and confirmations appear below the output."
    };
}

public sealed class Catalog
{
    public int Schema { get; set; }
    public List<Category> Categories { get; set; } = [];
    public List<ToolAction> Tools { get; set; } = [];
    public Dictionary<string, string> SourceHashes { get; set; } = [];
    public static Catalog Load()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Toolkit.Desktop.Data.Catalog.json")
            ?? throw new InvalidDataException("The command catalog is missing. Rebuild the desktop app.");
        var catalog = JsonSerializer.Deserialize<Catalog>(stream) ?? throw new InvalidDataException("The command catalog could not be read.");
        if (catalog.Schema != 1 || catalog.Tools.Count != 231 || catalog.Tools.Select(t => t.Id).Distinct().Count() != 231)
            throw new InvalidDataException("The command catalog does not match Toolkit V5.1.");
        return catalog;
    }

    public IEnumerable<ToolAction> Filter(string category, string query)
    {
        var trimmed = query.Trim();
        var id = trimmed.ToUpperInvariant() switch { "A" => "171", "B" => "172", "C" => "173", "D" => "174", _ => trimmed };
        if (int.TryParse(id, out var number)) id = number.ToString("000");
        if (trimmed.StartsWith('r') || trimmed.StartsWith('R'))
            if (int.TryParse(trimmed[1..], out var repair)) id = $"R{repair:00}";
        var exactId = Tools.Any(tool => tool.Id.Equals(id, StringComparison.OrdinalIgnoreCase));
        return Tools.Where(tool => category switch
        {
            "all" => true, "connected" => tool.Connected,
            "workflows" => tool.Id is "171" or "172" or "173" or "174",
            "repair" => tool.Section == "repair", _ => tool.CategoryKey == category
        }).Where(tool => trimmed.Length == 0 || (exactId
            ? tool.Id.Equals(id, StringComparison.OrdinalIgnoreCase)
            : ($"{tool.Id} {tool.Title} {tool.Description} {tool.CategoryName}").Contains(trimmed, StringComparison.OrdinalIgnoreCase)));
    }
}

public static class ExecutionPolicy
{
    public static bool IsWindowLauncher(string id) => id is "002" or "003" or "004" or "005" or "007" or "008" or "011";
    public static bool IsCancellableCheck(string id) => id is "052" or "175" or "171";
    public static bool NeedsConsole(string id) => id is "018" or "019" or "020" or "050" or "116" or "121" or "131" or "146" or "149" or "158" or "166" or "R41" or "R42";
    public static bool IsConnected(string id) => System.Text.RegularExpressions.Regex.IsMatch(id,
        @"\A(?:00[1-9]|0[1-9][0-9]|1[0-7][0-9]|180|R0[1-9]|R[1-4][0-9]|R5[01])\z");
    public static void EnsureConnected(string id)
    {
        if (!IsConnected(id)) throw new InvalidOperationException("Choose an existing Toolkit command ID.");
    }
}

public sealed class Finding
{
    public string Id { get; set; } = "";
    public string Check { get; set; } = "";
    public string Status { get; set; } = "NO DATA";
    public string Summary { get; set; } = "";
    public string Detail { get; set; } = "";
    public string SuggestedAction { get; set; } = "";
}

public sealed record DiagnosticResult(string TextPath, string JsonPath, IReadOnlyList<Finding> Findings)
{
    public string Summary => string.Join("   ·   ", new[] { "PASS", "WARNING", "ERROR", "NO DATA" }
        .Select(status => $"{Findings.Count(f => f.Status == status)} {status}"));
}

public sealed record OutputLine(string Text, bool IsError = false);
public sealed record ProcessResult(int ExitCode, string Output, bool HadErrors, bool Cancelled);
public sealed record RunResult(string Status, string Output, DiagnosticResult? Report = null);

public sealed class RunRecord : Observable
{
    public string Id { get; init; } = "";
    public string Title { get; init; } = "";
    public DateTime Started { get; init; } = DateTime.Now;
    public string TimeLabel => Started.ToString("HH:mm:ss");
    private string _status = "Running";
    public string Status { get => _status; set => Set(ref _status, value); }
    private string _output = "";
    public string Output { get => _output; set => Set(ref _output, value); }
    private DiagnosticResult? _report;
    public DiagnosticResult? Report { get => _report; set { Set(ref _report, value); Changed(nameof(Findings)); Changed(nameof(Summary)); Changed(nameof(HasReport)); } }
    public IReadOnlyList<Finding> Findings => Report?.Findings ?? [];
    public string Summary => Report?.Summary ?? "No diagnostic report for this run.";
    public bool HasReport => Report != null;
    public void Append(OutputLine line)
    {
        if (_output.Length < 1_000_000) Output += (line.IsError ? "[stderr] " : "") + line.Text + Environment.NewLine;
    }
}

using System.IO;
using System.Security.Cryptography;
using System.Security.Principal;

namespace Toolkit.Desktop;

public static class ToolkitEnvironment
{
    public static bool IsAdministrator()
    {
        using var identity = WindowsIdentity.GetCurrent();
        return new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator);
    }

    public static string? FindRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        for (var depth = 0; directory != null && depth < 8; depth++, directory = directory.Parent)
        {
            var candidate = Path.Combine(directory.FullName, "Toolkit-V5.1");
            if (File.Exists(Path.Combine(candidate, "src", "Toolkit.ps1"))) return candidate;
        }
        return null;
    }

    public static string ReportsFolder
    {
        get
        {
            var documents = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
            if (string.IsNullOrEmpty(documents) || !Directory.Exists(documents))
                documents = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            return Path.Combine(documents, "Toolkit-Reports");
        }
    }

    public static string PowerShellPath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe");

    public static void VerifySources(string root, IReadOnlyDictionary<string, string> hashes)
    {
        foreach (var (relative, expected) in hashes)
        {
            var path = Path.GetFullPath(Path.Combine(root, relative));
            if (!IsWithin(path, root) || !File.Exists(path)) throw new IOException($"Toolkit file is missing: {relative}");
            using var stream = File.OpenRead(path);
            if (!Convert.ToHexString(SHA256.HashData(stream)).Equals(expected, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("The toolkit source has changed since this desktop build. Run Build-Desktop.ps1 to refresh its catalog before running commands.");
        }
    }

    public static bool IsWithin(string path, string root) => Path.GetFullPath(path).StartsWith(
        Path.TrimEndingDirectorySeparator(Path.GetFullPath(root)) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
}

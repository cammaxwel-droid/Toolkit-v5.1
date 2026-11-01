using System.Windows;

namespace Toolkit.Desktop;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        try
        {
            var catalog = Catalog.Load();
            var root = ToolkitEnvironment.FindRoot();
            MainViewModel? viewModel = null;
            var transport = new ProcessTransport((question, token) => viewModel!.RequestAnswerAsync(question, token));
            viewModel = new MainViewModel(catalog, new CommandRunner(catalog, root ?? "", transport: transport), ToolkitEnvironment.IsAdministrator(), root != null);
            var window = new MainWindow(viewModel);
            MainWindow = window;
            window.Show();
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Toolkit Desktop could not start", MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown(1);
        }
    }
}

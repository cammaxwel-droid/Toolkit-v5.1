using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;

namespace Toolkit.Desktop;

public partial class MainWindow : Window
{
    public MainViewModel ViewModel { get; }
    private GridLength? _outputBeforePrompt;
    public MainWindow(MainViewModel viewModel)
    {
        InitializeComponent(); ViewModel = viewModel; DataContext = viewModel;
        SourceInitialized += (_, _) => SetTitleBar();
        Closing += WindowClosing;
        Closed += (_, _) => ViewModel.Dispose();
        viewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName != nameof(MainViewModel.HasPrompt)) return;
            if (viewModel.HasPrompt)
            {
                _outputBeforePrompt = OutputRow.Height;
                // Keep the command's choices visible above its question on small windows.
                if (OutputPanel.ActualHeight < 240) OutputRow.Height = new GridLength(1.1, GridUnitType.Star);
                Dispatcher.BeginInvoke(() => AnswerBox.Focus());
            }
            else if (_outputBeforePrompt is { } previous)
            {
                OutputRow.Height = previous; _outputBeforePrompt = null;
            }
        };
        PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.F && Keyboard.Modifiers == ModifierKeys.Control) { SearchBox.Focus(); SearchBox.SelectAll(); e.Handled = true; }
            else if (e.Key == Key.Escape && SearchBox.IsKeyboardFocusWithin) { ViewModel.Query = ""; e.Handled = true; }
        };
    }

    private void SearchBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key is Key.Down or Key.Up)
        {
            var index = ViewModel.SelectedTool == null ? -1 : ViewModel.VisibleTools.IndexOf(ViewModel.SelectedTool);
            index = Math.Clamp(index + (e.Key == Key.Down ? 1 : -1), 0, Math.Max(0, ViewModel.VisibleTools.Count - 1));
            if (ViewModel.VisibleTools.Count > 0) { ViewModel.SelectedTool = ViewModel.VisibleTools[index]; CommandList.ScrollIntoView(ViewModel.SelectedTool); }
            e.Handled = true;
        }
        else if (e.Key == Key.Enter)
        {
            // Search selection never executes a command. Enter moves focus to its explicit Run button.
            if (RunButton.IsEnabled) RunButton.Focus(); else CommandList.Focus();
            e.Handled = true;
        }
    }

    private void OutputBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (sender is TextBox box && (box.VerticalOffset >= box.ExtentHeight - box.ViewportHeight - 50 || box.VerticalOffset == 0)) box.ScrollToEnd();
    }

    private void AnswerBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;
        ViewModel.SendAnswerCommand.Execute(null); e.Handled = true;
    }

    private void WindowClosing(object? sender, CancelEventArgs e)
    {
        if (!ViewModel.Busy) return;
        e.Cancel = true;
        ViewModel.Notice = ViewModel.HasPrompt ? "The Toolkit is waiting for your answer below the output. Answer its question before closing."
            : "A command is running. Finish it in the output area or its console window before closing.";
    }

    private void SetTitleBar()
    {
        var handle = new WindowInteropHelper(this).Handle;
        var dark = 1; var caption = 0x000B0E08;
        DwmSetWindowAttribute(handle, 20, ref dark, sizeof(int));
        DwmSetWindowAttribute(handle, 35, ref caption, sizeof(int));
        var monitor = new MonitorInfo { Size = Marshal.SizeOf<MonitorInfo>() };
        var area = SystemParameters.WorkArea;
        if (GetMonitorInfo(MonitorFromWindow(handle, 2), ref monitor))
        {
            // Native work-area pixels and this window's DPI avoid primary-screen
            // work-area scaling errors. Apply before Show, with no later centering.
            var scale = Math.Max(96u, GetDpiForWindow(handle)) / 96d;
            var work = monitor.Work;
            area = new Rect(work.Left / scale, work.Top / scale,
                (work.Right - work.Left) / scale, (work.Bottom - work.Top) / scale);
        }
        var width = Math.Min(1000, Math.Max(1, area.Width - 48));
        var height = Math.Min(680, Math.Max(1, area.Height - 48));
        // MinHeight/MinWidth take precedence over Height/Width in WPF.
        // Lower the minimum too when display scaling leaves less usable space.
        MinWidth = width; MinHeight = height;
        Width = width; Height = height;
        Left = area.Left + (area.Width - width) / 2;
        Top = area.Top + Math.Min(32, (area.Height - height) / 2);
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeRect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    private struct MonitorInfo { public int Size; public NativeRect Monitor, Work; public uint Flags; }
    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
    [DllImport("user32.dll")]
    private static extern uint GetDpiForWindow(IntPtr hwnd);
}

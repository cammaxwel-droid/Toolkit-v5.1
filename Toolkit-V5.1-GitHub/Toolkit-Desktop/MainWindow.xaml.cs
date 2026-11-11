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
    private ColumnDefinition? _rotatedOutputColumn;
    private bool _outputBeforePromptWasColumn;
    private bool _rotatedLayout;
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
                _outputBeforePromptWasColumn = _rotatedLayout && _rotatedOutputColumn != null;
                if (_outputBeforePromptWasColumn)
                {
                    _outputBeforePrompt = _rotatedOutputColumn!.Width;
                    if (OutputPanel.ActualWidth < 360) _rotatedOutputColumn.Width = new GridLength(1.35, GridUnitType.Star);
                }
                else
                {
                    _outputBeforePrompt = OutputRow.Height;
                    // Keep the command's choices visible above its question on small windows.
                    if (OutputPanel.ActualHeight < 240) OutputRow.Height = new GridLength(1.1, GridUnitType.Star);
                }
                Dispatcher.BeginInvoke(() => AnswerBox.Focus());
            }
            else if (_outputBeforePrompt is { } previous)
            {
                if (_outputBeforePromptWasColumn && _rotatedOutputColumn != null) _rotatedOutputColumn.Width = previous;
                else OutputRow.Height = previous;
                _outputBeforePrompt = null; _outputBeforePromptWasColumn = false;
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

    private void RotateLayout_Click(object sender, RoutedEventArgs e)
    {
        _rotatedLayout = !_rotatedLayout;
        WorkspaceGrid.ColumnDefinitions.Clear();
        WorkspaceGrid.RowDefinitions.Clear();
        if (_rotatedLayout)
        {
            WorkspaceGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            WorkspaceGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1.2, GridUnitType.Star) });
            WorkspaceGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(8) });
            WorkspaceGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(0.8, GridUnitType.Star) });
            Grid.SetRow(MainPanel, 0); Grid.SetColumn(MainPanel, 0);
            Grid.SetRow(WorkspaceSplitter, 1); Grid.SetColumn(WorkspaceSplitter, 0);
            Grid.SetRow(SidePanels, 2); Grid.SetColumn(SidePanels, 0);
            SidePanels.RowDefinitions.Clear();
            SidePanels.ColumnDefinitions.Clear();
            SidePanels.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.1, GridUnitType.Star) });
            SidePanels.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            _rotatedOutputColumn = new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) };
            SidePanels.ColumnDefinitions.Add(_rotatedOutputColumn);
            Grid.SetRow(DetailsPanel, 0); Grid.SetColumn(DetailsPanel, 0);
            Grid.SetRow(SideSplitter, 0); Grid.SetColumn(SideSplitter, 1);
            Grid.SetRow(OutputPanel, 0); Grid.SetColumn(OutputPanel, 2);
            SideSplitter.ResizeDirection = GridResizeDirection.Columns;
            SideSplitter.Width = 8; SideSplitter.Height = double.NaN;
            SideSplitter.HorizontalAlignment = HorizontalAlignment.Center;
            SideSplitter.VerticalAlignment = VerticalAlignment.Stretch;
            WorkspaceSplitter.ResizeDirection = GridResizeDirection.Rows;
            WorkspaceSplitter.Width = double.NaN; WorkspaceSplitter.Height = 8;
            WorkspaceSplitter.HorizontalAlignment = HorizontalAlignment.Stretch;
            WorkspaceSplitter.VerticalAlignment = VerticalAlignment.Center;
            RotateLayoutButton.Content = "ROTATE BACK";
        }
        else
        {
            _rotatedOutputColumn = null;
            WorkspaceGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(3, GridUnitType.Star) });
            WorkspaceGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            WorkspaceGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(2, GridUnitType.Star) });
            WorkspaceGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            Grid.SetRow(MainPanel, 0); Grid.SetColumn(MainPanel, 0);
            Grid.SetRow(WorkspaceSplitter, 0); Grid.SetColumn(WorkspaceSplitter, 1);
            Grid.SetRow(SidePanels, 0); Grid.SetColumn(SidePanels, 2);
            SidePanels.ColumnDefinitions.Clear();
            SidePanels.RowDefinitions.Clear();
            SidePanels.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star), MinHeight = 180 });
            SidePanels.RowDefinitions.Add(new RowDefinition { Height = new GridLength(8) });
            SidePanels.RowDefinitions.Add(OutputRow);
            Grid.SetRow(DetailsPanel, 0); Grid.SetColumn(DetailsPanel, 0);
            Grid.SetRow(SideSplitter, 1); Grid.SetColumn(SideSplitter, 0);
            Grid.SetRow(OutputPanel, 2); Grid.SetColumn(OutputPanel, 0);
            SideSplitter.ResizeDirection = GridResizeDirection.Rows;
            SideSplitter.Width = double.NaN; SideSplitter.Height = 8;
            SideSplitter.HorizontalAlignment = HorizontalAlignment.Stretch;
            SideSplitter.VerticalAlignment = VerticalAlignment.Center;
            WorkspaceSplitter.ResizeDirection = GridResizeDirection.Columns;
            WorkspaceSplitter.Width = 8; WorkspaceSplitter.Height = double.NaN;
            WorkspaceSplitter.HorizontalAlignment = HorizontalAlignment.Center;
            WorkspaceSplitter.VerticalAlignment = VerticalAlignment.Stretch;
            RotateLayoutButton.Content = "ROTATE LAYOUT";
        }
        WorkspaceGrid.UpdateLayout();
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
        var minimumWidth = Math.Min(1000, Math.Max(1, area.Width - 48));
        var minimumHeight = Math.Min(680, Math.Max(1, area.Height - 48));
        var width = Math.Min(1500, Math.Max(minimumWidth, area.Width - 48));
        var height = Math.Min(900, Math.Max(minimumHeight, area.Height - 48));
        // Fit the larger three-panel workspace to the monitor while preserving
        // a useful resize minimum on screens with less available space.
        MinWidth = minimumWidth; MinHeight = minimumHeight;
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

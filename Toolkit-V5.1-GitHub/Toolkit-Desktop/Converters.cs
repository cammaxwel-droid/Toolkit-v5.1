using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;

namespace Toolkit.Desktop;

public sealed class StatusBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        new SolidColorBrush((Color)ColorConverter.ConvertFromString(value?.ToString() switch
        {
            "PASS" => "#61E8B8", "WARNING" or "CHANGE" => "#E6B64E",
            "ERROR" or "REPAIR" => "#F18D89", "REPORT" => "#6CCFE6", _ => "#9BB3A8"
        }));
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => throw new NotSupportedException();
}

public sealed class InverseVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) => value is true ? Visibility.Collapsed : Visibility.Visible;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => throw new NotSupportedException();
}

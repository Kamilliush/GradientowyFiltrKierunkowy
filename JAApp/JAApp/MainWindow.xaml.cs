using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace JAApp
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        [DllImport("/../../../../bin/JADll.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern int MyProc1(int a, int b);
        public MainWindow()
        {
            InitializeComponent();

            int a = 2;
            int b = 2;

            Debug.WriteLine(MyProc1(a, b));
        }
    }
}
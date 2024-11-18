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
using System.IO;
using System.Reflection.Metadata;


namespace JAApp
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        [DllImport("/../../../../bin/JADll.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern void MyProc1(IntPtr pixelData, int width, int startY, int segmentHeight, int imageHeight);

        [DllImport("/../../../../bin/cppDll.dll", CallingConvention = CallingConvention.StdCall)]

        public static extern void Add(IntPtr pixelData, int width, int startY, int segmentHeight, int imageHeight);

        private BitmapSource bitmap;
        public MainWindow()
        {
            InitializeComponent();        
        }
        public void Start()
        {


            int height = bitmap.PixelHeight;
            int width = bitmap.PixelWidth;
            int bytesPerPixel = 3;


            if (threadsNum.SelectedItem is ComboBoxItem selectedItem)
            {
                int.TryParse(selectedItem.Content.ToString(), out int threadsNumber);


                WriteableBitmap filteredBitmap = new WriteableBitmap(bitmap);

                filteredBitmap.Lock();
                try
                {
                    int length = width * height * bytesPerPixel;
                    byte[] pixelData = new byte[length];
                    IntPtr pBackBuffer = filteredBitmap.BackBuffer;
                    Marshal.Copy(pBackBuffer, pixelData, 0, length);

                    // Przypięcie tablicy pixelData do pamięci, by uniknąć problemów z GC
                    GCHandle handle = GCHandle.Alloc(pixelData, GCHandleType.Pinned);
                    IntPtr pixelDataPtr = Marshal.UnsafeAddrOfPinnedArrayElement(pixelData, 0);

                    // Obliczanie optymalnego podziału w pionie
                    int baseSegmentHeight = height / threadsNumber;
                    int extraRows = height % threadsNumber;

                    int[] startYs = new int[threadsNumber];
                    int[] endYs = new int[threadsNumber];

                    // Obliczanie start i end Y dla każdego wątku
                    int currentStartY = 0;
                    for (int i = 0; i < threadsNumber; i++)
                    {
                        int segmentHeight = baseSegmentHeight + (i < extraRows ? 1 : 0);
                        startYs[i] = currentStartY;
                        endYs[i] = currentStartY + segmentHeight - 1;
                        currentStartY = endYs[i] + 1; // Kolejny segment zaczyna się od następnego wiersza
                    }

                    bool cppRadioButton = (bool)CPP.IsChecked;
                    bool asmRadioButton = (bool)ASM.IsChecked;

                    // Parallel processing of image sections
                    Parallel.For(0, threadsNumber, i =>
                    {
                        int startY = startYs[i];
                        int segmentHeight = endYs[i] - startY + 1;



                        if (cppRadioButton)
                        {
                            Add(pixelDataPtr, width, startY, segmentHeight, height);
                        }
                        else if (asmRadioButton)
                        {
                            Add(pixelDataPtr, width, startY, segmentHeight, height);

                        }


                    });

                    // Kopiowanie zmodyfikowanych danych z powrotem do bitmapy
                    Marshal.Copy(pixelData, 0, pBackBuffer, length);

                    // Zwalnianie zasobów
                    handle.Free();
                }
                finally
                {
                    filteredBitmap.Unlock();
                }

                imageAfter.Source = filteredBitmap;

            }
        }

        private void Click(object sender, RoutedEventArgs e)
        {
            
            if (image.Source != null) { Start(); }
        }
        private void ImageDragEnter(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                string[] files = (string[])e.Data.GetData(DataFormats.FileDrop);
                if (files != null && IsValidImageFile(files[0]))
                {
                    e.Effects = DragDropEffects.Copy;
                }
                else
                {
                    e.Effects = DragDropEffects.None;
                }
            }
            else
            {
                e.Effects = DragDropEffects.None;
            }
        }

        private void ImageDrop(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                string[] files = (string[])e.Data.GetData(DataFormats.FileDrop);
                if (files != null && IsValidImageFile(files[0]))
                {
                    SetImage(files[0]);
                }
                else
                {
                    Console.WriteLine("Nieprawidłowy plik obrazu.");
                }
            }
        }
        private void SetImage(string filePath)
        {
            try
            {
                BitmapImage bitmapImage = new BitmapImage();
                bitmapImage.BeginInit();
                bitmapImage.UriSource = new Uri(filePath, UriKind.Absolute);
                bitmapImage.CacheOption = BitmapCacheOption.OnLoad;
                bitmapImage.EndInit();

                FormatConvertedBitmap rgbBitmap = new FormatConvertedBitmap(bitmapImage, PixelFormats.Rgb24, null, 0);
                bitmap = rgbBitmap;

                image.Source = bitmap;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Błąd podczas ładowania obrazu: {ex.Message}");
            }
        }

        private bool IsValidImageFile(string filePath)
        {
            string extension = System.IO.Path.GetExtension(filePath)?.ToLower();
            return extension == ".png" || extension == ".jpg" || extension == ".jpeg" || extension == ".bmp";
        }
    }
}
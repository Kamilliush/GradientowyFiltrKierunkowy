using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.IO;
using System.Reflection.Metadata;
using System.Threading.Tasks;

namespace JAApp
{
    public partial class MainWindow : Window
    {
        // Sygnatury funkcji DLL:
        [DllImport("/../../../../bin/JADll.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern void alg(IntPtr pixelData, IntPtr outputData, int width, int startY, int endY, int imageHeight);

        [DllImport("/../../../../bin/cppDll.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern void Add(IntPtr pixelData, IntPtr outputData, int width, int startY, int endY, int imageHeight);

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
                if (!int.TryParse(selectedItem.Content.ToString(), out int threadsNumber))
                    return;

                WriteableBitmap filteredBitmap = new WriteableBitmap(bitmap);

                filteredBitmap.Lock();
                try
                {
                    int length = width * height * bytesPerPixel;
                    byte[] pixelData = new byte[length];
                    byte[] outputData = new byte[length]; // Bufor wyjściowy

                    IntPtr pBackBuffer = filteredBitmap.BackBuffer;
                    Marshal.Copy(pBackBuffer, pixelData, 0, length);

                    // Przypięcie tablic do pamięci, by uniknąć problemów z GC
                    GCHandle handleInput = GCHandle.Alloc(pixelData, GCHandleType.Pinned);
                    GCHandle handleOutput = GCHandle.Alloc(outputData, GCHandleType.Pinned);
                    IntPtr pixelDataPtr = Marshal.UnsafeAddrOfPinnedArrayElement(pixelData, 0);
                    IntPtr outputDataPtr = Marshal.UnsafeAddrOfPinnedArrayElement(outputData, 0);

                    // Obliczanie podziału na startY i endY
                    int baseSegmentHeight = height / threadsNumber;
                    int extraRows = height % threadsNumber;

                    int[] startYs = new int[threadsNumber];
                    int[] endYs = new int[threadsNumber];

                    int currentStartY = 0;
                    for (int i = 0; i < threadsNumber; i++)
                    {
                        int segmentHeight = baseSegmentHeight + (i < extraRows ? 1 : 0);
                        // endY = ostatni wiersz w tym segmencie (inclusive)
                        int currentEndY = currentStartY + segmentHeight - 1;

                        startYs[i] = currentStartY;
                        endYs[i] = currentEndY;

                        currentStartY = currentEndY + 1;
                    }

                    // Tu dopisujemy wyświetlenie segmentów w GUI:
                    StringBuilder sb = new StringBuilder();
                    for (int i = 0; i < threadsNumber; i++)
                    {
                        sb.AppendLine(
                            $"Segment {i}: startY = {startYs[i]}, endY = {endYs[i]}"
                        );
                    }
                    SegmentsTextBlock.Text = sb.ToString(); // <-- Wyświetlamy w interfejsie

                    bool cppRadioButton = (bool)CPP.IsChecked;
                    bool asmRadioButton = (bool)ASM.IsChecked;

                    // Parallel processing of image sections
                    Parallel.For(0, threadsNumber, i =>
                    {
                        int startY = startYs[i];
                        int endY = endYs[i];

                        if (cppRadioButton)
                            Add(pixelDataPtr, outputDataPtr, width, startY, endY, height);
                        else if (asmRadioButton)
                            alg(pixelDataPtr, outputDataPtr, width, startY, endY, height);
                    });

                    // Utwórz nową bitmapę z bufora wyjściowego
                    WriteableBitmap outputBitmap = new WriteableBitmap(width, height, bitmap.DpiX, bitmap.DpiY, PixelFormats.Rgb24, null);
                    outputBitmap.Lock();
                    Marshal.Copy(outputData, 0, outputBitmap.BackBuffer, length);
                    outputBitmap.AddDirtyRect(new Int32Rect(0, 0, width, height));
                    outputBitmap.Unlock();

                    // Przypisz nową bitmapę jako wynik
                    imageAfter.Source = outputBitmap;

                    // Zwalnianie zasobów
                    handleInput.Free();
                    handleOutput.Free();
                }
                finally
                {
                    filteredBitmap.Unlock();
                }
            }
        }

        private void Click(object sender, RoutedEventArgs e)
        {
            if (image.Source != null)
            {
                Start();
            }
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

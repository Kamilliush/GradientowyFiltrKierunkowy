using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Shapes;
using System.Linq;

namespace JAApp
{
    public partial class MainWindow : Window
    {
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
                    byte[] outputData = new byte[length];

                    IntPtr pBackBuffer = filteredBitmap.BackBuffer;
                    Marshal.Copy(pBackBuffer, pixelData, 0, length);

                    GCHandle handleInput = GCHandle.Alloc(pixelData, GCHandleType.Pinned);
                    GCHandle handleOutput = GCHandle.Alloc(outputData, GCHandleType.Pinned);
                    IntPtr pixelDataPtr = Marshal.UnsafeAddrOfPinnedArrayElement(pixelData, 0);
                    IntPtr outputDataPtr = Marshal.UnsafeAddrOfPinnedArrayElement(outputData, 0);

                    int baseSegmentHeight = height / threadsNumber;
                    int extraRows = height % threadsNumber;

                    int[] startYs = new int[threadsNumber];
                    int[] endYs = new int[threadsNumber];

                    int currentStartY = 0;
                    for (int i = 0; i < threadsNumber; i++)
                    {
                        int segmentHeight = baseSegmentHeight + (i < extraRows ? 1 : 0);
                        int currentEndY = currentStartY + segmentHeight - 1;

                        startYs[i] = currentStartY;
                        endYs[i] = currentEndY;

                        currentStartY = currentEndY + 1;
                    }

                    StringBuilder sb = new StringBuilder();
                    for (int i = 0; i < threadsNumber; i++)
                    {
                        sb.AppendLine($"Segment {i}: startY = {startYs[i]}, endY = {endYs[i]}");
                    }
                    SegmentsTextBlock.Text = sb.ToString();

                    bool cppRadioButton = (bool)CPP.IsChecked;
                    bool asmRadioButton = (bool)ASM.IsChecked;

                    Stopwatch stopwatch = Stopwatch.StartNew();

                    Parallel.For(0, threadsNumber, i =>
                    {
                        int startY = startYs[i];
                        int endY = endYs[i];

                        if (cppRadioButton)
                            Add(pixelDataPtr, outputDataPtr, width, startY, endY, height);
                        else if (asmRadioButton)
                            alg(pixelDataPtr, outputDataPtr, width, startY, endY, height);
                    });

                    stopwatch.Stop();
                    double elapsedSeconds = stopwatch.Elapsed.TotalSeconds;
                    ExecutionTimeTextBlock.Text = $"Czas: {elapsedSeconds:F6} seconds";

                    WriteableBitmap outputBitmap = new WriteableBitmap(width, height, bitmap.DpiX, bitmap.DpiY, PixelFormats.Rgb24, null);
                    outputBitmap.Lock();
                    Marshal.Copy(outputData, 0, outputBitmap.BackBuffer, length);
                    outputBitmap.AddDirtyRect(new Int32Rect(0, 0, width, height));
                    outputBitmap.Unlock();

                    imageAfter.Source = outputBitmap;

                    // Wyświetl histogramy
                    DisplayHistogram(pixelData, width, height, HistogramBefore);
                    DisplayHistogram(outputData, width, height, HistogramAfter);

                    handleInput.Free();
                    handleOutput.Free();
                }
                finally
                {
                    filteredBitmap.Unlock();
                }
            }
        }

        private void DisplayHistogram(byte[] pixelData, int width, int height, Canvas histogramCanvas)
        {
            int[] redHistogram = new int[256];
            int[] greenHistogram = new int[256];
            int[] blueHistogram = new int[256];

            for (int i = 0; i < pixelData.Length; i += 3)
            {
                redHistogram[pixelData[i]]++;
                greenHistogram[pixelData[i + 1]]++;
                blueHistogram[pixelData[i + 2]]++;
            }

            int maxCount = new[] { redHistogram.Max(), greenHistogram.Max(), blueHistogram.Max() }.Max();

            histogramCanvas.Children.Clear();
            double scaleX = histogramCanvas.ActualWidth / 256.0;
            double scaleY = histogramCanvas.ActualHeight / maxCount;

            for (int i = 0; i < 256; i++)
            {
                // Red
                DrawBar(histogramCanvas, i, redHistogram[i], scaleX, scaleY, Brushes.Red);

                // Green
                DrawBar(histogramCanvas, i, greenHistogram[i], scaleX, scaleY, Brushes.Green);

                // Blue
                DrawBar(histogramCanvas, i, blueHistogram[i], scaleX, scaleY, Brushes.Blue);
            }
        }

        private void DrawBar(Canvas canvas, int x, int value, double scaleX, double scaleY, Brush color)
        {
            Rectangle rect = new Rectangle
            {
                Width = scaleX - 1,
                Height = value * scaleY,
                Fill = color
            };
            Canvas.SetLeft(rect, x * scaleX);
            Canvas.SetTop(rect, canvas.ActualHeight - rect.Height);
            canvas.Children.Add(rect);
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

using Microsoft.Win32;   // Dla OpenFileDialog i SaveFileDialog
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;

namespace JAApp
{
    public partial class MainWindow : Window
    {
        [DllImport("JADll.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern void alg(IntPtr pixelData, IntPtr outputData, int width, int startY, int endY, int imageHeight);

        [DllImport("cppDll.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern void Add(IntPtr pixelData, IntPtr outputData, int width, int startY, int endY, int imageHeight);

        private BitmapSource bitmap;
        private WriteableBitmap outputBitmap; // Przechowujemy wynik przetwarzania

        // Ścieżka do aktualnie wczytanego pliku. Służy do sprawdzenia, czy nie nadpisujemy oryginału.
        private string loadedImagePath;

        public MainWindow()
        {
            InitializeComponent();

            // Ustawiamy domyślną wartość suwaka na liczbę logicznych wątków w procesorze,
            // ale ograniczamy do 128, aby nie przekraczać maksimum zdefiniowanego w XAML.
            int processorCount = Environment.ProcessorCount;
            threadsSlider.Value = Math.Min(processorCount, 128);
        }

        private void CPP_Click(object sender, RoutedEventArgs e)
        {
            if (bitmap != null)
            {
                ProcessImage(useCpp: true);
            }
        }

        private void ASM_Click(object sender, RoutedEventArgs e)
        {
            if (bitmap != null)
            {
                ProcessImage(useCpp: false);
            }
        }

        /// <summary>
        /// Główna metoda wykonująca algorytm. 
        /// Parametr useCpp decyduje, czy wywołujemy funkcję Add (CPP) czy alg (ASM).
        /// </summary>
        /// <param name="useCpp"></param>
        private void ProcessImage(bool useCpp)
        {
            int height = bitmap.PixelHeight;
            int width = bitmap.PixelWidth;
            int bytesPerPixel = 3;

            // Pobranie liczby wątków z suwaka
            int threadsNumber = (int)threadsSlider.Value;

            // Przygotowanie do zapisu efektu w WriteableBitmap
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

                // Podział na segmenty
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

                // Wyświetlamy informacje o segmentach
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < threadsNumber; i++)
                {
                    sb.AppendLine($"Segment {i}: startY = {startYs[i]}, endY = {endYs[i]}");
                }
                SegmentsTextBlock.Text = sb.ToString();

                // Mierzymy czas
                Stopwatch stopwatch = Stopwatch.StartNew();

                // Przetwarzanie równoległe
                Parallel.For(0, threadsNumber, i =>
                {
                    int startY = startYs[i];
                    int endY = endYs[i];

                    if (useCpp)
                        Add(pixelDataPtr, outputDataPtr, width, startY, endY, height);
                    else
                        alg(pixelDataPtr, outputDataPtr, width, startY, endY, height);
                });

                stopwatch.Stop();
                double elapsedSeconds = stopwatch.Elapsed.TotalSeconds;
                ExecutionTimeTextBlock.Text = $"Czas: {elapsedSeconds:F6} s";

                // Przygotowujemy wynik do wyświetlenia
                outputBitmap = new WriteableBitmap(width, height, bitmap.DpiX, bitmap.DpiY, PixelFormats.Rgb24, null);
                outputBitmap.Lock();
                Marshal.Copy(outputData, 0, outputBitmap.BackBuffer, length);
                outputBitmap.AddDirtyRect(new Int32Rect(0, 0, width, height));
                outputBitmap.Unlock();

                imageAfter.Source = outputBitmap;

                // Wyświetlamy histogramy
                DisplayHistogram(pixelData, width, height, HistogramBefore);
                DisplayHistogram(outputData, width, height, HistogramAfter);

                handleInput.Free();
                handleOutput.Free();

                // Uaktywniamy przycisk "Zapisz", bo mamy już wynik
                saveButton.IsEnabled = true;
            }
            finally
            {
                filteredBitmap.Unlock();
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
            double scaleY = (maxCount == 0) ? 0 : histogramCanvas.ActualHeight / (double)maxCount;

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

        /// <summary>
        /// Obsługa przycisku "Wybierz zdjęcie" - otwieramy okno dialogowe z filtrem plików graficznych.
        /// </summary>
        private void WybierzZdjecie_Click(object sender, RoutedEventArgs e)
        {
            OpenFileDialog openFileDialog = new OpenFileDialog
            {
                Filter = "Obrazy (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp"
            };

            if (openFileDialog.ShowDialog() == true)
            {
                SetImage(openFileDialog.FileName);
            }
        }

        /// <summary>
        /// Ustawia wybrany plik jako główne źródło obrazu (po konwersji do Rgb24).
        /// </summary>
        /// <param name="filePath"></param>
        private void SetImage(string filePath)
        {
            try
            {
                BitmapImage bitmapImage = new BitmapImage();
                bitmapImage.BeginInit();
                bitmapImage.UriSource = new Uri(filePath, UriKind.Absolute);
                bitmapImage.CacheOption = BitmapCacheOption.OnLoad;
                bitmapImage.EndInit();

                // Konwersja do Rgb24
                FormatConvertedBitmap rgbBitmap = new FormatConvertedBitmap(bitmapImage, PixelFormats.Rgb24, null, 0);
                bitmap = rgbBitmap;

                image.Source = bitmap;

                // Zapamiętujemy ścieżkę, aby nie pozwolić na jej nadpisanie
                loadedImagePath = filePath;

                // Zerujemy ostatni wynik i blokujemy przycisk "Zapisz"
                imageAfter.Source = null;
                saveButton.IsEnabled = false;
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

        /// <summary>
        /// Obsługa przycisku "Zapisz" - zapisuje przetworzony obraz do wybranego pliku.
        /// </summary>
        private void Zapisz_Click(object sender, RoutedEventArgs e)
        {
            if (outputBitmap == null)
                return;

            SaveFileDialog saveFileDialog = new SaveFileDialog
            {
                Filter = "PNG Image|*.png|JPEG Image|*.jpg;*.jpeg|BMP Image|*.bmp"
            };

            if (saveFileDialog.ShowDialog() == true)
            {
                string fileName = saveFileDialog.FileName;

                // Sprawdzamy, czy nie próbujemy nadpisać oryginalnego pliku
                if (!string.IsNullOrEmpty(loadedImagePath) &&
                    string.Equals(fileName, loadedImagePath, StringComparison.OrdinalIgnoreCase))
                {
                    MessageBox.Show("Nie można nadpisać oryginalnego pliku!",
                                    "Błąd zapisu",
                                    MessageBoxButton.OK,
                                    MessageBoxImage.Warning);
                    return;
                }

                try
                {
                    using (FileStream fs = new FileStream(fileName, FileMode.Create))
                    {
                        BitmapEncoder encoder;
                        string ext = System.IO.Path.GetExtension(fileName).ToLower();
                        switch (ext)
                        {
                            case ".jpg":
                            case ".jpeg":
                                encoder = new JpegBitmapEncoder();
                                break;
                            case ".bmp":
                                encoder = new BmpBitmapEncoder();
                                break;
                            default:
                                encoder = new PngBitmapEncoder();
                                break;
                        }
                        encoder.Frames.Add(BitmapFrame.Create(outputBitmap));
                        encoder.Save(fs);
                    }
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Błąd zapisu pliku: {ex.Message}");
                }
            }
        }
    }
}

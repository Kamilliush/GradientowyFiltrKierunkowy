using Microsoft.Win32;
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
        private WriteableBitmap outputBitmap;
        private string loadedImagePath;

        public MainWindow()
        {
            InitializeComponent();

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
        private void ProcessImage(bool useCpp)
        {
            int height = bitmap.PixelHeight;
            int width = bitmap.PixelWidth;
            int bytesPerPixel = 3; // bo konwertujemy do Rgb24

            // Pobranie liczby wątków z suwaka
            int threadsNumber = (int)threadsSlider.Value;

            // Przygotowanie do zapisu efektu w WriteableBitmap
            WriteableBitmap filteredBitmap = new WriteableBitmap(bitmap);
            filteredBitmap.Lock();

            try
            {
                // 1) Tworzymy bufor tak duży jak cała pamięć obrazu (z paddingiem)
                int stride = filteredBitmap.BackBufferStride;
                int bufferSize = stride * height;
                byte[] readData = new byte[bufferSize];

                // 2) Kopiujemy z back‐buffera do readData
                Marshal.Copy(filteredBitmap.BackBuffer, readData, 0, bufferSize);

                // 3) Spłaszczamy dane do tablicy "pixelData" (width*height*3)
                //    tu nie ma już wierszowego paddingu – piksele idą ciągiem
                int flatSize = width * height * bytesPerPixel;
                byte[] pixelData = new byte[flatSize];
                byte[] outputData = new byte[flatSize];

                // Przepisujemy każdy wiersz z readData do pixelData
                for (int y = 0; y < height; y++)
                {
                    for (int x = 0; x < width; x++)
                    {
                        int sourceIndex = y * stride + x * bytesPerPixel; // indeks w readData
                        int destIndex = (y * width + x) * bytesPerPixel;  // indeks w spłaszczonej tablicy

                        pixelData[destIndex + 0] = readData[sourceIndex + 0];
                        pixelData[destIndex + 1] = readData[sourceIndex + 1];
                        pixelData[destIndex + 2] = readData[sourceIndex + 2];
                    }
                }

                // 4) Spinamy tablice z kodem niezarządzanym
                GCHandle handleInput = GCHandle.Alloc(pixelData, GCHandleType.Pinned);
                GCHandle handleOutput = GCHandle.Alloc(outputData, GCHandleType.Pinned);
                IntPtr pixelDataPtr = handleInput.AddrOfPinnedObject();
                IntPtr outputDataPtr = handleOutput.AddrOfPinnedObject();

                // Podział na segmenty do wątków
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

                // 5) Zapisujemy wynik z outputData z powrotem do readData (uwzględniając stride)
                for (int y = 0; y < height; y++)
                {
                    for (int x = 0; x < width; x++)
                    {
                        int destIndex = y * stride + x * bytesPerPixel; // indeks w readData
                        int sourceIndex = (y * width + x) * bytesPerPixel; // indeks w outputData

                        readData[destIndex + 0] = outputData[sourceIndex + 0];
                        readData[destIndex + 1] = outputData[sourceIndex + 1];
                        readData[destIndex + 2] = outputData[sourceIndex + 2];
                    }
                }

                // 6) Kopiujemy readData z powrotem do back‐buffera
                Marshal.Copy(readData, 0, filteredBitmap.BackBuffer, bufferSize);

                // Ustawiamy dirtyRect i kończymy
                filteredBitmap.AddDirtyRect(new Int32Rect(0, 0, width, height));
                filteredBitmap.Unlock();
                imageAfter.Source = filteredBitmap;
                outputBitmap = filteredBitmap; // zapamiętujemy wynik do ewentualnego zapisu

                // Wyświetlamy histogramy (zrobimy na bazie spłaszczonej tablicy outputData)
                DisplayHistogram(pixelData, width, height, HistogramBefore);
                DisplayHistogram(outputData, width, height, HistogramAfter);

                handleInput.Free();
                handleOutput.Free();

                // Uaktywniamy przycisk "Zapisz"
                saveButton.IsEnabled = true;
                MessageBox.Show("Pomyślnie wykonano algorytm");

            }
            catch (Exception ex)
            {
                filteredBitmap.Unlock();
                MessageBox.Show($"Błąd podczas przetwarzania obrazu: {ex.Message}");
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
                loadedImagePath = filePath;

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
                    MessageBox.Show("Pomyślnie zapisano obraz");

                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Błąd zapisu pliku: {ex.Message}");
                }
            }
        }
    }
}

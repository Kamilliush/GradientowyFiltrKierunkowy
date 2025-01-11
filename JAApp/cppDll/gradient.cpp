#include "pch.h"

#include <algorithm> // std::clamp

extern "C" __declspec(dllexport) void Add(
    unsigned char* pixelData,      // wejœcie
    unsigned char* outputData,     // wyjœcie
    int width,
    int startY,
    int endY,
    int imageHeight
)
{
    // Maska 3x3:
    //   -1  -1   1
    //   -1  -2   1
    //    1   1   1
    //
    // Dla piksela (x, y) liczymy sumê (R, G, B) z uwzglêdnieniem wag s¹siadów.
    // Jeœli piksel jest na brzegu (x == 0 || x == width - 1 || y == 0 || y == imageHeight - 1),
    // kopiujemy oryginaln¹ wartoœæ.

    // Ka¿dy piksel = 3 bajty (R, G, B).
    // Indeks piksela:  index = (y * width + x) * 3

    for (int y = startY; y <= endY && y < imageHeight; ++y)
    {
        for (int x = 0; x < width; ++x)
        {
            // Sprawdzenie brzegów
            bool isBorder = (x == 0 || x == width - 1 || y == 0 || y == imageHeight - 1);
            int index = (y * width + x) * 3;

            if (isBorder)
            {
                // Kopiujemy piksel oryginalny
                outputData[index + 0] = pixelData[index + 0]; // R
                outputData[index + 1] = pixelData[index + 1]; // G
                outputData[index + 2] = pixelData[index + 2]; // B
                continue;
            }

            // Jeœli nie jesteœmy na brzegu, obliczamy maskê 3×3.
            // accR, accG, accB – akumulatory
            int accR = 0, accG = 0, accB = 0;

            // Makro- / funkcja pomocnicza do pobierania 3 kana³ów i mno¿enia przez wagê
            auto addWeightedPixel = [&](int dx, int dy, int weight)
                {
                    int nx = x + dx;    // neighbor x
                    int ny = y + dy;    // neighbor y
                    int nIndex = (ny * width + nx) * 3;
                    accR += pixelData[nIndex + 0] * weight;
                    accG += pixelData[nIndex + 1] * weight;
                    accB += pixelData[nIndex + 2] * weight;
                };

            // Zgodnie z mask¹ 3x3 (kolejno wierszami):
            // (x-1, y-1) z wag¹ -1
            addWeightedPixel(-1, -1, -1);
            // (x,   y-1) z wag¹ -1
            addWeightedPixel(0, -1, -1);
            // (x+1, y-1) z wag¹  1
            addWeightedPixel(1, -1, 1);

            // (x-1, y)   z wag¹ -1
            addWeightedPixel(-1, 0, -1);
            // (x,   y)   z wag¹ -2
            addWeightedPixel(0, 0, -2);
            // (x+1, y)   z wag¹  1
            addWeightedPixel(1, 0, 1);

            // (x-1, y+1) z wag¹  1
            addWeightedPixel(-1, 1, 1);
            // (x,   y+1) z wag¹  1
            addWeightedPixel(0, 1, 1);
            // (x+1, y+1) z wag¹  1
            addWeightedPixel(1, 1, 1);

            // Teraz obcinamy wartoœci do [0..255]
            unsigned char r = static_cast<unsigned char>(std::clamp(accR, 0, 255));
            unsigned char g = static_cast<unsigned char>(std::clamp(accG, 0, 255));
            unsigned char b = static_cast<unsigned char>(std::clamp(accB, 0, 255));

            // Zapisujemy wynik do bufora wyjœciowego
            outputData[index + 0] = r;
            outputData[index + 1] = g;
            outputData[index + 2] = b;
        }
    }
}

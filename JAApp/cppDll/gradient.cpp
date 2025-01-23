#include "pch.h"          // Plik nag³ówkowy "pch.h" (precompiled header) - przyspiesza kompilacjê

#include <algorithm>      // Zawiera std::clamp (do ograniczania wartoœci)

// Funkcja Add (eksportowana z biblioteki DLL w stylu C) - g³ówny punkt wejœcia
// do przetwarzania obrazu w kodzie C++ (nak³adanie maski gradientowej 3x3).
extern "C" __declspec(dllexport) void Add(
    unsigned char* pixelData,      // wskaŸnik na oryginalne dane wejœciowe (piksele obrazu)
    unsigned char* outputData,     // wskaŸnik na bufor wyjœciowy (gdzie zapisujemy wynik)
    int width,                     // szerokoœæ obrazu w pikselach
    int startY,                    // indeks pocz¹tkowego wiersza do przetworzenia
    int endY,                      // indeks koñcowego wiersza do przetworzenia
    int imageHeight                // ca³kowita wysokoœæ obrazu
)
{
    // Maska 3x3, któr¹ wykorzystujemy do przetwarzania gradientowego:
    //   -1  -1   1
    //   -1  -2   1
    //    1   1   1
    //
    // Dla piksela (x, y) liczymy sumê osobno dla kana³ów R, G i B
    // z uwzglêdnieniem odpowiednich wag dla s¹siednich pikseli.
    //
    // Jeœli piksel jest na brzegu (x == 0 || x == width - 1 || y == 0 || y == imageHeight - 1),
    // to nie stosujemy maski, tylko kopiujemy oryginaln¹ wartoœæ piksela do wyniku.

    // Ka¿dy piksel zapisany jest w formacie 3 bajtów (R, G, B) w kolejnych komórkach pamiêci.
    // Indeks piksela w tablicy: index = (y * width + x) * 3.

    // Pêtla po wierszach (od startY do endY, z uwzglêdnieniem granicy imageHeight)
    for (int y = startY; y <= endY && y < imageHeight; ++y)
    {
        // Pêtla po kolumnach (x od 0 do width - 1)
        for (int x = 0; x < width; ++x)
        {
            // Sprawdzenie, czy piksel jest na krawêdzi (brzegu) obrazu
            bool isBorder = (x == 0 || x == width - 1 || y == 0 || y == imageHeight - 1);

            // Obliczenie indeksu w tablicy (odwo³anie do piksela (x,y))
            int index = (y * width + x) * 3;

            // Jeœli piksel jest na brzegu, kopiujemy oryginalne wartoœci R, G, B
            // bez zastosowania maski gradientowej
            if (isBorder)
            {
                outputData[index + 0] = pixelData[index + 0]; // R
                outputData[index + 1] = pixelData[index + 1]; // G
                outputData[index + 2] = pixelData[index + 2]; // B
                continue; // Przejœcie do nastêpnego piksela w tym wierszu
            }

            // Jeœli nie jesteœmy na brzegu, stosujemy filtr 3×3.
            // Tworzymy zmienne akumuluj¹ce sumê wag dla R, G i B.
            int accR = 0, accG = 0, accB = 0;

            // Lambda (funkcja anonimowa) u³atwiaj¹ca pobieranie
            // danych s¹siada (piksel w odleg³oœci dx, dy) i mno¿enie przez wagê (weight).
            auto addWeightedPixel = [&](int dx, int dy, int weight)
                {
                    int nx = x + dx;           // wspó³rzêdna X s¹siada
                    int ny = y + dy;           // wspó³rzêdna Y s¹siada
                    int nIndex = (ny * width + nx) * 3; // indeks s¹siada w tablicy

                    // Dodanie R, G, B s¹siedniego piksela (po przemno¿eniu przez "weight")
                    accR += pixelData[nIndex + 0] * weight;
                    accG += pixelData[nIndex + 1] * weight;
                    accB += pixelData[nIndex + 2] * weight;
                };

            // Aplikowanie maski 3x3 (wagi dla s¹siadów w kolejnych wierszach)

            // Wiersz y-1: [(-1, -1), (0, -1), (1, -1)] z wagami [-1, -1, 1]
            addWeightedPixel(-1, -1, -1);  // (x-1, y-1) => waga -1
            addWeightedPixel(0, -1, -1);  // (x,   y-1) => waga -1
            addWeightedPixel(1, -1, 1);  // (x+1, y-1) => waga  1

            // Wiersz y:   [(-1, 0), (0, 0), (1, 0)] z wagami [-1, -2, 1]
            addWeightedPixel(-1, 0, -1);  // (x-1, y)   => waga -1
            addWeightedPixel(0, 0, -2);  // (x,   y)   => waga -2
            addWeightedPixel(1, 0, 1);  // (x+1, y)   => waga  1

            // Wiersz y+1: [(-1, 1), (0, 1), (1, 1)] z wagami [1, 1, 1]
            addWeightedPixel(-1, 1, 1);  // (x-1, y+1) => waga  1
            addWeightedPixel(0, 1, 1);  // (x,   y+1) => waga  1
            addWeightedPixel(1, 1, 1);  // (x+1, y+1) => waga  1

            // Po zsumowaniu wagowych wartoœci dla R, G, B - ograniczamy wynik do przedzia³u [0..255]
            // std::clamp (z <algorithm>) zapewnia "przyciêcie" wartoœci do zakresu, co zapobiega przepe³nieniom.
            unsigned char r = static_cast<unsigned char>(std::clamp(accR, 0, 255));
            unsigned char g = static_cast<unsigned char>(std::clamp(accG, 0, 255));
            unsigned char b = static_cast<unsigned char>(std::clamp(accB, 0, 255));

            // Zapisujemy ostateczny wynik do bufora wyjœciowego (outputData)
            outputData[index + 0] = r;  // Kana³ R
            outputData[index + 1] = g;  // Kana³ G
            outputData[index + 2] = b;  // Kana³ B
        }
    }
}

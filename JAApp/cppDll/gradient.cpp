#include "pch.h"          // Plik nag��wkowy "pch.h" (precompiled header) - przyspiesza kompilacj�

#include <algorithm>      // Zawiera std::clamp (do ograniczania warto�ci)

// Funkcja Add (eksportowana z biblioteki DLL w stylu C) - g��wny punkt wej�cia
// do przetwarzania obrazu w kodzie C++ (nak�adanie maski gradientowej 3x3).
extern "C" __declspec(dllexport) void Add(
    unsigned char* pixelData,      // wska�nik na oryginalne dane wej�ciowe (piksele obrazu)
    unsigned char* outputData,     // wska�nik na bufor wyj�ciowy (gdzie zapisujemy wynik)
    int width,                     // szeroko�� obrazu w pikselach
    int startY,                    // indeks pocz�tkowego wiersza do przetworzenia
    int endY,                      // indeks ko�cowego wiersza do przetworzenia
    int imageHeight                // ca�kowita wysoko�� obrazu
)
{
    // Maska 3x3, kt�r� wykorzystujemy do przetwarzania gradientowego:
    //   -1  -1   1
    //   -1  -2   1
    //    1   1   1
    //
    // Dla piksela (x, y) liczymy sum� osobno dla kana��w R, G i B
    // z uwzgl�dnieniem odpowiednich wag dla s�siednich pikseli.
    //
    // Je�li piksel jest na brzegu (x == 0 || x == width - 1 || y == 0 || y == imageHeight - 1),
    // to nie stosujemy maski, tylko kopiujemy oryginaln� warto�� piksela do wyniku.

    // Ka�dy piksel zapisany jest w formacie 3 bajt�w (R, G, B) w kolejnych kom�rkach pami�ci.
    // Indeks piksela w tablicy: index = (y * width + x) * 3.

    // P�tla po wierszach (od startY do endY, z uwzgl�dnieniem granicy imageHeight)
    for (int y = startY; y <= endY && y < imageHeight; ++y)
    {
        // P�tla po kolumnach (x od 0 do width - 1)
        for (int x = 0; x < width; ++x)
        {
            // Sprawdzenie, czy piksel jest na kraw�dzi (brzegu) obrazu
            bool isBorder = (x == 0 || x == width - 1 || y == 0 || y == imageHeight - 1);

            // Obliczenie indeksu w tablicy (odwo�anie do piksela (x,y))
            int index = (y * width + x) * 3;

            // Je�li piksel jest na brzegu, kopiujemy oryginalne warto�ci R, G, B
            // bez zastosowania maski gradientowej
            if (isBorder)
            {
                outputData[index + 0] = pixelData[index + 0]; // R
                outputData[index + 1] = pixelData[index + 1]; // G
                outputData[index + 2] = pixelData[index + 2]; // B
                continue; // Przej�cie do nast�pnego piksela w tym wierszu
            }

            // Je�li nie jeste�my na brzegu, stosujemy filtr 3�3.
            // Tworzymy zmienne akumuluj�ce sum� wag dla R, G i B.
            int accR = 0, accG = 0, accB = 0;

            // Lambda (funkcja anonimowa) u�atwiaj�ca pobieranie
            // danych s�siada (piksel w odleg�o�ci dx, dy) i mno�enie przez wag� (weight).
            auto addWeightedPixel = [&](int dx, int dy, int weight)
                {
                    int nx = x + dx;           // wsp�rz�dna X s�siada
                    int ny = y + dy;           // wsp�rz�dna Y s�siada
                    int nIndex = (ny * width + nx) * 3; // indeks s�siada w tablicy

                    // Dodanie R, G, B s�siedniego piksela (po przemno�eniu przez "weight")
                    accR += pixelData[nIndex + 0] * weight;
                    accG += pixelData[nIndex + 1] * weight;
                    accB += pixelData[nIndex + 2] * weight;
                };

            // Aplikowanie maski 3x3 (wagi dla s�siad�w w kolejnych wierszach)

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

            // Po zsumowaniu wagowych warto�ci dla R, G, B - ograniczamy wynik do przedzia�u [0..255]
            // std::clamp (z <algorithm>) zapewnia "przyci�cie" warto�ci do zakresu, co zapobiega przepe�nieniom.
            unsigned char r = static_cast<unsigned char>(std::clamp(accR, 0, 255));
            unsigned char g = static_cast<unsigned char>(std::clamp(accG, 0, 255));
            unsigned char b = static_cast<unsigned char>(std::clamp(accB, 0, 255));

            // Zapisujemy ostateczny wynik do bufora wyj�ciowego (outputData)
            outputData[index + 0] = r;  // Kana� R
            outputData[index + 1] = g;  // Kana� G
            outputData[index + 2] = b;  // Kana� B
        }
    }
}

#include "pch.h"

extern "C" __declspec(dllexport) void Add(unsigned char* pixelData, int width, int startY, int segmentHeight, int imageHeight) {
    // Iteracja po pikselach w ca³ym segmencie obrazu
    for (int y = startY; y <= startY + segmentHeight && y < imageHeight; ++y) { // Iteracja w pe³nym segmencie, w ramach obrazu
        for (int x = 0; x < width; ++x) {
            int index = (y * width + x) * 3;

            // Piksel centralny (R, G, B)
            unsigned char r = pixelData[index];
            unsigned char g = pixelData[index + 1];
            unsigned char b = pixelData[index + 2];

            // Inicjalizacja s¹siadów centralnego piksela z wartoœci¹ domyœln¹ centralnego piksela
            unsigned char r_south = r, g_south = g, b_south = b;
            unsigned char r_east = r, g_east = g, b_east = b;
            unsigned char r_southeast = r, g_southeast = g, b_southeast = b;

            // Pobieranie wartoœci z s¹siadów tylko jeœli s¹ w obrêbie obrazu
            if (y + 1 < imageHeight) { // Jeœli jest dolny s¹siad
                int southIndex = ((y + 1) * width + x) * 3;
                r_south = pixelData[southIndex];
                g_south = pixelData[southIndex + 1];
                b_south = pixelData[southIndex + 2];
            }
            if (x + 1 < width) { // Jeœli jest prawy s¹siad
                int eastIndex = (y * width + (x + 1)) * 3;
                r_east = pixelData[eastIndex];
                g_east = pixelData[eastIndex + 1];
                b_east = pixelData[eastIndex + 2];
            }
            if (y + 1 < imageHeight && x + 1 < width) { // Jeœli jest dolno-prawy s¹siad
                int southeastIndex = ((y + 1) * width + (x + 1)) * 3;
                r_southeast = pixelData[southeastIndex];
                g_southeast = pixelData[southeastIndex + 1];
                b_southeast = pixelData[southeastIndex + 2];
            }

            // Zastosowanie maski filtra
            int r_new = -r_south - r_southeast + r_east + r;
            int g_new = -g_south - g_southeast + g_east + g;
            int b_new = -b_south - b_southeast + b_east + b;

            // Ograniczenie wartoœci RGB do zakresu 0-255
            r_new = (r_new < 0) ? 0 : (r_new > 255) ? 255 : r_new;
            g_new = (g_new < 0) ? 0 : (g_new > 255) ? 255 : g_new;
            b_new = (b_new < 0) ? 0 : (b_new > 255) ? 255 : b_new;

            // Zapisanie zmodyfikowanego piksela do tablicy pixelData
            pixelData[index] = static_cast<unsigned char>(r_new);
            pixelData[index + 1] = static_cast<unsigned char>(g_new);
            pixelData[index + 2] = static_cast<unsigned char>(b_new);
        }
    }
}
#include <opencv2/opencv.hpp> // Do��czenie nag��wka OpenCV
#include <iostream>

int main() {
    // Program u�ywa funkcji imread, aby wczyta� obraz.
    cv::Mat image = cv::imread("image.jpg");

    // Sprawdzanie, czy obraz zosta� poprawnie wczytany
    if (image.empty()) {
        std::cerr << "Nie uda�o si� wczyta� obrazu!" << std::endl; // Informacja o b��dzie wczytywania
        return -1; // Zako�czenie programu z kodem b��du
    }

    // Program definiuje poprawiony filtr kierunkowy po�udniowo-wschodni
    // U�ywa obiektu cv::Mat i wype�nia go warto�ciami macierzy o rozmiarze 3x3.
    // Warto�ci ujemne w prawym dolnym roku wykrywaj� zmiany w kierunku po�udniowo-wschodnim
    cv::Mat seFilter = (cv::Mat_<float>(3, 3) <<
        1, 1, 1,   
        1, -2, -1, 
        1, -1,-1);

    // Tworzenie obrazu wyj�ciowego po przefiltrowaniu
    cv::Mat outputImage;

    // Przetwarza obraz "image" za pomoc� filtra "seFilter" i zapisuje wynik w "outputImage".
    cv::filter2D(image, outputImage, CV_32F, seFilter);

    // Program normalizuje warto�ci pikseli obrazu wyj�ciowego, aby mie�ci�y si� w standardowym zakresie intensywno�ci (0-255), co jest niezb�dne do poprawnego wy�wietlania obrazu.
    cv::normalize(outputImage, outputImage, 0, 255, cv::NORM_MINMAX);

    // Program konwertuje typ danych obrazu z CV_32F (zmiennoprzecinkowy) na CV_8U (8-bitowy bez znaku), jednocze�nie zwi�kszaj�c kontrast przez zastosowanie wsp�czynnika 2.0 (mno�enie warto�ci pikseli przez 2).
    outputImage.convertTo(outputImage, CV_8U, 2.0);

    // Wy�wietlanie oryginalnego i przefiltrowanego obrazu
    // Program wywo�uje funkcj� imshow, aby wy�wietli� dwa okna: jedno z oryginalnym obrazem, a drugie z przefiltrowanym.
    cv::imshow("Oryginalny obraz", image);
    cv::imshow("Filtr kierunkowy poludniowo-wschodni", outputImage);

    // Oczekiwanie na wci�ni�cie klawisza przez u�ytkownika przed zamkni�ciem okien
    cv::waitKey(0);

    return 0; // Zako�czenie programu
}

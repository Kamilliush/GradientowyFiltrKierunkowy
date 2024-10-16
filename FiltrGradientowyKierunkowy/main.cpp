#include <opencv2/opencv.hpp> // Do³¹czenie nag³ówka OpenCV
#include <iostream>

int main() {
    // Program u¿ywa funkcji imread, aby wczytaæ obraz.
    cv::Mat image = cv::imread("image.jpg");

    // Sprawdzanie, czy obraz zosta³ poprawnie wczytany
    if (image.empty()) {
        std::cerr << "Nie uda³o siê wczytaæ obrazu!" << std::endl; // Informacja o b³êdzie wczytywania
        return -1; // Zakoñczenie programu z kodem b³êdu
    }

    // Program definiuje poprawiony filtr kierunkowy po³udniowo-wschodni
    // U¿ywa obiektu cv::Mat i wype³nia go wartoœciami macierzy o rozmiarze 3x3.
    // Wartoœci ujemne w prawym dolnym roku wykrywaj¹ zmiany w kierunku po³udniowo-wschodnim
    cv::Mat seFilter = (cv::Mat_<float>(3, 3) <<
        1, 1, 1,   
        1, -2, -1, 
        1, -1,-1);

    // Tworzenie obrazu wyjœciowego po przefiltrowaniu
    cv::Mat outputImage;

    // Przetwarza obraz "image" za pomoc¹ filtra "seFilter" i zapisuje wynik w "outputImage".
    cv::filter2D(image, outputImage, CV_32F, seFilter);

    // Program normalizuje wartoœci pikseli obrazu wyjœciowego, aby mieœci³y siê w standardowym zakresie intensywnoœci (0-255), co jest niezbêdne do poprawnego wyœwietlania obrazu.
    cv::normalize(outputImage, outputImage, 0, 255, cv::NORM_MINMAX);

    // Program konwertuje typ danych obrazu z CV_32F (zmiennoprzecinkowy) na CV_8U (8-bitowy bez znaku), jednoczeœnie zwiêkszaj¹c kontrast przez zastosowanie wspó³czynnika 2.0 (mno¿enie wartoœci pikseli przez 2).
    outputImage.convertTo(outputImage, CV_8U, 2.0);

    // Wyœwietlanie oryginalnego i przefiltrowanego obrazu
    // Program wywo³uje funkcjê imshow, aby wyœwietliæ dwa okna: jedno z oryginalnym obrazem, a drugie z przefiltrowanym.
    cv::imshow("Oryginalny obraz", image);
    cv::imshow("Filtr kierunkowy poludniowo-wschodni", outputImage);

    // Oczekiwanie na wciœniêcie klawisza przez u¿ytkownika przed zamkniêciem okien
    cv::waitKey(0);

    return 0; // Zakoñczenie programu
}

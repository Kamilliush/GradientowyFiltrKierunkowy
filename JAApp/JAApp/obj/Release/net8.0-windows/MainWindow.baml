   M S B A M L   `   `   `  ���� 	  JAApp    JAApp.MainWindow   W SPresentationCore, Version=8.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35\ XPresentationFramework, Version=8.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35e aSystem.Windows.Controls.Ribbon, Version=8.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089R NWindowsBase, Version=8.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35F 9http://schemas.microsoft.com/winfx/2006/xaml/presentation     R NSystem.Xaml, Version=8.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089:x,http://schemas.microsoft.com/winfx/2006/xaml     $	��800��$
��1200��  � Title$  
MainWindow��$	��900��$
��1500�����	#FFEFEFEF � 	Resources  �� 
TargetType �� Property �� Value��%  '��       '�� �     '�� ,    '�� �    �� " ��.���  � ��$ 16(���  � ��$ SemiBold"���  � ��$ 5q���  � ��$	 8,4q���  � ��
 �������  � �� �	#FF607D8B��  � �� �	#FF37474F��  � ��$ 1q���  �@�Cursor$
 Hand���� " ��.���  � ��$ 5q���  � ��$	 250���� " ��.���  � ��$ 14(���  � �� �	#FF333333��  � ��$ 5q��� " ��.���  �@��CornerRadius$ 5����  � ��$ 2q���  � �� �	#FFA0A0A0.��� -    J� 	AllowDrop$
 True�� � ColumnDefinitions �� $��3* ��� $	��29* ��� $��3* ��� $	��29* ��� $��3* ��� $	��29* ��� $��3* � � RowDefinitions �� $��2* ��� $	��45* ��� $��2* ��� $	��10* ��� $��2* ��� $	��45* ��� $��2* �.+��� -    ��Name$ ExecutionTimeTextBlock��$
��Wrap=�$��10q�$��16(�$
��Bold"�
��� � �$��5��$��5��$	��Top=�$��Center=�$��Czas: ���� -   $��1��$��1��$��Stretch=�$��Stretch=�
�������$
 True��._��� -   	 ��Name$	 image��$��Uniform=�$��Stretch=�$��Stretch=��� $��3��$��1��$��Stretch=�$��Stretch=�
�������._��� -   $	 
imageAfter��$��Uniform=�$��Stretch=�$��Stretch=��� $��1��$��3�����	#FF222222._��� -   
 ��Name$
 HistogramBefore��$��Stretch=�$��Stretch=�$��10q��� $��3��$��3�����	#FF222222._��� -   $
 HistogramAfter��$��Stretch=�$��Stretch=�$��10q��� $��5��$��1�����	#FFF5F5F5 �� Padding$ 10q�._��  �� $
��Auto ��� $
��Auto ��� $
��Auto ��� $
��Auto ��� $
��Auto �.+��� -   $��0��$��Wybierz zdjęcie���� $��1�� �� Orientation$ Vertical=�$��Center=�$��10q�.+��� $
��Bold"�$��14(�$��Center=�����  �� ElementName$ threadsSlider�� �� Path$ Value� �� StringFormat$ Liczba wątków: {0}���� -	    ��Name$ threadsSlider�� � Minimum$ 1Q� � Maximum$ 64Q� �� TickFrequency$ 1Q� �� TickPlacement$ BottomRight=� �� IsSnapToTickEnabled$
 True�� �� AutoToolTipPlacement$ TopLeft=� �� AutoToolTipPrecision$ 0���� $��2��$ 
Horizontal=�$��Center=�$��10q�.+��� -
   $	��CPP��$	��100��$��40���� -   $	��ASM��$	��100��$��10,0,0,0q�$��40���� -    ��Name$ 
saveButton��$��3��$��Zapisz��${�False��$	��120��$��Center=�$��10q�
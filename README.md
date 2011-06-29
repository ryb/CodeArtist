CodeArtist
==========

CodeArtist is an experiment. It replaces the pixels of an image with coloured text glyphs. Written in D. Tested on Windows and Mac OS X.

Usage
-----

	codeartist [arguments] <filename>
	
### Arguments ###

* `-o` <path> specifies an output image filename or path
* `-f` forces processing
* `-ttf <path>` specifies a TTF file to use as the font
* `-p <number>` text size in points
* `-s <string>` specifies font style in the following format: "bui"
	* e.g., `-s b` for bold; `-s ui` for underlined & italic
* `-t <path>` Specifies the text file name or path to the text file to pull letters from. Only uses letters. No symbols or numbers are used. Letters are converted to caps.
* `-px <number>` Specifies the X Padding, i.e. space between characters horizontally.
	* Range: -10 to 10.
* `-py <number>` Specifies the Y Padding, i.e. space between characters vertically.
	* Range: -10 to 10.
* `-v` gives verbose output
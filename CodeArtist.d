version(Windows) {
    import derelict.sdl.sdl;
    import derelict.sdl.image;
    import derelict.sdl.ttf;
} else version(darwin) {
    import sdl.sdl;
    import sdl.image;
    import sdl.ttf;
}

import std.string;
import std.c.string;
import std.stdio;
import std.file;

const char[] VERSION_NUMBER = "alpha 0.1b";

SDL_Surface* inputimage, outputimage, glyph;
TTF_Font* font;
wchar[] textfile;
int textindex = 0;
int fontadvance, advanceoffset;
int fontheight = 0, heightoffset = -7;
int sx, sy, dx, dy;
bit verbose = 0;
bit force = 0;

const int LARGE_FILESIZE = 20; //about 20KB?

private bit loadImage(char[] filename) {
    int filesize;
    
    //we should probably make sure the image doesn't exceed... say... 20KB. For now.
    if(!std.file.exists(filename) ) {
        throw new FileNotFoundException("Sorry. File " ~filename~ " doesn't exist. Try again.");
    }
    
    filesize = std.file.getSize(filename) / 1024; //bytes -> KiB
    if(filesize > LARGE_FILESIZE) {
        writefln("This file is pretty big at %dK. Processing might take a while.", filesize) ;
    }
    
    writefln("Loading " ~ filename);
    inputimage = IMG_Load(toStringz(filename) );
    
    if(inputimage == null) {
        throw new Error("Couldn't load the image of your choice.");
    }
    if(verbose) writefln("Bits Per Pixel = %d", inputimage.format.BitsPerPixel);
    if( (inputimage.format.BitsPerPixel != 8) && (!force) ) {
        throw new Error("Image must be 8 bits per pixel (256 colours). Sorry. Quitting...");
    }
    return true;
}

private uint getPixel(SDL_Surface* surface, int x, int y) {
    uint pixel = 0;
    uint bpp = surface.format.BytesPerPixel;
    
    ubyte* offset = cast(Uint8 *)surface.pixels + y * surface.pitch + x * bpp;
    
    pixel = cast(uint) *(offset);
    return pixel;
}

private void stdoutImage(SDL_Surface* surface) {
    writefln("for image %d x %d...\n", surface.w, surface.h);
    for (int y = 0; y <= surface.h; y++) {
        for (int x = 0; x <= surface.w; x++) {
            writef("%d", getPixel(surface, x, y) );
        }
        writefln("");
    }
}

private void initTypeface(char[] file, int fontsize, char[] style) {
    int sdlstyle;
    
    font = TTF_OpenFont(file, fontsize);
    if(font == null) {
        writefln("Font not loaded. Quitting is inevitable.");
        quit();
    }
    foreach(char c; style) {
        switch (c) {
            case 'b':
                sdlstyle |= TTF_STYLE_BOLD;
                break;
            case 'i':
                sdlstyle |= TTF_STYLE_ITALIC;
                break;
            case 'u':
                sdlstyle |= TTF_STYLE_UNDERLINE;
                break;
            default:
                sdlstyle = TTF_STYLE_NORMAL;
        }
    }
    TTF_SetFontStyle(font, sdlstyle);
}

private bit outputImageInit() {
    int lfontadvance, lfontheight;
    int minx, maxx;
    
    //calculate font dimensions
    TTF_GlyphMetrics(font, 'h', &minx, &maxx, null, null, &lfontadvance);
    lfontheight = TTF_FontHeight(font);
    
    fontadvance = (maxx - minx) + advanceoffset;
    fontheight = lfontheight + heightoffset;
    if(verbose) writefln("Font height = %d", fontheight);
    if(verbose) writefln("Font advance = %d", fontadvance);
    
    outputimage = SDL_CreateRGBSurface(SDL_SWSURFACE, (fontadvance * inputimage.w), (fontheight * inputimage.h), 24, 0, 0, 0, 0);
    return true;
}

private char[] readText(char[] filename) {
    return cast(char[])std.file.read(filename);
}

private void pixelToChar(int x, int y) {
    SDL_Color colour;
    SDL_Rect destrect;
    char c;

    SDL_GetRGB(getPixel(inputimage, sx, sy), inputimage.format, &colour.r, &colour.g, &colour.b);

    if(verbose) printf("[%d %d %d] ", colour.r, colour.g, colour.b);
    
    do {
        c = textfile[textindex];
        textindex++;
        if(textindex >= textfile.length) {
            textindex = 0;
        }
    } while(c < 65 || c > 90);
    glyph = TTF_RenderGlyph_Solid(font, c, colour);
    if(!glyph) {
        writefln("glyph is null. ", TTF_GetError());
    }
    
    destrect.x = dx;
    destrect.y = dy;

    SDL_BlitSurface(glyph, null, outputimage, &destrect);
    SDL_FreeSurface(glyph);
}

extern(C)
int SDL_main(int argc, char** argv) {
    const int DEFAULT_FONT_SIZE = 12;;
    int done = 0;
    char[] imgpath;
    char[] outputpath;
    char[] textfilepath = "text.txt";
    int fontsize = DEFAULT_FONT_SIZE;
    char[] style;
    char[] fontfile = "font.ttf";
    
    if(argc < 2) {
        writefln("usage - %s [option] <image path>", toString(argv[0]));
        return 1;
    } else {
        for(int i = 0; i < argc; i++) {
            if(toString(argv[i]) == "-o") {
                i++;
                outputpath = toString(argv[i]);
                verboseprint("Output Image Path = " ~ outputpath);
            } 
            else if(toString(argv[i]) == "-f") {
                force = 1;
            }
            else if (toString(argv[i]) == "-ttf") {
                i++;
                fontfile = toString(argv[i]);
                verboseprint("Font file = " ~ fontfile);
            }
            else if(toString(argv[i]) == "-p") {
                //"p" for point size
                i++;
                if(isNumeric(toString(argv[i]) )) {
                    fontsize = atoi(toString(argv[i]));
                    if(fontsize < 1) {
                        fontsize = fontsize * -1;
                    }
                    if(fontsize == 0) {
                        writefln("%d not acceptable. Defaulting to default value.", fontsize);
                        fontsize = DEFAULT_FONT_SIZE;
                    }
                    verboseprint("Font Size = " ~ toString(fontsize));
                } else {
                    writefln("%d not acceptable. Expected a positive numeric value for font size.", fontsize);
                }
                
            }
            else if(toString(argv[i]) == "-s") {
                //Style.
                i++;
                style = toString(argv[i]);
            }
            else if(toString(argv[i]) == "-t") {
                //Text file.
                i++;
                textfilepath = toString(argv[i]);
                verboseprint("Text file path = " ~ textfilepath);
            }
            else if(toString(argv[i]) == "-px") {
                //pad x, i.e. add or subtract something from the fontadvance
                i++;
                if(isNumeric(toString(argv[i]) )) {
                    advanceoffset = atoi(toString(argv[i]));
                    if(advanceoffset < -10) {
                        advanceoffset = -10;
                        writefln("%d not acceptable. Reverting to default value.", advanceoffset);
                    }
                    if(advanceoffset > 10) {
                        advanceoffset = 10;
                        writefln("%d not acceptable. Reverting to default value.", advanceoffset);
                    }
                    verboseprint("Pad x: " ~ toString(advanceoffset));
                } else {
                    writefln("%d not acceptable.", advanceoffset);
                }
            }
            else if(toString(argv[i]) == "-py") {
                //pad y, i.e. add or subtract something from the fontheight
                i++;
                if(isNumeric(toString(argv[i]) )) {
                    heightoffset += atoi(toString(argv[i]));
                    if(heightoffset < -10) {
                        heightoffset += -10;
                        writefln("%d not acceptable. Reverting to default value.", heightoffset);
                    }
                    if(heightoffset > 10) {
                        heightoffset += 10;
                        writefln("%d not acceptable. Reverting to default value.", heightoffset);
                    }
                    verboseprint("Pad y: " ~ toString(heightoffset));
                } else {
                    writefln("%d not acceptable.", heightoffset);
                }
            }
            else if(toString(argv[i]) == "-v") {
                verbose = 1;
            } else {
                //if all else fails, let's assume an input path
                imgpath = std.string.toString(argv[i]);
            }
        }
    }
    
    writefln("CodeArtist %s", VERSION_NUMBER);
    
    version(Windows) {
        DerelictSDL.load();
        DerelictSDLImage.load();
        DerelictSDLttf.load();
    }
    
    if(SDL_Init(SDL_INIT_VIDEO) < 0) {
        throw new Error("Could not init SDL's video subsystem.");
        return 1;
    }
    
    version(Windows) {
        TTF_Init();
    } else {
        if(TTF_Init == -1) {
        throw new Error("Could not init SDL_ttf");
        return 1;
        }
    }

    //load inputimage from file
    try {
        loadImage(imgpath);
    } catch (Exception e) {
        writefln(e.toString);
        quit();
        return 2;
    }
    
    //calc output image dimensions and initialize it
    initTypeface(fontfile, fontsize, style);
    outputImageInit();
    if(outputimage == null) {
        throw new Error("output image is null");
        return 3;
    }
    //load up textfile
    char[] text = readText(textfilepath);
    text = toupper(text);
    textfile = std.utf.toUTF16((text));
    
    //do the pixel to ascii magic
    if(verbose) writefln("inputimage height = %d. width = %d.", inputimage.h, inputimage.w);
    writefln("Processing...");
    for(dy = 0, sy = 0; sy <= inputimage.h; sy++, dy = dy + fontheight) {
        for(dx = 0, sx = 0; sx <= inputimage.w; sx++, dx = dx + fontadvance) {
            pixelToChar(sx, sy);
        }
    }
    
    //save out image
    SDL_SaveBMP(outputimage, (outputpath is null) ? imgpath[0 .. $-4] ~ "_ascii.bmp": outputpath);
    writefln("Done.");
    
    //free up resources and quit
    quit();
    
    return(0);
}

void verboseprint(char[] message) {
    if(verbose) writefln(message);
}

void quit() {
    if(font != null)TTF_CloseFont(font);
    if(inputimage != null)SDL_FreeSurface(inputimage);
    if(outputimage != null)SDL_FreeSurface(outputimage);
    SDL_Quit();
}

int main(char[][] args) {
    version(Windows) {
        return SDL_main(cast(int) args.length, args);
    } else {
        return SDL_InitApplication(args);
    }
}

class FileNotFoundException : Exception {
    this(char[] msg) {
        super(msg);
    }
}
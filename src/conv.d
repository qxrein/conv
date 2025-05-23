module conv;

import std.stdio;
import std.file;
import std.string;
import std.getopt;
import std.conv;
import std.regex;
import std.algorithm;
import std.uri;

class PDFGenerator {
private:
    string content;
    string title;
    string author;
    int fontSize = 12;
    int currentY = 750;
    int lineHeight = 20;
    int pageWidth = 550;
    int margin = 50;
    int pageCount = 1;
    int maxPages = 100;
    int minY = 50;
    
public:
    this(string title = "", string author = "") {
        this.title = title;
        this.author = author;
    }
    
    void setFontSize(int size) {
        fontSize = size;
        lineHeight = size + 8;
    }
    
    void setMargins(int top, int bottom, int left, int right) {
        margin = left;
        currentY = top;
        minY = bottom;
    }
    
    void addHeader1(string text) {
        checkNewPage();
        int oldSize = fontSize;
        setFontSize(18);
        addText(text);
        setFontSize(oldSize);
        currentY -= lineHeight;
    }
    
    void addHeader2(string text) {
        checkNewPage();
        int oldSize = fontSize;
        setFontSize(16);
        addText(text);
        setFontSize(oldSize);
        currentY -= lineHeight;
    }
    
    void addText(string text) {
        checkNewPage();
        content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
        content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "(" ~ escapeText(text) ~ ") Tj\nET\n";
        currentY -= lineHeight;
    }
    
    void addList(string[] items) {
        foreach(item; items) {
            checkNewPage();
            content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
            content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
            content ~= "(• " ~ escapeText(item) ~ ") Tj\nET\n";
            currentY -= lineHeight;
        }
    }
    
    void addLink(string text, string url) {
        checkNewPage();
        content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
        content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "[(" ~ escapeText(text) ~ ") /URI (" ~ escapeText(url) ~ ")] TJ\nET\n";
        currentY -= lineHeight;
    }
    
    void addBlockquote(string text) {
        checkNewPage();
        int oldSize = fontSize;
        setFontSize(fontSize-2);
        content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
        content ~= (margin+10).to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "(" ~ escapeText(text) ~ ") Tj\nET\n";
        setFontSize(oldSize);
        currentY -= lineHeight;
    }
    
    void checkNewPage() {
        if (currentY < minY && pageCount < maxPages) {
            newPage();
        }
    }
    
    void newPage() {
        content ~= "showpage\n";
        currentY = 750;
        pageCount++;
    }
    
    ubyte[] generate() {
        string pdf = "%PDF-1.4\n";
        
        pdf ~= "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n";
        
        pdf ~= "2 0 obj\n<< /Type /Pages /Kids [";
        foreach(i; 3..3+pageCount) {
            pdf ~= i.to!string ~ " 0 R ";
        }
        pdf ~= "] /Count " ~ pageCount.to!string ~ " >>\nendobj\n";
        
        for(int i = 0; i < pageCount; i++) {
            pdf ~= (3+i).to!string ~ " 0 obj\n<< /Type /Page /Parent 2 0 R /Contents " ~ (3+pageCount+i).to!string ~ " 0 R >>\nendobj\n";
        }
        
        string[] contentPages = content.split("showpage\n");
        for(int i = 0; i < contentPages.length; i++) {
            string stream = "<< /Length " ~ contentPages[i].length.to!string ~ " >>\n";
            stream ~= "stream\n" ~ contentPages[i] ~ "endstream\n";
            pdf ~= (3+pageCount+i).to!string ~ " 0 obj\n" ~ stream ~ "endobj\n";
        }
        
        pdf ~= (3+2*pageCount).to!string ~ " 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n";
        
        pdf ~= (4+2*pageCount).to!string ~ " 0 obj\n<<";
        if (!title.empty) pdf ~= " /Title (" ~ escapeText(title) ~ ")";
        if (!author.empty) pdf ~= " /Author (" ~ escapeText(author) ~ ")";
        pdf ~= " >>\nendobj\n";
        
        size_t xrefPos = pdf.length;
        pdf ~= "xref\n0 " ~ (5+2*pageCount).to!string ~ "\n";
        pdf ~= "0000000000 65535 f \n";
        pdf ~= "0000000010 00000 n \n";
        pdf ~= "0000000069 00000 n \n";
        
        size_t pos = 69;
        for(int i = 0; i < 2*pageCount+2; i++) {
            pdf ~= format("%010d", pos) ~ " 00000 n \n";
            pos = pdf.length;
        }
        
        pdf ~= "trailer\n<< /Size " ~ (5+2*pageCount).to!string ~ " /Root 1 0 R /Info " ~ (4+2*pageCount).to!string ~ " 0 R >>\n";
        pdf ~= "startxref\n" ~ xrefPos.to!string ~ "\n%%EOF\n";
        
        return cast(ubyte[])pdf;
    }
    
private:
    string escapeText(string text) {
        return text
            .replace("\\", "\\\\")
            .replace("(", "\\(")
            .replace(")", "\\)");
    }
}

struct MarkdownParser {
    string[] lines;
    size_t currentLine;
    
    this(string input) {
        this.lines = input.splitLines();
        this.currentLine = 0;
    }
    
    bool hasMoreLines() {
        return currentLine < lines.length;
    }
    
    string nextLine() {
        return lines[currentLine++];
    }
    
    string peekLine() {
        return hasMoreLines() ? lines[currentLine] : "";
    }
}

void processMarkdown(MarkdownParser parser, PDFGenerator pdf) {
    while (parser.hasMoreLines()) {
        string line = parser.nextLine().strip();
        
        if (line.length == 0) continue;
        
        if (line.startsWith("> ")) {
            string quote = line[2..$].strip();
            while (parser.hasMoreLines() && parser.peekLine().strip().startsWith("> ")) {
                quote ~= " " ~ parser.nextLine()[2..$].strip();
            }
            pdf.addBlockquote(quote);
        }
        else if (line.startsWith("## ")) {
            pdf.addHeader2(line[3..$].strip());
        }
        else if (line.startsWith("# ")) {
            pdf.addHeader1(line[2..$].strip());
        }
        else if (line.startsWith("- ")) {
            string[] items = [line[2..$].strip()];
            while (parser.hasMoreLines() && parser.peekLine().strip().startsWith("- ")) {
                items ~= parser.nextLine()[2..$].strip();
            }
            pdf.addList(items);
        }
        else {
            auto m = matchFirst(line, regex(`\[([^\]]+)\]\(([^)]+)\)`));
            if (!m.empty) {
                pdf.addLink(m.captures[1], m.captures[2]);
            } else {
                pdf.addText(line);
            }
        }
    }
}

void main(string[] args) {
    string inputFile;
    string outputFile;
    string title = "";
    string author = "";
    int fontSize = 12;
    int topMargin = 750;
    int bottomMargin = 50;
    int leftMargin = 50;
    int rightMargin = 50;
    
    getopt(args,
        "input|i", "Input Markdown file", &inputFile,
        "output|o", "Output PDF file", &outputFile,
        "title|t", "Document title", &title,
        "author|a", "Document author", &author,
        "font-size|f", "Base font size (default: 12)", &fontSize,
        "top-margin|T", "Top margin (default: 750)", &topMargin,
        "bottom-margin|B", "Bottom margin (default: 50)", &bottomMargin,
        "left-margin|L", "Left margin (default: 50)", &leftMargin,
        "right-margin|R", "Right margin (default: 50)", &rightMargin
    );
    
    if (inputFile.empty || outputFile.empty) {
        stderr.writeln("Error: Both input and output files must be specified");
        stderr.writeln("Usage: conv -i input.md -o output.pdf [options]");
        stderr.writeln("Options:");
        stderr.writeln("  -t, --title        Document title");
        stderr.writeln("  -a, --author       Document author");
        stderr.writeln("  -f, --font-size    Base font size (default: 12)");
        stderr.writeln("  -T, --top-margin   Top margin (default: 750)");
        stderr.writeln("  -B, --bottom-margin Bottom margin (default: 50)");
        stderr.writeln("  -L, --left-margin  Left margin (default: 50)");
        stderr.writeln("  -R, --right-margin Right margin (default: 50)");
        return;
    }
    
    try {
        string mdContent = readText(inputFile);
        auto pdf = new PDFGenerator(title, author);
        pdf.setFontSize(fontSize);
        pdf.setMargins(topMargin, bottomMargin, leftMargin, rightMargin);
        
        auto parser = MarkdownParser(mdContent);
        processMarkdown(parser, pdf);
        
        std.file.write(outputFile, pdf.generate());
        writeln("Successfully converted ", inputFile, " to ", outputFile);
        writeln("Pages generated: ", pdf.pageCount);
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
    }
}

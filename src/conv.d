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
    const int lineHeight = 20;
    const int pageWidth = 550;
    const int margin = 50;
    
public:
    this(string title = "", string author = "") {
        this.title = title;
        this.author = author;
    }
    
    void addHeader1(string text) {
        fontSize = 18;
        addText(text);
        currentY -= lineHeight;
        fontSize = 12;
    }
    
    void addHeader2(string text) {
        fontSize = 16;
        addText(text);
        currentY -= lineHeight;
        fontSize = 12;
    }
    
    void addText(string text) {
        content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
        content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "(" ~ escapeText(text) ~ ") Tj\nET\n";
        currentY -= lineHeight;
    }
    
    void addList(string[] items) {
        foreach(item; items) {
            content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
            content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
            content ~= "(• " ~ escapeText(item) ~ ") Tj\nET\n";
            currentY -= lineHeight;
        }
    }
    
    void addLink(string text, string url) {
        content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
        content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "[(" ~ escapeText(text) ~ ") /URI (" ~ escapeText(url) ~ ")] TJ\nET\n";
        currentY -= lineHeight;
    }
    
    void addBlockquote(string text) {
        content ~= "BT\n/F1 " ~ (fontSize-2).to!string ~ " Tf\n";
        content ~= (margin+10).to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "(" ~ escapeText(text) ~ ") Tj\nET\n";
        currentY -= lineHeight;
    }
    
    void newPage() {
        currentY = 750;
        content ~= "showpage\n";
    }
    
    ubyte[] generate() {
        string pdf = "%PDF-1.4\n";
        
        pdf ~= "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n";
        
        pdf ~= "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n";
        
        pdf ~= "3 0 obj\n<< /Type /Page /Parent 2 0 R /Contents 4 0 R >>\nendobj\n";
        
        string stream = "<< /Length " ~ content.length.to!string ~ " >>\n";
        stream ~= "stream\n" ~ content ~ "endstream\n";
        pdf ~= "4 0 obj\n" ~ stream ~ "endobj\n";
        
        pdf ~= "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n";
        
        pdf ~= "6 0 obj\n<<";
        if (!title.empty) pdf ~= " /Title (" ~ escapeText(title) ~ ")";
        if (!author.empty) pdf ~= " /Author (" ~ escapeText(author) ~ ")";
        pdf ~= " >>\nendobj\n";
        
        size_t xrefPos = pdf.length;
        pdf ~= "xref\n0 7\n";
        pdf ~= "0000000000 65535 f \n";
        pdf ~= "0000000010 00000 n \n";
        pdf ~= "0000000069 00000 n \n";
        pdf ~= "0000000128 00000 n \n";
        pdf ~= "0000000209 00000 n \n";
        pdf ~= "0000000392 00000 n \n";
        pdf ~= "0000000483 00000 n \n";
        
        pdf ~= "trailer\n<< /Size 7 /Root 1 0 R /Info 6 0 R >>\n";
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
    
    getopt(args,
        "input|i", "Input Markdown file", &inputFile,
        "output|o", "Output PDF file", &outputFile,
        "title|t", "Document title", &title,
        "author|a", "Document author", &author
    );
    
    if (inputFile.empty || outputFile.empty) {
        stderr.writeln("Error: Both input and output files must be specified");
        stderr.writeln("Usage: conv -i input.md -o output.pdf [options]");
        stderr.writeln("Options:");
        stderr.writeln("  -t, --title     Document title");
        stderr.writeln("  -a, --author    Document author");
        return;
    }
    
    try {
        string mdContent = readText(inputFile);
        auto pdf = new PDFGenerator(title, author);
        auto parser = MarkdownParser(mdContent);
        
        processMarkdown(parser, pdf);
        
        std.file.write(outputFile, pdf.generate());
        writeln("Successfully converted ", inputFile, " to ", outputFile);
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
    }
}

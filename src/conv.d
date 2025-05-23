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
    int fontSize = 11;
    int currentY = 750;
    int lineHeight = 15;
    int pageWidth = 500;
    int margin = 50;
    int pageCount = 1;
        
public:
    this(string title = "", string author = "") {
        this.title = title;
        this.author = author;
    }
    
    void addHeader(string text) {
        checkNewPage();
        content ~= "BT\n/F1 14 Tf\n";
        content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "(" ~ escapeText(text) ~ ") Tj\nET\n";
        currentY -= lineHeight + 5;
    }
    
    void addSubheader(string text) {
        checkNewPage();
        content ~= "BT\n/F1 12 Tf\n";
        content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "(" ~ escapeText(text) ~ ") Tj\nET\n";
        currentY -= lineHeight;
    }
    
    void addText(string text) {
        checkNewPage();
        content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
        content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "(" ~ escapeText(text) ~ ") Tj\nET\n";
        currentY -= lineHeight;
    }
    
    void addListItem(string text) {
        checkNewPage();
        content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
        content ~= (margin+10).to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "(• " ~ escapeText(text) ~ ") Tj\nET\n";
        currentY -= lineHeight;
    }
    
    void addLink(string text, string url) {
        checkNewPage();
        content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
        content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "(" ~ escapeText(text) ~ ") Tj\n";
        content ~= "ET\nBT\n/F1 " ~ (fontSize-1).to!string ~ " Tf\n";
        content ~= margin.to!string ~ " " ~ (currentY-5).to!string ~ " Td\n";
        content ~= "[(" ~ escapeText(url) ~ ") /URI (" ~ escapeText(url) ~ ")] TJ\nET\n";
        currentY -= lineHeight + 5;
    }
    
    void addBlockquote(string text) {
        checkNewPage();
        content ~= "q\n";
        content ~= (margin-5).to!string ~ " " ~ (currentY+2).to!string ~ " " ~ 
                  (pageWidth+10).to!string ~ " " ~ (lineHeight-4).to!string ~ " re\n";
        content ~= "0.95 0.95 0.95 rg\n";
        content ~= "f\n";
        content ~= "0.7 0.7 0.7 RG\n"; 
        content ~= "0.5 w\n"; 
        content ~= (margin-5).to!string ~ " " ~ (currentY+2).to!string ~ " " ~ 
                  (pageWidth+10).to!string ~ " " ~ (lineHeight-4).to!string ~ " re\n";
        content ~= "S\n";
        
        // Add text
        content ~= "BT\n/F1 " ~ fontSize.to!string ~ " Tf\n";
        content ~= margin.to!string ~ " " ~ currentY.to!string ~ " Td\n";
        content ~= "(" ~ escapeText(text) ~ ") Tj\nET\n";
        content ~= "Q\n";
        
        currentY -= lineHeight;
    }
    
    void checkNewPage() {
        if (currentY < 50 && pageCount < 10) {
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
            pdf ~= (3+i).to!string ~ " 0 obj\n<< /Type /Page /Parent 2 0 R /Contents " ~ 
                  (3+pageCount+i).to!string ~ " 0 R >>\nendobj\n";
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
        
        pdf ~= "trailer\n<< /Size " ~ (5+2*pageCount).to!string ~ " /Root 1 0 R /Info " ~ 
              (4+2*pageCount).to!string ~ " 0 R >>\n";
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

void processWorkReport(string[] lines, PDFGenerator pdf) {
    foreach(line; lines) {
        line = line.strip();
        if (line.length == 0) continue;
        
        if (line.startsWith("> ")) {
            pdf.addBlockquote(line[2..$].strip());
        }
        else if (line.startsWith("## ")) {
            pdf.addHeader(line[3..$].strip());
        }
        else if (line.startsWith("# ")) {
            pdf.addHeader(line[2..$].strip());
        }
        else if (line.endsWith(" :")) {
            pdf.addSubheader(line);
        }
        else if (line.startsWith("- ")) {
            pdf.addListItem(line[2..$].strip());
        }
        else if (matchFirst(line, regex(`\[([^\]]+)\]\(([^)]+)\)`))) {
            auto m = matchFirst(line, regex(`\[([^\]]+)\]\(([^)]+)\)`));
            pdf.addLink(m.captures[1], m.captures[2]);
        }
        else {
            pdf.addText(line);
        }
    }
}

void main(string[] args) {
    string inputFile;
    string outputFile;
    
    getopt(args,
        "input|i", "Input Markdown file", &inputFile,
        "output|o", "Output PDF file", &outputFile
    );
    
    if (inputFile.empty || outputFile.empty) {
        stderr.writeln("Usage: conv -i input.md -o output.pdf");
        return;
    }
    
    try {
        string[] lines = readText(inputFile).splitLines();
        auto pdf = new PDFGenerator("Work Report", "Manav (2023UEA6505)");
        
        processWorkReport(lines, pdf);
        
        std.file.write(outputFile, pdf.generate());
        writeln("Successfully converted ", inputFile, " to ", outputFile);
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
    }
}

# (conv)

A command-line tool that converts Markdown files to properly formatted PDF documents.

## Installation
1. Ensure you have Nix installed
2. Clone the repository
3. Run `nix build` in the project directory

## Usage
```
conv -i <input.md> -o <output.pdf> [options]
```

## Options
| Option          | Description                          | Default Value |
|-----------------|--------------------------------------|---------------|
| -i, --input     | Input Markdown file (required)       | -             |
| -o, --output    | Output PDF file (required)           | -             |
| -t, --title     | Document title                       | ""            |
| -a, --author    | Document author                      | ""            |
| -f, --font-size | Base font size                       | 12            |
| -m, --margin    | Page margin (all sides)              | 50            |

## Examples

1. Basic conversion:
```
  conv -i document.md -o document.pdf
```


2. With title and author:
```
  conv -i report.md -o report.pdf -t "x" -a "deez nuts"
```

3. and
```
  conv -i notes.md -o notes.pdf -f 14 -m 40
```

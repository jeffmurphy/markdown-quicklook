## Purpose

Defines the observable behavior of converting raw Markdown source text into styled, themed HTML for display in the Quick Look preview, including GitHub-Flavored-Markdown extensions, embedded diagrams/math, and local asset resolution.

## ADDED Requirements

### Requirement: CommonMark baseline rendering
The system SHALL render standard CommonMark constructs (headings, paragraphs, emphasis/strong, ordered and unordered lists, blockquotes, inline code, horizontal rules, and hyperlinks) as their corresponding styled HTML elements.

#### Scenario: Common elements render correctly
- **WHEN** a Markdown document contains headings, lists, emphasis, blockquotes, and a hyperlink
- **THEN** the rendered preview SHALL display each as the corresponding styled HTML element (e.g. `<h1>`-`<h6>`, `<ul>`/`<ol>`, `<em>`/`<strong>`, `<blockquote>`, a clickable link)

### Requirement: GFM tables
The system SHALL render GitHub-Flavored-Markdown pipe tables as HTML tables with a distinguishable header row.

#### Scenario: Pipe table renders as a table
- **WHEN** the document contains a GFM pipe-delimited table with a header row and one or more data rows
- **THEN** the preview SHALL render it as an HTML table with the header row visually distinct from data rows

### Requirement: Task lists
The system SHALL render GFM task list items as checkboxes reflecting their checked/unchecked state.

#### Scenario: Checked and unchecked items render as checkboxes
- **WHEN** the document contains `- [ ] item A` and `- [x] item B`
- **THEN** the preview SHALL render item A as an unchecked checkbox and item B as a checked checkbox, both read-only

### Requirement: Fenced code block syntax highlighting
The system SHALL apply syntax highlighting to fenced code blocks based on the declared language, and SHALL render code blocks with no or unrecognized language as plain monospaced text without error.

#### Scenario: Recognized language is highlighted
- **WHEN** the document contains a fenced code block with a recognized language identifier (e.g. `python`, `javascript`, `swift`)
- **THEN** the preview SHALL render the block in monospace font with syntax-appropriate color highlighting

#### Scenario: Unknown or missing language degrades gracefully
- **WHEN** a fenced code block has no language identifier or an unrecognized one
- **THEN** the preview SHALL render the block as plain monospaced text with no highlighting and no error or crash

### Requirement: Footnotes
The system SHALL render footnote references and their definitions as linked, navigable footnotes.

#### Scenario: Footnote reference and definition render as linked footnote
- **WHEN** the document contains a footnote reference (e.g. `text[^1]`) and a matching definition (e.g. `[^1]: note text`)
- **THEN** the preview SHALL render a clickable marker at the reference point and a corresponding footnote entry, linked to each other

### Requirement: YAML front matter handling
The system SHALL detect a leading YAML front matter block (delimited by `---` lines at the very start of the file) and render it as a distinct metadata table rather than as part of the document body or as raw text.

#### Scenario: Front matter present
- **WHEN** the file begins with a `---`-delimited YAML block followed by the document body
- **THEN** the preview SHALL render the front matter's key/value pairs as a metadata table separate from the rendered body, and SHALL NOT display the raw `---` delimiters or YAML syntax as body text

#### Scenario: No front matter present
- **WHEN** the file does not begin with a `---`-delimited YAML block
- **THEN** the preview SHALL render the body normally with no metadata table shown

### Requirement: Relative image and link resolution
The system SHALL resolve relative image and link paths against the directory containing the previewed Markdown file.

#### Scenario: Relative image resolves and displays
- **WHEN** the document references an image with a path relative to the Markdown file's own location (e.g. `![alt](./images/pic.png)`) and that file exists on disk
- **THEN** the preview SHALL display the referenced image inline

#### Scenario: Missing relative image degrades gracefully
- **WHEN** a referenced relative image path does not exist on disk
- **THEN** the preview SHALL show a broken-image placeholder for that image without crashing or blocking the rest of the preview from rendering

### Requirement: Mermaid diagram rendering
The system SHALL render fenced code blocks labeled `mermaid` as rendered diagrams.

#### Scenario: Valid Mermaid block renders as a diagram
- **WHEN** the document contains a fenced code block with language `mermaid` and valid Mermaid diagram syntax
- **THEN** the preview SHALL render it as a graphical diagram rather than as plain text

#### Scenario: Invalid Mermaid syntax degrades gracefully
- **WHEN** a `mermaid` code block contains invalid diagram syntax
- **THEN** the preview SHALL display an in-place error/fallback indication for that block without crashing or preventing the rest of the document from rendering

### Requirement: Math rendering
The system SHALL render inline (`$...$`) and block (`$$...$$`) math expressions as typeset mathematical notation.

#### Scenario: Valid math expression renders as typeset notation
- **WHEN** the document contains a valid inline or block math expression
- **THEN** the preview SHALL render it as typeset mathematical notation rather than raw LaTeX source

#### Scenario: Invalid math syntax degrades gracefully
- **WHEN** a math expression contains invalid syntax
- **THEN** the preview SHALL fall back to displaying the raw source text for that expression without crashing or preventing the rest of the document from rendering

### Requirement: Consistent visual theme
The system SHALL apply a consistent, GitHub-Flavored-Markdown-like visual theme to all rendered elements (typography, spacing, code block backgrounds, table borders, blockquote styling), matching the current light/dark appearance mode.

#### Scenario: Rendered document has consistent styling
- **WHEN** a document containing headings, code blocks, tables, and blockquotes is rendered
- **THEN** each element type SHALL use a consistent, visually distinct style consistent with the rest of the document and with the active light/dark theme

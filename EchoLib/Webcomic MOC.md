---
aliases:
  - Webcomic
---
```meta-bind-button
label: New Book
hidden: false
class: ""
tooltip: ""
id: ""
style: default
actions:
  - type: templaterCreateNote
    templateFile: Extras/Templates/Template, Books.md
    folderPath: Sources/Books
    fileName: Book Name
    openNote: true

```

# Template
- [[Template, Books]]

# Books
```dataview
TABLE Date, Title, Author
FROM "Sources/Books"
SORT file.name DESC
```

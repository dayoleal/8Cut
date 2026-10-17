# Architecture

Folders and main types of the app.

## Overview

```
MyApp.swift      Entry point
Models/          Zine, ZinePage, ZineLayer, DrawingTool, ZineSummary,
                 ZineDocument, EditHistory
ViewModels/      AppViewModel, GalleryViewModel, ReaderViewModel,
                 EditorViewModel, ToolPaletteViewModel
Views/           RootView, GalleryView, ZineReaderView, EditorView
  Components/    BookSpreadView, BookCoverView, ToolSheet, PageDrawerView,
                 PageCanvasView, DeskBackground, ...
Helpers/         ZineRepository, ZinePackage, PageRenderer, ViewExtension,
                 PreviewData
```

### MVVM

Each screen has a view and an `@Observable` view model. Views show the state
and call view model methods. View models hold the state, load data and handle
navigation.

### Navigation

``AppViewModel`` keeps the current screen. The screen view models call
``GalleryRouting``, ``ReaderRouting`` and ``EditorRouting`` to change screens.

### Storage

``FileZineRepository`` saves each zine as a folder in `Documents/Zines`:

```
<id>.zine/
├── manifest.json
├── thumbnail.jpg
├── drawings/<layer>.drawing
└── assets/<name>
```

Changes are saved 1.5 s after the last edit, when leaving the editor and when
the app goes to the background.

### Undo and redo

``EditHistory`` keeps one stack per open zine. Drawing edits store the drawing
before and after; other edits store a copy of the page.

### Rendering

In the editor only the active layer is a `PKCanvasView`. The layers below and
above it are rendered to images by ``PageRenderer``, which is also used for
thumbnails, the reader and sharing.

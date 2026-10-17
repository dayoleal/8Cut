# Architecture

How 8-Cut is organized.

## Overview

```
MyApp.swift      Entry point; creates the repository and AppViewModel
Models/          Zine, ZinePage, ZineLayer, DrawingTool, ZineSummary,
                 ZineDocument (open zine in memory), EditHistory (undo/redo)
ViewModels/      AppViewModel, GalleryViewModel, ReaderViewModel,
                 EditorViewModel, ToolPaletteViewModel
Views/           RootView, GalleryView, ZineReaderView, EditorView
  Components/    Reusable pieces: BookSpreadView, BookCoverView, ToolSheet,
                 PageDrawerView, PageCanvasView, DeskBackground…
Helpers/         ZineRepository, ZinePackage, PageRenderer, PreviewData
```

### MVVM

Each screen has a view and an `@Observable`, `@MainActor` view model.

- **Views** render state and forward actions (`viewModel.undo()`,
  `viewModel.createZine()`). The only state they keep is animation or focus,
  such as the page-flip progress in ``BookSpreadView``.
- **View models** hold the screen state, perform the actions, fetch data from
  the ``ZineRepository`` and the ``ZineDocument``, and request navigation.
- **Models** are value types plus ``ZineDocument``, the open zine shared by the
  reader and the editor.

### Navigation

``AppViewModel`` owns the current screen and creates the screen view models.
They ask for navigation through small protocols (``GalleryRouting``,
``ReaderRouting``, ``EditorRouting``) held as `weak` references, so screens do
not know about each other.

### Storage

``ZineRepository`` hides the file system; ``FileZineRepository`` stores one
``ZinePackage`` per zine. Previews use the same implementation pointed at a
temporary folder.

```
<id>.zine/
├── manifest.json             Zine
├── thumbnail.jpg             cover for the gallery
├── drawings/<layer>.drawing  PKDrawing data
└── assets/<name>             imported images
```

Writes are atomic and debounced (1.5 s); pending changes are flushed when
leaving the editor or when the app goes to the background.

### Undo and redo

``EditHistory`` records every edit as an entry that can undo and redo itself.
Drawing edits keep the strokes before and after; structural edits keep a
snapshot of the whole ``ZinePage``. Entries remember their page so undo brings
the user back to it.

### Rendering

The editor uses a "sandwich": only the active layer is a live `PKCanvasView`;
layers below and above it are flattened by ``PageRenderer``. Thumbnails, the
reader and sharing come from the same renderer, so what is on screen always
matches what is exported.

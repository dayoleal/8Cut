# ``AppModule``

Create 8-page zines on iPad: draw, add images, read and print.

## Overview

8-Cut is a SwiftUI app that uses MVVM. The drawing canvas uses PencilKit in a
UIKit view.

See <doc:Architecture>.

## Topics

### Essentials

- <doc:Architecture>
- ``AppViewModel``
- ``RootView``

### Models

- ``Zine``
- ``ZinePage``
- ``ZineLayer``
- ``ZineFormat``
- ``ZineSummary``
- ``DrawingTool``
- ``ZineDocument``
- ``EditHistory``

### View models

- ``GalleryViewModel``
- ``ReaderViewModel``
- ``EditorViewModel``
- ``ToolPaletteViewModel``

### Views

- ``GalleryView``
- ``ZineReaderView``
- ``EditorView``

### Components

- ``BookSpreadView``
- ``BookCoverView``
- ``PageCanvasView``
- ``PageCanvasHostView``
- ``PageDrawerView``
- ``LayersPanelView``
- ``TextEditorSheet``
- ``ToolSheet``
- ``DeskBackground``
- ``ChromeIconButton``

### Helpers

- ``ZineRepository``
- ``FileZineRepository``
- ``ZinePackage``
- ``PageRenderer``
- ``ImageProcessing``

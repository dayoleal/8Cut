# ``AppModule``

Make 8-page, one-sheet zines on iPad: draw, collage, leaf through and print.

## Overview

8-Cut is a SwiftUI app built with MVVM. Views only render state and forward
user actions; view models hold the state, the actions and the data access;
models describe the zine and how it is stored. The drawing surface is UIKit +
PencilKit for stroke latency, bridged into SwiftUI.

Read <doc:Architecture> for how the pieces fit together.

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
- ``ToolSheet``
- ``DeskBackground``
- ``ChromeIconButton``

### Helpers

- ``ZineRepository``
- ``FileZineRepository``
- ``ZinePackage``
- ``PageRenderer``

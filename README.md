# 8-Cut 🎨

### Unleash your daily creativity in classic 8-page zines. ✂️

**8-Cut** is a digital creative platform designed to encourage fanzine production. 
The application allows users to explore their daily creativity through collage tools, 
image editing, and illustrations, to produce and export a classic eight-page magazine format.

<br/>

[![Platform](https://img.shields.io/badge/iPadOS-17.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/ipados/)
[![Swift](https://img.shields.io/badge/Swift-5-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![PencilKit](https://img.shields.io/badge/PencilKit-0052CC?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/documentation/pencilkit)
[![License](https://img.shields.io/badge/License-MIT-3DA639?style=for-the-badge)](LICENSE)

</div>

---

## 📑 Table of Contents

- [About](#-about)
- [Screenshots](#-screenshots)
- [Features](#-features)
- [How It Works](#-how-it-works)
- [Roadmap](#-roadmap)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Authors](#-authors)
- [License](#-license)

---

## 📖 About

This project emerged from research into the materialization of creative ideation. After an intense phase of aesthetic investigation and reference mapping, **8-Cut** was conceived as a tool that bridges the gap between physical and digital media. 

It connects the raw, visceral visual allure of analog collages with the endless possibilities of digital assets, giving creators a dedicated space to build and distribute fanzines right from their iPads.

---

## 📸 Screenshots

<div align="center">

<img src="https://github.com/user-attachments/assets/39073bbe-565c-4666-aef8-467db0789dd9" width="80%" alt="Edit Screen" style="border-radius: 12px;"/>

*The 8-Cut editing canvas, featuring drawing tools and image manipulation.*

</div>

---

## 🚀 Features

- **✂️ Collage Editor** — A flexible, canvas-based interface for free manipulation, scaling, and rotation of visual elements.
- **✍️ Illustration Tools** — Integrated support for manual drawing, sketching, and handwriting via Apple Pencil.
- **🖨️ Retro Image Editing** — Apply custom filters and technical adjustments to achieve that authentic, gritty *xerox-like* aesthetic.
- **📄 Print-Ready Export** — Automatically generates files specifically configured for the classic 8-page zine layout (standard fold), ready to print, fold, and share.

---

## ⚙️ How It Works

1. **Start a Zine** — Open a new blank canvas mapped to the 8-page folding structure.
2. **Import & Collage** — Bring in digital assets, photos, or textures and manipulate them freely on the page.
3. **Draw & Annotate** — Use the Apple Pencil to add handwritten text, doodles, and illustrations natively over your images.
4. **Apply Analog Filters** — Give your pages a DIY feel with high-contrast, xerox-style Core Image filters.
5. **Export & Fold** — Export a single PDF or image sheet. Print it out, make one cut in the center, fold it up, and you have a physical zine.

---

## 🗺️ Roadmap

Features we plan to bring to **8-Cut** next:

- **Text Tool** — Native typography support for typewriter-style fonts.
- **Zine Templates** — Pre-defined layouts to help overcome the blank page syndrome.
- **Community Gallery** — A space to share exported digital zines with other creators.

---

## 🛠️ Tech Stack

| Area | Tech |
|------|------|
| Drawing & Brushes | PencilKit |
| Canvas Manipulation | PaperKit |
| Image Processing | Core Image |
| Language | Swift |

---

## 📂 Project Structure

```text
8-Cut/
├── 8CutApp.swift                 # App entry point
├── Models/                       # Zine, Page, CollageElement models
├── ViewModels/                   # CanvasViewModel, ExportViewModel...
├── Views/                        # SwiftUI screens (Editor, Gallery, Settings)
├── Components/                   # Reusable UI components and toolbars
├── Filters/                      # Core Image custom xerox filters
├── Managers/                     # File export and layout managers
├── Extensions/                   # Swift / SwiftUI helpers
└── Assets.xcassets/              # Colors, icons, textures

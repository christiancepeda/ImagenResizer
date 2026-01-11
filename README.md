# Image Resizer & WebP Converter for macOS

![Platform: macOS](https://img.shields.io/badge/Platform-macOS-000000.svg?style=flat&logo=apple)
![Language: Swift](https://img.shields.io/badge/Language-Swift-F05138.svg?style=flat&logo=swift)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)

## 📖 About the Program

**Image Resizer & WebP Converter** is a native macOS production tool designed to streamline the workflow of developers and designers who need consistent, web-optimized assets.

The application solves a common problem: taking a batch of mixed-format images (PNG, JPEG, HEIC, etc.) and converting them into a standardized, high-performance format (**WebP**) with exact uniform dimensions (**800x800**).

Whether you are preparing product catalogs, user avatars, or gallery thumbnails, this tool ensures your images are exactly the right size and format without the tedium of manual editing software.

## 🌟 Key Features

### 1. Smart Resizing Modes
The app offers two distinct resizing strategies to handle different aspect ratios:
*   **Fill (Crop)**: Intelligently scales the image to strictly fill the 800x800 canvas. Center-crops any excess. Perfect for consistent thumbnails where filling the frame is more important than showing every edge.
*   **Fit (Pad)**: Scales the image to fit entirely within the 800x800 canvas. Adds a transparent background (padding) to fill the remaining space. Ideal for product images where the entire object must be visible.

### 2. Batch Processing
*   **Drag & Drop Simplicity**: Select multiple individual files or point to an entire folder.
*   **Recursive Loading**: Automatically identifies valid image files in the selected source.

### 3. Professional WebP Conversion
*   **High Efficiency**: Uses `libwebp` (via SDWebImageWebPCoder) to create images that are significantly smaller than PNGs/JPGs with comparable quality.
*   **Customizable Quality**: Adjust the lossy compression quality (0-100) or switch to Lossless mode for pixel-perfect archiving.

### 4. Production-Ready Reliability
*   **Exact Pixel Precision**: Uses low-level `NSBitmapImageRep` rendering to guarantee 800x800 pixel output, avoiding common "Retina 2x" scaling issues.
*   **Non-Destructive**: Never overwrites your originals. Saves new files to a dedicated output folder.
*   **Collision Handling**: Automatically renames files (e.g., `image-1.webp`) if a file with the same name already exists.
*   **Sandbox Compliant**: Fully compatible with macOS App Sandbox security requirements using scoped resource access.

## 🛠 Installation & Setup

### Prerequisites
*   **Xcode 14+**
*   **macOS 12.0+**

### Building from Source
This project relies on the `SDWebImageWebPCoder` Swift Package.

1.  Clone this repository.
2.  Open `ImagenResizer.xcodeproj`.
3.  Xcode should automatically resolve the package dependency.
    *   *If not managed automatically*: Go to **File > Add Packages...** and add `https://github.com/SDWebImage/SDWebImageWebPCoder.git`.
4.  **Important**: Ensure **App Sandbox** permissions are set correctly.
    *   Target > Signing & Capabilities > App Sandbox > File Access > User Selected File: **Read/Write**.
5.  Press `Cmd+R` to build and run.

## 🧑‍� Usage

1.  **Input**: Click **Choose Images** to select files, or **Choose Folder** to scan a directory.
2.  **Output**: Select a destination folder for the converted files.
3.  **Settings**:
    *   Select **Fill** or **Fit**.
    *   Set your desired **WebP Quality**.
4.  **Run**: Click **Convert**. The app processes images asynchronously to keep the UI responsive.
5.  **Review**: Open the output folder directly from the app to verify your new assets.

---

**Note**: This is a portfolio-quality application giving full access to modern macOS SwiftUI APIs combined with robust file system handling.
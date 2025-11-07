# Windows UVC Control Panel

A Windows application for accessing USB Video Class (UVC) camera property pages and settings dialogs. This tool provides direct access to the same camera configuration interfaces used by applications like NVIDIA Broadcast and e-CAM.

## Features

- **DirectShow Integration**: Opens camera property pages using DirectShow's `ISpecifyPropertyPages` interface
- **Camera Enumeration**: Lists all available video input devices on your system
- **Multiple Access Methods**:
  - **UVC (DirectShow)**: Primary method for accessing camera property pages (works with most USB UVC cameras like Logitech C920)
  - **Legacy VfW Dialogs**: Attempts to open Video for Windows dialogs (if supported by the camera)
  - **Media Foundation Info**: Provides information about Media Foundation integration
  - **Device Manager**: Quick access to Windows Device Manager
- **Real-time Logging**: Built-in logging to both the UI and log file
- **Cross-Platform Windows Support**: Works on Windows 10 and Windows 11, both 32-bit and 64-bit

## Requirements

- **Operating System**: Windows 10 (version 19041 or later) or Windows 11
- **Architecture**: x64 (64-bit) or x86 (32-bit)
- **Runtime**: 
  - For self-contained executables: No additional requirements
  - For framework-dependent executables: .NET 8.0 Runtime must be installed

## Download

Pre-built executables are available in the [Releases](https://github.com/yourusername/windows-uvc-control-panel/releases) section.

Choose the appropriate version:
- **Self-contained**: Larger file size (~50-70 MB) but no .NET runtime required
- **Framework-dependent**: Smaller file size (~200 KB) but requires .NET 8.0 runtime

## Usage

1. **Launch the application**: Run `UvcPaneler.exe`
2. **Select a camera**: Choose your camera from the list on the left
3. **Open property pages**: Click "Open UVC (DirectShow)…" to access the camera's settings dialog
4. **View logs**: Check the log area on the right for detailed information about operations

### Button Functions

- **Refresh**: Reloads the list of available cameras
- **Open UVC (DirectShow)…**: Opens the camera's property pages (primary feature)
- **Open Legacy VfW…**: Attempts to open Video for Windows dialogs (may not work on all cameras)
- **Try MF (exploratory)…**: Shows information about Media Foundation integration
- **Device Manager…**: Opens Windows Device Manager

## Building from Source

### Prerequisites

- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) or later
- Windows 10/11 development environment
- Visual Studio 2022 (recommended) or Visual Studio Code with C# extension

### Build Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/windows-uvc-control-panel.git
   cd windows-uvc-control-panel
   ```

2. **Restore dependencies**:
   ```bash
   dotnet restore
   ```

3. **Build the project**:
   ```bash
   dotnet build -c Release
   ```

4. **Run the application**:
   ```bash
   dotnet run -c Release
   ```

### Creating Distributable Executables

#### Self-Contained Executables (Recommended)

Build for 64-bit Windows:
```bash
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
```

Build for 32-bit Windows:
```bash
dotnet publish -c Release -r win-x86 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
```

Output will be in `bin/Release/net8.0-windows10.0.19041/win-x64/publish/` or `bin/Release/net8.0-windows10.0.19041/win-x86/publish/`

#### Framework-Dependent Executables

Build for 64-bit Windows:
```bash
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true
```

Build for 32-bit Windows:
```bash
dotnet publish -c Release -r win-x86 --self-contained false -p:PublishSingleFile=true
```

### Using the Build Script

A PowerShell build script (`build.ps1`) is provided for convenience:

```powershell
.\build.ps1
```

This will create both x64 and x86 self-contained executables in the `publish/` directory.

## How It Works

The application uses DirectShow's COM interfaces to enumerate and interact with camera devices:

1. **Device Enumeration**: Uses `DsDevice.GetDevicesOfCat(FilterCategory.VideoInputDevice)` to find all video input devices
2. **Property Page Access**: Queries the camera filter for `ISpecifyPropertyPages` interface
3. **Dialog Display**: Uses Windows' `OleCreatePropertyFrame` to display the vendor-provided property pages

Most USB UVC cameras (like the Logitech C920) expose their configuration UI through COM property pages, which is the standard method used by professional applications.

## Logging

The application logs all operations to:
- **UI Log**: Displayed in the log text box within the application
- **File Log**: `%LOCALAPPDATA%\UvcPaneler\log.txt`

Log files are automatically rotated when they exceed 512 KB.

## Troubleshooting

### No Cameras Detected

- Ensure your camera is connected and recognized by Windows
- Check Device Manager to verify the camera appears under "Cameras" or "Imaging devices"
- Try clicking the "Refresh" button

### Property Pages Don't Open

- Some cameras may not expose property pages through DirectShow
- Check the log for COM error codes (HRESULT values)
- Try the "Legacy VfW" option if available
- Ensure you have the latest camera drivers installed

### Build Warnings

- **NU1701**: DirectShowLib package compatibility warning - this is expected and safe to ignore
- The package was designed for .NET Framework but works with .NET 8.0

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Uses [DirectShowLib](https://www.nuget.org/packages/DirectShowLib/) for DirectShow interop
- Built with .NET 8.0 and Windows Forms

## GitHub Setup

To publish this project to GitHub:

1. **Create a new repository** on GitHub named `windows-uvc-control-panel`
2. **Initialize git** (if not already done):
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   ```
3. **Add remote and push**:
   ```bash
   git remote add origin https://github.com/yourusername/windows-uvc-control-panel.git
   git branch -M main
   git push -u origin main
   ```
4. **Create a release**:
   - Go to the Releases section on GitHub
   - Click "Create a new release"
   - Tag version (e.g., `v1.0.0`)
   - Upload the executables from the `publish/` directory
   - Add release notes describing the version

## Support

For issues, questions, or feature requests, please open an issue on the [GitHub Issues](https://github.com/yourusername/windows-uvc-control-panel/issues) page.


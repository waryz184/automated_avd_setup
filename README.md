# Android VM Creator

This project provides scripts to quickly set up a full command-line Android emulation environment on macOS, Linux, and Windows, without needing a full Android Studio installation.

Each script installs the necessary dependencies, downloads the Android SDK tools, and creates an Android Virtual Device (AVD) for a specified Android version.

## Prerequisites per OS

- **macOS**: [Homebrew](https://brew.sh/)
- **Linux (Debian/Ubuntu)**: `apt` and `sudo` access.
- **Windows**: [Chocolatey](https://chocolatey.org/install)

## Usage

1. Clone this repository to your machine.
2. Open a terminal (or PowerShell on Windows) and navigate to the project folder.
3. Run the script for your OS, passing the desired Android version as an argument.

### macOS
```bash
./setup-macos.sh <version>
```

### Linux (Debian/Ubuntu)
```bash
./setup-linux.sh <version>
```

### Windows (PowerShell)

First, you may need to allow script execution by running this command in an Administrator PowerShell terminal:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
```
Then, you can run the setup script:
```powershell
.\setup-windows.ps1 <version>
```

--- 

### Supported Versions

- `13` (Tiramisu)
- `14` (Upside Down Cake)
- `15` (Vanilla Ice Cream)
- `16` (Upcoming, if system image is available)

### Example

To install and create an Android 14 virtual machine on macOS:

```bash
./setup-macos.sh 14
```

## After Installation

Once the script is finished, open a **new terminal** for the environment variables to be loaded.

You can then launch your virtual machine using the `emulator` command:

```bash
# Example for an Android 14 VM
emulator @android-14-vm
```

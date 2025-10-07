# Automated AVD Setup

This project provides scripts to quickly set up a full command-line Android emulation environment on macOS, Linux, and Windows, without needing a full Android Studio installation.

The scripts for macOS and Linux feature an interactive terminal UI to guide you through the setup process.

## Features

-   **Interactive UI**: A user-friendly terminal interface on macOS and Linux for easy setup.
-   **Cross-Platform Support**: Scripts for macOS, Linux (Debian/Ubuntu), and Windows.
-   **Google Play Store Included**: Creates AVDs with the Google Play Store, allowing you to install any application.
-   **Automated Dependency Installation**: Installs Java and other required tools automatically.
-   **Architecture Detection**: Automatically detects the CPU architecture (ARM64 or x86_64) and installs the appropriate system image.
-   **Environment Setup**: Configures the necessary environment variables for you.

## Prerequisites

-   **macOS**:
    -   [Homebrew](https://brew.sh/)
    -   [Gum](https://github.com/charmbracelet/gum) (will be installed automatically if you have Homebrew)
-   **Linux (Debian/Ubuntu)**:
    -   `apt` and `sudo` access.
    -   [Gum](https://github.com/charmbracelet/gum) (must be installed manually)
-   **Windows**:
    -   [Chocolatey](https://chocolatey.org/install)

## Usage

1.  Clone this repository to your machine.
2.  Open a terminal (or PowerShell on Windows) and navigate to the project folder.
3.  Make the scripts executable if they are not already (`chmod +x setup-*.sh`).
4.  Run the script for your OS.

### macOS & Linux

The scripts for macOS and Linux are interactive. Simply run the script, and it will prompt you for the required information.

```bash
# On macOS
./setup-macos.sh

# On Linux
./setup-linux.sh
```

### Windows (PowerShell)

The Windows script is not yet interactive and requires the Android version as an argument.

First, you may need to allow script execution by running this command in an Administrator PowerShell terminal:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
```

Then, you can run the setup script:

```powershell
# Example for Android 14
.\setup-windows.ps1 14
```

Supported versions for Windows: `13`, `14`, `15`, `16`.

## After Installation

Once the script is finished, open a **new terminal** for the environment variables to be loaded.

You can then launch your virtual machine using the `emulator` command. The name of your AVD will be the one you chose during the setup.

```bash
# Example for an AVD named 'android-14-vm'
emulator @android-14-vm
```

### Managing AVDs

You can use the `avdmanager` command to manage your AVDs:

-   **List AVDs**: `avdmanager list avd`
-   **Delete an AVD**: `avdmanager delete avd -n <avd_name>`

## Troubleshooting

-   **Windows**: If you get an error about script execution being disabled, make sure you have run the `Set-ExecutionPolicy` command mentioned in the "Usage" section.
-   **macOS**: If you have issues with Java, make sure you have followed the on-screen instructions to link the OpenJDK installation.
-   **All Platforms**: If you encounter issues with the Android SDK, you can try deleting the `sdk` directory and running the script again.

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

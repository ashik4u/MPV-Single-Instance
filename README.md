# [MPV](https://mpv.io/) Single Instance Script

This repo contains a Lua script for MPV that forces all secondary MPV launches to send the file to the main MPV window instead of opening multiple players.

## 📌 Features
- Ensures # [MPV](https://mpv.io/) Single Instance Script runs as a **single instance**
- Secondary launches forward file paths to the main instance
- Uses **IPC pipes/sockets** for communication
- Supports **Windows and Linux**
- Automatically detects whether the instance is main or secondary

## 📂 Installation

### 1. Create your MPV scripts folder
- **Windows:** `%AppData%\mpv\scripts\`
- **Linux:** `~/.config/mpv/scripts/`

### 2. Copy the script
Place `single_instance.lua` into the `scripts` folder.

### 3. Done!
MPV will automatically detect the script at next launch.

## 📘 How it works
The script:
1. Checks whether an IPC server is already active.
2. If not found → becomes the **main MPV instance** and creates one.
3. If found → becomes a **secondary instance**, sends its file path via IPC, and exits.

## 🛠 IPC Socket Paths
- **Windows:** `\\.\pipe\mpvsocket`
- **Linux:** `/tmp/mpvsocket`

## ▶️ Example behavior
- You open a file → MPV starts normally.
- You double-click another video → the second MPV launches but detects main instance → sends the new file to the main MPV → quits.

## 📜 Script included
The repo also contains the `single_instance.lua` file with full source code.

## 📄 License
MIT License
